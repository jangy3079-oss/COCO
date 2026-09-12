package com.coco.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Builder;
import lombok.Getter;
import java.time.LocalDateTime;

@Getter @Builder
public class FeedPostResponse {
    private Long id;
    private String userNickname;
    private String imageUrl;
    private String description;
    private Long spotId;
    private String spotName;
    private Double lat;
    private Double lng;
    private int likeCount;
    // Jackson write-dates-as-timestamps: false 설정과 이중으로 보호.
    // 프론트 Flutter의 DateTime.parse()가 읽을 수 있는 "2026-09-12T13:00:00" 형태로 내려감.
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;
    // 이 게시물이 붙은 스팟이 지금 인기(trending) 상태인지 — SpotService.isTrending과
    // 동일 기준. 피드 탭에서 인기 배지를 그리는 데 쓴다.
    private boolean trending;
    // 로그인한 요청자가 이 게시물에 좋아요를 눌렀는지. 비로그인 요청이면 항상 false.
    private boolean liked;
}
