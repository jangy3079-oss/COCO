package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;

@Getter
public class FeedCommentRequest {
    @NotBlank
    @Size(max = 300) // feed_comments.content 컬럼 길이(300)와 맞춤
    private String content;
}
