package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;

@Getter
public class QnaAdoptRequest {
    @NotNull
    private Long answerId;
}
