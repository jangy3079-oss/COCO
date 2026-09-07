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
     * 다국어 제목(en/ja)은 TourAPI 응답에 없으므로 우선 한글 제목으로 채워두고,
     * 번역은 추후 별도 작업으로 채운다.
     */
    public int importFromTourApi() {
        List<TourApiService.TourApiCandidate> candidates = tourApiService.fetchCandidates();
        int inserted = 0;

        for (var c : candidates) {
            if (spotRepository.findByTourApiId(c.tourApiId()).isPresent()) continue;

            Spot spot = Spot.builder()
                    .tourApiId(c.tourApiId())
                    .titleKo(c.title())
                    .titleEn(c.title()) // TODO: 번역 필요 — 지금은 한글 제목으로 임시 채움
                    .titleJa(c.title()) // TODO: 번역 필요 — 지금은 한글 제목으로 임시 채움
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
        String title = switch (locale == null ? "ko" : locale) {
            case "en" -> s.getTitleEn() != null ? s.getTitleEn() : s.getTitleKo();
            case "ja" -> s.getTitleJa() != null ? s.getTitleJa() : s.getTitleKo();
            default -> s.getTitleKo();
        };
        return SpotResponse.builder()
                .id(s.getSpotId())
                .title(title)
                .lat(s.getLat())
                .lng(s.getLng())
                .category(s.getCategory())
                .imageUrl(s.getImageUrl())
                .address(s.getAddress())
                .build();
    }
}
