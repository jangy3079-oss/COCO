package com.coco.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Arrays;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Pattern;

/**
 * 사용자 업로드 이미지를 Supabase Storage에 저장한다.
 *
 * DB와 프론트가 사용하는 /uploads/{폴더}/{파일명} 경로는 그대로 유지하고, 실제 파일만
 * 영구 저장소에 둔다. 이 경로의 조회는 UploadController가 Storage에서 중계한다.
 */
@Service
public class FileStorageService {

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp", "gif");
    private static final Pattern SAFE_PATH_SEGMENT = Pattern.compile("[a-zA-Z0-9._-]+");
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(20);

    private final String supabaseUrl;
    private final String storageKey;
    private final String bucket;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final AtomicBoolean bucketReady = new AtomicBoolean(false);

    @Autowired
    public FileStorageService(
            @Value("${app.storage.supabase-url:}") String supabaseUrl,
            @Value("${app.storage.key:}") String storageKey,
            @Value("${app.storage.bucket:coco-uploads}") String bucket
    ) {
        this(supabaseUrl, storageKey, bucket, new ObjectMapper(),
                HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build());
    }

    FileStorageService(String supabaseUrl, String storageKey, String bucket,
                       ObjectMapper objectMapper, HttpClient httpClient) {
        this.supabaseUrl = stripTrailingSlash(supabaseUrl);
        this.storageKey = storageKey == null ? "" : storageKey.trim();
        this.bucket = bucket == null ? "" : bucket.trim();
        this.objectMapper = objectMapper;
        this.httpClient = httpClient;
    }

    /** Storage의 {subDir}/{UUID}.{확장자}에 저장하고 기존 계약과 같은 상대 URL을 반환한다. */
    public String store(MultipartFile file, String subDir) throws IOException {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("파일이 비어있습니다.");
        }
        validatePathSegment(subDir, "저장 폴더");

