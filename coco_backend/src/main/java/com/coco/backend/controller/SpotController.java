package com.coco.backend.controller;

import com.coco.backend.dto.response.ErrorResponse;
import com.coco.backend.dto.response.LikeToggleResponse;
import com.coco.backend.dto.response.SpotResponse;
import com.coco.backend.service.KakaoLocalService;
import com.coco.backend.service.SpotService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/spot")
@RequiredArgsConstructor
public class SpotController {

    private final SpotService spotService;
    private final KakaoLocalService kakaoLocalService;

    /** 지도 뷰포트(화면에 보이는 영역) 안의 스팟만 조회 — 줌/이동 시마다 프론트에서 재호출. */
    @GetMapping
    public ResponseEntity<List<SpotResponse>> getSpotsInViewport(
            @RequestParam double swLat,
            @RequestParam double neLat,
            @RequestParam double swLng,
            @RequestParam double neLng,
            @RequestParam(required = false) String category,
            @RequestParam(defaultValue = "ko") String locale
    ) {
        return ResponseEntity.ok(spotService.findInViewport(swLat, neLat, swLng, neLng, category, locale));
    }

    /**
     * 지도 탭 전용 조회 — 6개 지도 카테고리(음식점/골목/공원/카페/명소/문화시설) 중 하나로만
     * 호출 가능. category가 "전체"거나 없으면 빈 배열, 6개 밖의 값이면 400.
     * 기존 GET /api/spot(연관 스팟 조회 등에서 category 없이도 호출됨)은 건드리지 않는다.
     */
    @GetMapping("/map")
    public ResponseEntity<?> getMapSpots(
            @RequestParam double swLat,
            @RequestParam double neLat,
            @RequestParam double swLng,
            @RequestParam double neLng,
            @RequestParam(required = false) String category,
            @RequestParam(defaultValue = "ko") String locale
    ) {
        try {
            return ResponseEntity.ok(spotService.findMapSpots(swLat, neLat, swLng, neLng, category, locale));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 스팟 상세 화면용 단건 조회. */
    @GetMapping("/{id}")
    public ResponseEntity<SpotResponse> getSpotById(@PathVariable Long id,
                                                     @RequestParam(defaultValue = "ko") String locale) {
        return spotService.getById(id, locale)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** 제목/주소 키워드 검색 — 코스 만들기 "+ 스팟 추가" 등에서 사용. */
    @GetMapping("/search")
    public ResponseEntity<List<SpotResponse>> searchSpots(@RequestParam String q,
                                                           @RequestParam(defaultValue = "ko") String locale) {
        return ResponseEntity.ok(spotService.search(q, locale));
    }

    /**
     * 스팟 등록 신청 화면의 실시간 장소 검색 — DB에 아직 없는 새 장소도 찾아야 해서
     * (DB만 뒤지는 위 /search와 달리) 카카오 로컬에 검색어를 그대로 쏜다.
     * 검색 자체는 로그인 없이도 가능 — 실제 "등록 신청" 제출은 SpotRegistrationController가
     * 로그인을 요구하므로 여기서는 막지 않는다.
     */
    @GetMapping("/search/external")
    public ResponseEntity<?> searchExternal(@RequestParam String q) {
        return ResponseEntity.ok(kakaoLocalService.searchByKeyword(q));
    }

    /** TourAPI에서 필터링된 후보를 가져와 DB에 채워 넣는 수동 배치 트리거. */
    @PostMapping("/import")
    public ResponseEntity<Map<String, Integer>> importFromTourApi() {
        int inserted = spotService.importFromTourApi();
        return ResponseEntity.ok(Map.of("inserted", inserted));
    }

    /** 카카오 로컬 API에서 관광 관련 카테고리로 좁힌 후보를 가져와 DB에 채워 넣는 수동 배치 트리거. */
    @PostMapping("/import/kakao")
    public ResponseEntity<Map<String, Object>> importFromKakaoLocal() {
        return ResponseEntity.ok(spotService.importFromKakaoLocal());
    }

    /**
     * TourAPI 일일 요청 한도 등으로 설명/사진이 비어있게 저장된 기존 스팟만 골라
     * 재시도한다. 새 스팟을 만들지 않으므로 몇 번을 호출해도 중복 저장 안 됨 —
     * 이미 채워진 스팟은 매번 자동으로 대상에서 빠진다.
     */
    @PostMapping("/backfill")
    public ResponseEntity<Map<String, Integer>> backfillMissingTourApiContent() {
        return ResponseEntity.ok(spotService.backfillMissingTourApiContent());
    }

    /** 스팟 찜 토글 — 이미 찜했으면 취소, 아니면 새로 찜한다. */
    @PostMapping("/{id}/like")
    public ResponseEntity<?> toggleLike(@PathVariable Long id) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        try {
            LikeToggleResponse result = spotService.toggleLike(userId, id);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ErrorResponse(e.getMessage()));
        }
    }

    /** 현재 로그인한 유저가 찜한 스팟 목록. */
    @GetMapping("/liked")
    public ResponseEntity<?> getLikedSpots(@RequestParam(defaultValue = "ko") String locale) {
        Long userId = currentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("로그인이 필요합니다."));
        }
        return ResponseEntity.ok(spotService.getLikedSpots(userId, locale));
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
