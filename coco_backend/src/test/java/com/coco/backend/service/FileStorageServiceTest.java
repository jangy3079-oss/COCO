package com.coco.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;

class FileStorageServiceTest {

    private HttpServer server;

    @AfterEach
    void stopServer() {
        if (server != null) {
            server.stop(0);
        }
    }

    @Test
    void storesAndReadsImageThroughSupabaseStorageWithoutChangingPublicPathContract() throws Exception {
        AtomicBoolean bucketCreated = new AtomicBoolean(false);
        AtomicReference<byte[]> uploaded = new AtomicReference<>();
        server = HttpServer.create(new InetSocketAddress(0), 0);
        server.createContext("/storage/v1", exchange -> handleStorage(exchange, bucketCreated, uploaded));
        server.start();

        String baseUrl = "http://localhost:" + server.getAddress().getPort();
        FileStorageService service = new FileStorageService(
                baseUrl,
                "server-only-key",
                "coco-uploads",
                new ObjectMapper(),
                HttpClient.newHttpClient()
        );
        byte[] imageBytes = "image-bytes".getBytes(StandardCharsets.UTF_8);
        MockMultipartFile image = new MockMultipartFile(
                "file", "photo.png", "image/png", imageBytes);

        String storedPath = service.store(image, "feed");
        String filename = storedPath.substring(storedPath.lastIndexOf('/') + 1);
        FileStorageService.StoredFile result = service.read("feed", filename).orElseThrow();

        assertThat(storedPath).matches("/uploads/feed/[0-9a-f-]{36}\\.png");
        assertThat(bucketCreated).isTrue();
        assertThat(uploaded.get()).isEqualTo(imageBytes);
        assertThat(result.bytes()).isEqualTo(imageBytes);
        assertThat(result.contentType()).isEqualTo("image/png");
    }

    private void handleStorage(HttpExchange exchange, AtomicBoolean bucketCreated,
                               AtomicReference<byte[]> uploaded) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();

        if (method.equals("GET") && path.equals("/storage/v1/bucket/coco-uploads")) {
            respond(exchange, bucketCreated.get() ? 200 : 400,
                    bucketCreated.get() ? "{}" : "{\"code\":\"NoSuchBucket\",\"message\":\"Bucket not found\"}");
            return;
        }
        if (method.equals("POST") && path.equals("/storage/v1/bucket")) {
            bucketCreated.set(true);
            respond(exchange, 200, "{}");
            return;
        }
        if (method.equals("POST") && path.startsWith("/storage/v1/object/coco-uploads/feed/")) {
            uploaded.set(exchange.getRequestBody().readAllBytes());
            respond(exchange, 200, "{}");
            return;
        }
        if (method.equals("GET") && path.startsWith("/storage/v1/object/authenticated/coco-uploads/feed/")) {
            byte[] body = uploaded.get();
            exchange.getResponseHeaders().add("Content-Type", "image/png");
            exchange.sendResponseHeaders(200, body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
            return;
        }
        respond(exchange, 404, "{}");
    }

    private void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.sendResponseHeaders(status, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }
}
