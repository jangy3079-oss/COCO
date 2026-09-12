package com.coco.backend.dto.response;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class LikeToggleResponse {
    private boolean liked;
    private int likeCount;
}
