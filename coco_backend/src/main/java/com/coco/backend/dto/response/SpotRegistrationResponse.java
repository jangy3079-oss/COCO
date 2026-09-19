package com.coco.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class SpotRegistrationResponse {
    private Long id;
    private String name;
    private String category;
    private String address;
    private Double lat;
    private Double lng;
    private String description;
    private String status;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;
}
