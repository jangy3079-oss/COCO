package com.coco.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@Builder
public class RouteResponse {
    private Long id;
    private String userNickname;
    private String name;
    private String visibility;
    // boolean 필드가 "is"로 시작하면 Lombok+Jackson이 JSON에서 "is"를 벗겨 "draft"로
    // 내려버리는 함정이 있어(SpotResponse.isLocalPick 참고) 프론트가 기대하는
    // "isDraft" 키로 명시 고정한다.
    @JsonProperty("isDraft")
    private boolean isDraft;
    private List<RouteSpotResponse> spots;
    private int likeCount;
    private int saveCount;
    private int shareCount;
    // 로그인한 요청자가 이 코스에 좋아요/저장을 눌렀는지. 비로그인 요청이면 항상 false.
    private boolean liked;
    private boolean saved;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;
}
