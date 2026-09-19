package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;

@Getter
public class QnaPostRequest {
    @NotBlank
    @Size(max = 100) // qna_posts.title 컬럼 길이(100)와 맞춤
    private String title;

    @NotBlank
    private String content;

    private Long spotId;   // 장소 태그 — 선택사항
    private String locale; // en | ja | ko
}
