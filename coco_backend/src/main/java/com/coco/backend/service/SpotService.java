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
     * (TourAPI가 현재 한국어 서비스만 연동되어 있어서 titleKo만 채우고, titleEn/titleJa는 번역이 붙을 때까지 null로 둔다.)
     */
    public int importFromTourApi() {
        List<TourApiService.TourApiCandidate> candidates = tourApiService.fetchCandidates();
        int inserted = 0;

        for (var c : candidates) {
            if (spotRepository.findByTourApiid(c.tourApiId()).isPresent()) continue;

            Spot spot = Spot.builder()
                    .tourApiid(c.tourApiId())
                    .titleKo(c.title())
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
                .map(s -> toResponse(s, locale))
                .toList();
    }

    private SpotResponse toResponse(Spot s, String locale) {
        return SpotResponse.builder()
                .id(s.getId())
                .title(resolveTitle(s, locale))
                .lat(s.getLat())
                .lng(s.getLng())
                .category(s.getCategory())
                .imageUrl(s.getImageUrl())
                .address(s.getAddress())
                .build();
    }

    /** locale(ko/en/ja)에 맞는 title을 고른다. en/ja가 아직 번역되지 않았으면 titleKo로 폴백한다. */
    private String resolveTitle(Spot s, String locale) {
        String title = switch (locale == null ? "" : locale) {
            case "en" -> s.getTitleEn();
            case "ja" -> s.getTitleJa();
            default -> s.getTitleKo();
        };
        return title != null ? title : s.getTitleKo();
    }
}
