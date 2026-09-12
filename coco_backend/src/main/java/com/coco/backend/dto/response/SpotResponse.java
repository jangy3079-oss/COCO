package com.coco.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;
import lombok.Getter;

@Getter @Builder
public class SpotResponse {
    private Long id;
    private String title;       // locale 따라 ko/en/ja 중 하나
    private Double lat;
    private Double lng;
    private String category;
    private String imageUrl;
    private String address;
    private String description; // 카카오 로컬 소스는 소개글이 없어 null일 수 있음

    // 지도 핀 표시용 신호 두 가지. 서로 다른 축이라 독립적으로 true/false 조합 가능하다.
    // - isLocalPick: 팀이 검증해 심어둔 로컬 픽 여부 → 프론트에서 핀 "색"을 다르게 표시.
    // - trending: 실제 유저 반응(피드 게시물 수·좋아요)이 기준치 이상인지 → 핀 "크기"를 다르게 표시.
    // 인기 없는 진짜 로컬 스팟(isLocalPick=true, trending=false)도 색으로는 항상 눈에 띄게 하려는 의도.
    // boolean 필드 이름이 "is"로 시작하면 Lombok이 getter를 isLocalPick()으로 만드는데,
    // Jackson이 JSON 만들 때 그 "is"를 property 이름에서 다시 벗겨내서 "localPick"으로
    // 내려가 버린다(흔한 Lombok+Jackson 함정). 프론트가 기대하는 "isLocalPick" 키로
    // 고정하려면 명시적으로 지정해줘야 한다. trending은 "is"로 시작 안 해서 이 문제가 없다.
    @JsonProperty("isLocalPick")
    private boolean isLocalPick;
    private boolean trending;
}
