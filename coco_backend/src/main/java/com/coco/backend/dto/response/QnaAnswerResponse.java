package com.coco.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class QnaAnswerResponse {
    private Long id;
    private String userNickname;
    // 답변 작성자가 LOCAL 유저인지 — TOURIST면 false. boolean 필드가 "is"로 시작하면
    // Lombok+Jackson이 JSON에서 "is"를 벗겨 "local"로 내려버리는 함정이 있어(SpotResponse.isLocalPick
    // 참고) 프론트가 기대하는 "isLocal" 키로 명시 고정한다.
    @JsonProperty("isLocal")
    private boolean isLocal;
    private String content;
    private boolean adopted;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;
}
