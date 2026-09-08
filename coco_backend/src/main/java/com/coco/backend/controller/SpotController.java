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

    /** TourAPI에서 필터링된 후보를 가져와 DB에 채워 넣는 수동 배치 트리거. */
    @PostMapping("/import")
    public ResponseEntity<Map<String, Integer>> importFromTourApi() {
        int inserted = spotService.importFromTourApi();
        return ResponseEntity.ok(Map.of("inserted", inserted));
    }
}
