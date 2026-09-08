package com.coco.backend.service;

import com.coco.backend.dto.response.SpotResponse;
import com.coco.backend.entity.Spot;
import com.coco.backend.repository.SpotRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class SpotService {

    private final SpotRepository spotRepository;
    private final TourApiService tourApiService;

    /**
     * TourAPI에서 필터링된 후보를 가져와 아직 DB에 없는 것만 저장한다.
     * (다국어 title 컬럼이 현재 엔티티엔 없어서 한글 제목 하나만 저장한다.)
     */
    public int importFromTourApi() {
        List<TourApiService.TourApiCandidate> candidates = tourApiService.fetchCandidates();
        int inserted = 0;

        for (var c : candidates) {
            if (spotRepository.findByTourApiid(c.tourApiId()).isPresent()) continue;

            Spot spot = Spot.builder()
                    .tourApiid(c.tourApiId())
                    .title(c.title())
                    .lat(c.lat())
                    .lng(c.lng())
                    .address(c.address())
                    .category(c.category())
                    .imageUrl(c.imageUrl())
                    .build();
            spotRepository.save(spot);
            inserted++;
        }
        log.info("TourAPI 스팟 임포트 완료: 후보 {}건 중 신규 {}건 저장", candidates.size(), inserted);
        return inserted;
    }

    /** 지도 화면에 보이는 영역(뷰포트) 안의 스팟만 조회 — 핀 밀집 방지의 핵심. */
    public List<SpotResponse> findInViewport(double swLat, double neLat, double swLng, double neLng,
                                              String category, String locale) {
        return spotRepository.findInBounds(swLat, neLat, swLng, neLng, category).stream()
                .map(this::toResponse)
                .toList();
    }

    private SpotResponse toResponse(Spot s) {
        return SpotResponse.builder()
                .id(s.getId())
                .title(s.getTitle())
                .lat(s.getLat())
                .lng(s.getLng())
                .category(s.getCategory())
                .imageUrl(s.getImageUrl())
                .address(s.getAddress())
                .build();
    }
}
