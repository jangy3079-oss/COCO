package com.coco.backend.controller;

import com.coco.backend.dto.request.SpotRegistrationRequest;
import com.coco.backend.dto.response.ErrorResponse;
import com.coco.backend.dto.response.SpotRegistrationResponse;
import com.coco.backend.service.SpotRegistrationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/spot/register")
@RequiredArgsConstructor
public class SpotRegistrationController {

    private final SpotRegistrationService spotRegistrationService;

    /** 로그인한 사용자가 새 스팟 등록을 신청한다. */
    @PostMapping
    public ResponseEntity<?> register(@Valid @RequestBody SpotRegistrationRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            return ResponseEntity.status(HttpStatus.CREATED).body(spotRegistrationService.register(userId, request));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 내가 신청한 목록 + 각각의 심사 상태. */
    @GetMapping("/mine")
    public ResponseEntity<?> listMine() {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        List<SpotRegistrationResponse> registrations = spotRegistrationService.listMine(userId);
        return ResponseEntity.ok(registrations);
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
