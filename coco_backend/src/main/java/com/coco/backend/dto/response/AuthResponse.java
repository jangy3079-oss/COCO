package com.coco.backend.dto.response;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class AuthResponse {
    private String accessToken;
    private Long userId;
    private String email;
    private String nickname;
    private String role;
    private String locale;
}
