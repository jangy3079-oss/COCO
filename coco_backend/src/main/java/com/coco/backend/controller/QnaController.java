package com.coco.backend.controller;

import com.coco.backend.dto.request.QnaAdoptRequest;
import com.coco.backend.dto.request.QnaAnswerRequest;
import com.coco.backend.dto.request.QnaPostRequest;
import com.coco.backend.dto.response.ErrorResponse;
import com.coco.backend.dto.response.QnaAnswerResponse;
import com.coco.backend.dto.response.QnaPostDetailResponse;
import com.coco.backend.dto.response.QnaPostResponse;
import com.coco.backend.exception.ForbiddenException;
import com.coco.backend.service.QnaService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/qna")
@RequiredArgsConstructor
public class QnaController {

    private final QnaService qnaService;

    /** 질문 목록. filter=all(기본)|unanswered|mine, sort=latest(기본)|unanswered_first. */
    @GetMapping("/posts")
    public ResponseEntity<?> listPosts(
            @RequestParam(defaultValue = "all") String filter,
            @RequestParam(defaultValue = "latest") String sort
    ) {
        Long userId = currentUserId();
        if ("mine".equals(filter) && userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        List<QnaPostResponse> posts = qnaService.listPosts(filter, sort, userId);
        return ResponseEntity.ok(posts);
    }

    /** 로그인한 사용자가 (선택적으로 스팟을 태그해서) 질문을 올린다. */
    @PostMapping("/posts")
    public ResponseEntity<?> createPost(@Valid @RequestBody QnaPostRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            return ResponseEntity.status(HttpStatus.CREATED).body(qnaService.createPost(userId, request));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 질문 상세 + 답변 목록. */
    @GetMapping("/posts/{id}")
    public ResponseEntity<?> getPostDetail(@PathVariable Long id) {
        try {
            QnaPostDetailResponse detail = qnaService.getPostDetail(id);
            return ResponseEntity.ok(detail);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 로그인한 사용자가 질문에 답변을 단다. */
    @PostMapping("/posts/{id}/answers")
    public ResponseEntity<?> createAnswer(@PathVariable Long id, @Valid @RequestBody QnaAnswerRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            QnaAnswerResponse answer = qnaService.createAnswer(userId, id, request);
            return ResponseEntity.status(HttpStatus.CREATED).body(answer);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 답변 채택 — 질문 작성자만 가능(아니면 403). */
    @PostMapping("/posts/{id}/adopt")
    public ResponseEntity<?> adopt(@PathVariable Long id, @Valid @RequestBody QnaAdoptRequest request) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            qnaService.adopt(userId, id, request);
            return ResponseEntity.ok().build();
        } catch (ForbiddenException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(new ErrorResponse(e.getMessage()));
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
