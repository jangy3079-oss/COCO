package com.coco.backend.controller;

import com.coco.backend.dto.request.FeedCommentRequest;
import com.coco.backend.dto.request.FeedPostRequest;
import com.coco.backend.dto.response.ErrorResponse;
import com.coco.backend.dto.response.FeedCommentResponse;
import com.coco.backend.dto.response.FeedPostResponse;
import com.coco.backend.dto.response.LikeToggleResponse;
import com.coco.backend.dto.response.SaveToggleResponse;
import com.coco.backend.service.FeedService;
import com.coco.backend.service.FileStorageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/feed")
@RequiredArgsConstructor
@Slf4j
public class FeedController {

    private final FeedService feedService;
    private final FileStorageService fileStorageService;

    @GetMapping
    public List<FeedPostResponse> list(@RequestParam(defaultValue = "ko") String locale) {
        return feedService.listFeed(currentUserId(), locale);
    }

    @PostMapping
    public ResponseEntity<?> create(@Valid @RequestBody FeedPostRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(feedService.createPost(userId, request));
    }

    /** 게시물 작성 전, 사진을 먼저 올려 imageUrl을 받아온다 — 그 값을 그대로 POST /api/feed의 imageUrl에 넣어 쓴다. */
    @PostMapping(value = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> uploadImage(@RequestParam("file") MultipartFile file) {
        if (currentUserId() == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            String imageUrl = fileStorageService.store(file, "feed");
            return ResponseEntity.ok(Map.of("imageUrl", imageUrl));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        } catch (IOException e) {
            log.error("피드 이미지 Storage 업로드 실패", e);
            return ResponseEntity.internalServerError().body(new ErrorResponse("이미지 업로드에 실패했습니다."));
        }
    }

    /** 좋아요 토글 — 이미 눌렀으면 취소, 아니면 새로 누른다. */
    @PostMapping("/{id}/like")
    public ResponseEntity<?> toggleLike(@PathVariable Long id) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            LikeToggleResponse result = feedService.toggleLike(userId, id);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 저장(북마크) 토글 — 이미 저장했으면 취소, 아니면 새로 저장한다. */
    @PostMapping("/{id}/save")
    public ResponseEntity<?> toggleSave(@PathVariable Long id) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            SaveToggleResponse result = feedService.toggleSave(userId, id);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 현재 로그인한 유저가 좋아요한 피드 목록 — GET /api/feed(최신 50개 캡)와 달리 캡 없이 전체. */
    @GetMapping("/liked")
    public ResponseEntity<?> getLikedFeed(@RequestParam(defaultValue = "ko") String locale) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        return ResponseEntity.ok(feedService.getLikedFeed(userId, locale));
    }

    /** 현재 로그인한 유저가 저장한 피드 목록 — getLikedFeed와 동일한 형태(캡 없이 전체). */
    @GetMapping("/saved")
    public ResponseEntity<?> getSavedFeed(@RequestParam(defaultValue = "ko") String locale) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        return ResponseEntity.ok(feedService.getSavedFeed(userId, locale));
    }

    @GetMapping("/{id}/comments")
    public List<FeedCommentResponse> listComments(@PathVariable Long id,
                                                   @RequestParam(defaultValue = "ko") String locale) {
        return feedService.listComments(id, locale);
    }

    @PostMapping("/{id}/comments")
    public ResponseEntity<?> createComment(@PathVariable Long id, @Valid @RequestBody FeedCommentRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            return ResponseEntity.status(HttpStatus.CREATED).body(feedService.createComment(userId, id, request));
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
