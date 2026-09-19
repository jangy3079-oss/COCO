package com.coco.backend.dto.request;

import jakarta.validation.constraints.Size;
import lombok.Getter;

@Getter
public class UserProfileUpdateRequest {
    @Size(max = 50) // users.nickname 컬럼 길이(50)와 맞춤
    private String nickname; // 선택사항 — 보낸 경우만 갱신

    @Size(max = 60) // users.bio 컬럼 길이(60)와 맞춤
    private String bio;      // 선택사항 — 보낸 경우만 갱신
}
