package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;

@Getter
public class FeedPostRequest {
    @NotBlank
    private String imageUrl;
    private String description;
    private Long spotId;        // 위치태그 — 선택사항.
    private Long routeId;       // 코스 공유로 만드는 게시물일 때만 — 선택사항.
}
