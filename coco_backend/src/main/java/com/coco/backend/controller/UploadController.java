package com.coco.backend.controller;

import com.coco.backend.dto.response.ErrorResponse;
import com.coco.backend.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.time.Duration;

/** 기존 /uploads/... URL 계약을 유지하면서 Supabase Storage 이미지를 전달한다. */
@RestController
@RequiredArgsConstructor
@Slf4j
public class UploadController {

    private final FileStorageService fileStorageService;

    @GetMapping("/uploads/{subDir}/{filename:.+}")
    public ResponseEntity<?> getImage(@PathVariable String subDir, @PathVariable String filename) {
        try {
            return fileStorageService.read(subDir, filename)
                    .<ResponseEntity<?>>map(file -> ResponseEntity.ok()
                            .contentType(MediaType.parseMediaType(file.contentType()))
                            .cacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable())
                            .body(file.bytes()))
                    .orElseGet(() -> ResponseEntity.notFound().build());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        } catch (IOException e) {
            log.error("Storage 이미지 조회 실패: {}/{}", subDir, filename, e);
            return ResponseEntity.internalServerError()
                    .body(new ErrorResponse("이미지를 불러오지 못했습니다."));
        }
    }
}
