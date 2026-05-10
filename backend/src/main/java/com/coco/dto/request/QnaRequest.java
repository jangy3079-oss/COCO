package com.coco.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;

@Getter
public class QnaRequest {
    @NotBlank
    private String question;
    private String locale;   // en | ja | ko
}
