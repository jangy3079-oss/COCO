package com.coco.backend.controller;

import com.coco.backend.dto.response.SpotResponse;
import com.coco.backend.service.SpotService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/spot")
@RequiredArgsConstructor
public class SpotController {

    private final SpotService spotService;

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

    /** 스팟 상세 화면용 단건 조회. */
    @GetMapping("/{id}")
    public ResponseEntity<SpotResponse> getSpotById(@PathVariable Long id) {
        return spotService.getById(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** 제목/주소 키워드 검색 — 코스 만들기 "+ 스팟 추가" 등에서 사용. */
    @GetMapping("/search")
    public ResponseEntity<List<SpotResponse>> searchSpots(@RequestParam String q) {
        return ResponseEntity.ok(spotService.search(q));
    }

    /** TourAPI에서 필터링된 후보를 가져와 DB에 채워 넣는 수동 배치 트리거. */
    @PostMapping("/import")
    public ResponseEntity<Map<String, Integer>> importFromTourApi() {
        int inserted = spotService.importFromTourApi();
        return ResponseEntity.ok(Map.of("inserted", inserted));
    }

    /** 카카오 로컬 API에서 관광 관련 카테고리로 좁힌 후보를 가져와 DB에 채워 넣는 수동 배치 트리거. */
    @PostMapping("/import/kakao")
    public ResponseEntity<Map<String, Integer>> importFromKakaoLocal() {
        int inserted = spotService.importFromKakaoLocal();
        return ResponseEntity.ok(Map.of("inserted", inserted));
    }
}
