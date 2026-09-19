package com.coco.backend.dto.response;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class UserProfileResponse {
    private Long id;
    private String nickname;
    private String email;
    private String role;
    private String bio;
    private String profileImageUrl;
}
