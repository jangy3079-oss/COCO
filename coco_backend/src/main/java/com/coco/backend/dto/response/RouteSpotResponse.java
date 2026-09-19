package com.coco.backend.dto.response;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class RouteSpotResponse {
    private Long spotId;
    private String title;
    private Double lat;
    private Double lng;
    private String imageUrl;
    private int order;
}
