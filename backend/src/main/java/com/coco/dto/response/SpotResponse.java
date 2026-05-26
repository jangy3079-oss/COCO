package com.coco.dto.response;

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
}