        String extension = extractExtension(file.getOriginalFilename());
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new IllegalArgumentException("지원하지 않는 이미지 형식입니다. (jpg, png, webp, gif만 가능)");
        }

        requireConfiguration();
        ensureBucketExists();

        String filename = UUID.randomUUID() + "." + extension;
        String objectPath = subDir + "/" + filename;
        HttpRequest request = authorizedRequest(storageUri("/object/" + encode(bucket) + "/" + encodePath(objectPath)))
                .timeout(REQUEST_TIMEOUT)
                .header("Content-Type", contentType(extension))
                .header("cache-control", "31536000")
                .header("x-upsert", "false")
                .POST(HttpRequest.BodyPublishers.ofByteArray(file.getBytes()))
                .build();

        HttpResponse<String> response = send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw storageFailure("이미지 업로드", response);
        }

        return "/uploads/" + objectPath;
    }

    /** Storage의 비공개 객체를 읽는다. 존재하지 않는 객체는 Optional.empty()로 반환한다. */
    public Optional<StoredFile> read(String subDir, String filename) throws IOException {
        validatePathSegment(subDir, "저장 폴더");
        validatePathSegment(filename, "파일명");
        requireConfiguration();

        String objectPath = subDir + "/" + filename;
        HttpRequest request = authorizedRequest(
                storageUri("/object/authenticated/" + encode(bucket) + "/" + encodePath(objectPath)))
                .timeout(REQUEST_TIMEOUT)
                .GET()
                .build();
        HttpResponse<byte[]> response = send(request, HttpResponse.BodyHandlers.ofByteArray());
        if (response.statusCode() == 404) {
            return Optional.empty();
        }
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IOException("Supabase Storage 이미지 조회 실패 (HTTP " + response.statusCode() + ")");
        }

        String mediaType = response.headers().firstValue("content-type")
                .orElseGet(() -> contentType(extractExtension(filename)));
        return Optional.of(new StoredFile(response.body(), mediaType));
    }

    private void ensureBucketExists() throws IOException {
        if (bucketReady.get()) {
            return;
        }
        synchronized (bucketReady) {
            if (bucketReady.get()) {
                return;
            }

            HttpRequest findRequest = authorizedRequest(storageUri("/bucket/" + encode(bucket)))
                    .timeout(REQUEST_TIMEOUT)
                    .GET()
                    .build();
            HttpResponse<String> findResponse = send(findRequest, HttpResponse.BodyHandlers.ofString());
            if (isSuccess(findResponse.statusCode())) {
                bucketReady.set(true);
                return;
            }
            if (!isMissingBucket(findResponse)) {
                throw storageFailure("Storage 버킷 확인", findResponse);
            }

            byte[] body = objectMapper.writeValueAsBytes(Map.of(
                    "id", bucket,
                    "name", bucket,
                    "public", false,
                    "file_size_limit", 5 * 1024 * 1024,
                    "allowed_mime_types", new String[]{"image/jpeg", "image/png", "image/webp", "image/gif"}
            ));
            HttpRequest createRequest = authorizedRequest(storageUri("/bucket"))
                    .timeout(REQUEST_TIMEOUT)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                    .build();
            HttpResponse<String> createResponse = send(createRequest, HttpResponse.BodyHandlers.ofString());
            if (isSuccess(createResponse.statusCode())) {
                bucketReady.set(true);
                return;
            }

            // 여러 인스턴스가 동시에 최초 업로드를 처리하면 다른 인스턴스가 먼저 만들 수 있다.
            HttpResponse<String> retryResponse = send(findRequest, HttpResponse.BodyHandlers.ofString());
            if (isSuccess(retryResponse.statusCode())) {
                bucketReady.set(true);
                return;
            }
            throw storageFailure("Storage 버킷 생성", createResponse);
        }
    }

    private HttpRequest.Builder authorizedRequest(URI uri) {
        HttpRequest.Builder builder = HttpRequest.newBuilder(uri)
                .header("apikey", storageKey);
        // 새 sb_secret 키는 apikey 헤더로만 전송한다. 기존 JWT service_role 키는
        // Storage 인증 호환성을 위해 Authorization 헤더도 함께 전송한다.
        if (!storageKey.startsWith("sb_secret_")) {
            builder.header("Authorization", "Bearer " + storageKey);
        }
        return builder;
    }

    private URI storageUri(String path) {
        return URI.create(supabaseUrl + "/storage/v1" + path);
    }

    private void requireConfiguration() throws IOException {
        if (supabaseUrl.isBlank() || storageKey.isBlank()) {
            throw new IOException("Supabase Storage 설정이 없습니다. SUPABASE_URL과 SUPABASE_STORAGE_KEY를 설정하세요.");
        }
        if (!supabaseUrl.startsWith("https://") && !supabaseUrl.startsWith("http://localhost")) {
            throw new IOException("SUPABASE_URL 형식이 올바르지 않습니다.");
        }
        validatePathSegment(bucket, "Storage 버킷");
    }

    private <T> HttpResponse<T> send(HttpRequest request, HttpResponse.BodyHandler<T> bodyHandler)
            throws IOException {
        try {
            return httpClient.send(request, bodyHandler);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Supabase Storage 요청이 중단되었습니다.", e);
        }
    }

    private IOException storageFailure(String operation, HttpResponse<String> response) {
        String body = response.body() == null ? "" : response.body();
        if (body.length() > 500) {
            body = body.substring(0, 500);
        }
        return new IOException(operation + " 실패 (HTTP " + response.statusCode() + "): " + body);
    }

    private void validatePathSegment(String value, String label) {
        if (value == null || !SAFE_PATH_SEGMENT.matcher(value).matches()) {
            throw new IllegalArgumentException(label + " 형식이 올바르지 않습니다.");
        }
    }

    private String extractExtension(String originalFilename) {
        if (originalFilename == null || !originalFilename.contains(".")) {
            throw new IllegalArgumentException("파일 확장자를 확인할 수 없습니다.");
        }
        return originalFilename.substring(originalFilename.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
    }

    private String contentType(String extension) {
        return switch (extension.toLowerCase(Locale.ROOT)) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "webp" -> "image/webp";
            case "gif" -> "image/gif";
            default -> "application/octet-stream";
        };
    }

    private String encodePath(String path) {
        return String.join("/", Arrays.stream(path.split("/"))
                .map(this::encode)
                .toList());
    }

    private String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }

    private static boolean isSuccess(int statusCode) {
        return statusCode >= 200 && statusCode < 300;
    }

    /** Supabase Storage는 없는 버킷을 HTTP 400 + NoSuchBucket으로 응답할 수 있다. */
    private static boolean isMissingBucket(HttpResponse<String> response) {
        if (response.statusCode() == 404) {
            return true;
        }
        String body = response.body();
        return response.statusCode() == 400 && body != null
                && (body.contains("NoSuchBucket") || body.contains("Bucket not found"));
    }

    private static String stripTrailingSlash(String value) {
        if (value == null) {
            return "";
        }
        String result = value.trim();
        while (result.endsWith("/")) {
            result = result.substring(0, result.length() - 1);
        }
        return result;
    }

    public record StoredFile(byte[] bytes, String contentType) {
    }
}
