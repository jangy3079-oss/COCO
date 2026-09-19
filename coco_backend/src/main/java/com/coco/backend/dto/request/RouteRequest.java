package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;

import java.util.List;

@Getter
public class RouteRequest {
    @NotBlank
    @Size(max = 100) // route_maps.title 컬럼 길이(100)와 맞춤
    private String name;

    @NotNull
    private List<Long> spotIds;   // 코스에 담을 스팟들 — 이 순서 그대로 RouteMapSpot.sortOrder에 반영

    private String visibility;    // PUBLIC | PRIVATE — null이면 PRIVATE로 저장
    private Boolean isDraft;      // null이면 false(발행 상태)로 저장
}
