package com.coco.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class QnaPostResponse {
    private Long id;
    private String userNickname;
    private String title;
    private String content;
    private Long spotId;
    private String spotName;
    private Long adoptedAnswerId;
    // 목록 화면에서 "답변 N개" 배지, filter=unanswered 등에 사용
    private int answerCount;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;
}
