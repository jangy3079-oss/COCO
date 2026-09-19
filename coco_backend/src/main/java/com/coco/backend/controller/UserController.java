package com.coco.backend.controller;

import com.coco.backend.dto.request.UserProfileUpdateRequest;
import com.coco.backend.dto.response.ErrorResponse;
import com.coco.backend.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/me")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    /** 마이페이지에서 보여줄 내 프로필(닉네임/이메일/역할/자기소개/프로필사진). */
    @GetMapping
    public ResponseEntity<?> getMyProfile() {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            return ResponseEntity.ok(userService.getProfile(userId));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 프로필 편집 — nickname/bio 둘 다 선택사항, 보낸 필드만 갱신. */
    @PatchMapping
    public ResponseEntity<?> updateMyProfile(@Valid @RequestBody UserProfileUpdateRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            return ResponseEntity.ok(userService.updateProfile(userId, request));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    // JwtAuthenticationFilter가 유효한 토큰이 있을 때만 SecurityContext에 principal(userId)을
    // 심어두므로, 로그인 안 한 요청은 여기서 null로 나온다.
    private Long currentUserId() {
        var authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof Long userId)) {
            return null;
        }
        return userId;
    }
}
