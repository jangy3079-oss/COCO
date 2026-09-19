package com.coco.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
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
    private boolean isDraft;
    private List<RouteSpotResponse> spots;
    private int likeCount;
    private int saveCount;
    // 로그인한 요청자가 이 코스에 좋아요/저장을 눌렀는지. 비로그인 요청이면 항상 false.
    private boolean liked;
    private boolean saved;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;
}
