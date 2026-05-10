package com.coco.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;

@Getter
public class FeedPostRequest {
    @NotBlank
    private String imageUrl;
    private String description;
    private Long spotId;        // 위치태그
}
