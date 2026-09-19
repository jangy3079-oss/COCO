package com.coco.backend.controller;

import com.coco.backend.dto.request.RouteRequest;
import com.coco.backend.dto.response.ErrorResponse;
import com.coco.backend.dto.response.LikeToggleResponse;
import com.coco.backend.dto.response.RouteResponse;
import com.coco.backend.dto.response.SaveToggleResponse;
import com.coco.backend.exception.ForbiddenException;
import com.coco.backend.service.RouteService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/routes")
@RequiredArgsConstructor
public class RouteController {

    private final RouteService routeService;

    /** 로그인한 사용자가 스팟들을 순서대로 엮어 코스를 만든다. */
    @PostMapping
    public ResponseEntity<?> createRoute(@Valid @RequestBody RouteRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            return ResponseEntity.status(HttpStatus.CREATED).body(routeService.createRoute(userId, request));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 내가 만든 코스 목록. */
    @GetMapping("/mine")
    public ResponseEntity<?> listMine() {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        List<RouteResponse> routes = routeService.listMine(userId);
        return ResponseEntity.ok(routes);
    }

    /** 코스 상세 + 스팟 목록. PRIVATE 코스는 작성자 본인만 조회 가능. */
    @GetMapping("/{id}")
    public ResponseEntity<?> getById(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(routeService.getById(id, currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 이름/스팟 목록/공개범위 수정 — 작성자 본인만 가능. */
    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @Valid @RequestBody RouteRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            return ResponseEntity.ok(routeService.update(userId, id, request));
        } catch (ForbiddenException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(new ErrorResponse(e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 코스 삭제 — 작성자 본인만 가능. */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            routeService.delete(userId, id);
            return ResponseEntity.noContent().build();
        } catch (ForbiddenException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(new ErrorResponse(e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 코스 좋아요 토글. */
    @PostMapping("/{id}/like")
    public ResponseEntity<?> toggleLike(@PathVariable Long id) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            LikeToggleResponse result = routeService.toggleLike(userId, id);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 코스 저장(북마크) 토글. */
    @PostMapping("/{id}/save")
    public ResponseEntity<?> toggleSave(@PathVariable Long id) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            SaveToggleResponse result = routeService.toggleSave(userId, id);
            return ResponseEntity.ok(result);
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
