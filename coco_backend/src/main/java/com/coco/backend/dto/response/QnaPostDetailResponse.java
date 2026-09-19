package com.coco.backend.dto.response;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class QnaPostDetailResponse {
    private QnaPostResponse post;
    private List<QnaAnswerResponse> answers;
}
