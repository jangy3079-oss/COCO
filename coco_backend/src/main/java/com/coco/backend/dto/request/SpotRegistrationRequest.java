package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;

@Getter
public class SpotRegistrationRequest {
    @NotBlank
    @Size(max = 100) // spot_registrations.name 컬럼 길이(100)와 맞춤
    private String name;

    @NotBlank
    @Size(max = 20) // spot_registrations.category 컬럼 길이(20)와 맞춤
    private String category;

    @NotBlank
    @Size(max = 255) // spot_registrations.address 컬럼 길이(255)와 맞춤
    private String address;

    @NotNull
    private Double lat;

    @NotNull
    private Double lng;

    private String description; // 선택사항
}
