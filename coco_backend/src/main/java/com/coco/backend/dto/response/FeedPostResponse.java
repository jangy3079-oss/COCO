package com.coco.backend.dto.response;

import lombok.Builder;
import lombok.Getter;
import java.time.LocalDateTime;

@Getter @Builder
public class FeedPostResponse {
    private Long id;
    private String userNickname;
    private String imageUrl;
    private String description;
    private String spotName;
    private Double lat;
    private Double lng;
    private int likeCount;
    private LocalDateTime createdAt;
}
