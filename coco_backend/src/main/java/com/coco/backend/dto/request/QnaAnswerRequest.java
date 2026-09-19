package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;

@Getter
public class QnaAnswerRequest {
    @NotBlank
    @Size(max = 1000) // qna_answers.content 컬럼 길이(1000)와 맞춤
    private String content;
}
