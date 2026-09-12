package com.coco.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/**
 * 업로드 파일(현재는 피드 게시물 사진)을 로컬 디스크에 저장한다.
 * 배포 규모가 커지면 Supabase Storage/S3 등으로 교체할 수 있게 저장 로직을 여기 한 곳에 모아뒀다.
 */
@Service
public class FileStorageService {

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp", "gif");

    @Value("${app.upload-dir:uploads}")
    private String uploadDir;

    /**
     * 파일을 {uploadDir}/{subDir}/{UUID}.{확장자}로 저장하고, 정적 리소스 매핑(WebConfig)과
     * 짝이 맞는 상대 경로("/uploads/{subDir}/{파일명}")를 돌려준다.
     * 프론트/DB에는 이 상대 경로만 저장하고, 화면에 그릴 때 API 베이스 URL을 앞에 붙인다.
     */
    public String store(MultipartFile file, String subDir) throws IOException {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("파일이 비어있습니다.");
        }

        String extension = extractExtension(file.getOriginalFilename());
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new IllegalArgumentException("지원하지 않는 이미지 형식입니다. (jpg, png, webp, gif만 가능)");
        }

        Path dir = Path.of(uploadDir, subDir);
        Files.createDirectories(dir);

        String filename = UUID.randomUUID() + "." + extension;
        Path target = dir.resolve(filename);
        file.transferTo(target);

        return "/uploads/" + subDir + "/" + filename;
    }

    private String extractExtension(String originalFilename) {
        if (originalFilename == null || !originalFilename.contains(".")) {
            throw new IllegalArgumentException("파일 확장자를 확인할 수 없습니다.");
        }
        String ext = originalFilename.substring(originalFilename.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
        return ext;
    }
}
