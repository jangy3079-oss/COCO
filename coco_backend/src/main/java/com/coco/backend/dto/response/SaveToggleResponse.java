package com.coco.backend.dto.response;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class SaveToggleResponse {
    private boolean saved;
    private int saveCount;
}
