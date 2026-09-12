package com.coco.backend.service;

import com.coco.backend.dto.response.SpotResponse;
import com.coco.backend.entity.Spot;
import com.coco.backend.repository.FeedPostRepository;
import com.coco.backend.repository.SpotRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class SpotService {

    private final SpotRepository spotRepository;
    private final TourApiService tourApiService;
    private final KakaoLocalService kakaoLocalService;
    private final FeedPostRepository feedPostRepository;

    // "인기 핀"(trending) 판정 기준값. 아직 실사용 데이터가 없어 임의로 정한 값이라,
    // 실제 유저 활동이 쌓이면 데모/운영 상황에 맞게 조정 필요.
    private static final int TRENDING_POST_COUNT_THRESHOLD = 3;
    private static final long TRENDING_LIKE_COUNT_THRESHOLD = 20;

    /**
     * TourAPI에서 필터링된 후보를 가져와 아직 DB에 없는 것만 저장한다.
     * (다국어 title 컬럼이 현재 엔티티엔 없어서 한글 제목 하나만 저장한다.)
     */
    public int importFromTourApi() {
        List<TourApiService.TourApiCandidate> candidates = tourApiService.fetchCandidates();
        int inserted = 0;

        for (var c : candidates) {
            if (spotRepository.findByTourApiid(c.tourApiId()).isPresent()) continue;

            // 신규 스팟만 소개글을 조회한다 — 이미 있는 스팟까지 매번 다시 부르면 재import할
            // 때마다 쓸데없이 API 호출이 늘어난다(dedupe 체크를 통과한 것만 호출하도록 여기 배치).
            String description = tourApiService.fetchOverview(c.tourApiId());

            Spot spot = Spot.builder()
                    .tourApiid(c.tourApiId())
                    .title(c.title())
                    .lat(c.lat())
                    .lng(c.lng())
                    .address(c.address())
                    .category(c.category())
                    .imageUrl(c.imageUrl())
                    .description(description)
                    .build();
            spotRepository.save(spot);
            inserted++;
        }
        log.info("TourAPI 스팟 임포트 완료: 후보 {}건 중 신규 {}건 저장", candidates.size(), inserted);
        return inserted;
    }

    /**
     * 카카오 로컬 API에서 관광 관련 카테고리로 좁힌 후보를 가져와 아직 DB에 없는 것만 저장한다.
     * TourAPI 임포트와 데이터 소스만 다를 뿐 흐름은 동일 — 중복 체크만 kakao_place_id 기준.
     */
    public int importFromKakaoLocal() {
        List<KakaoLocalService.KakaoLocalCandidate> candidates = kakaoLocalService.fetchCandidates();
        int inserted = 0;

        for (var c : candidates) {
            if (spotRepository.findByKakaoPlaceId(c.kakaoPlaceId()).isPresent()) continue;

            Spot spot = Spot.builder()
                    .kakaoPlaceId(c.kakaoPlaceId())
                    .title(c.title())
                    .lat(c.lat())
                    .lng(c.lng())
                    .address(c.address())
                    .category(c.category())
                    .build();
            spotRepository.save(spot);
            inserted++;
        }
        log.info("카카오 로컬 스팟 임포트 완료: 후보 {}건 중 신규 {}건 저장", candidates.size(), inserted);
        return inserted;
    }

    /** 지도 화면에 보이는 영역(뷰포트) 안의 스팟만 조회 — 핀 밀집 방지의 핵심. */
    public List<SpotResponse> findInViewport(double swLat, double neLat, double swLng, double neLng,
                                              String category, String locale) {
        List<Spot> spots = spotRepository.findInBounds(swLat, neLat, swLng, neLng, category);
        Map<Long, long[]> engagementBySpotId = fetchEngagement(spots);

        return spots.stream()
                .map(s -> toResponse(s, engagementBySpotId.get(s.getId())))
                .toList();
    }

    /** 스팟 상세 화면용 단건 조회. 존재하지 않으면 빈 Optional. */
    public Optional<SpotResponse> getById(Long id) {
        return spotRepository.findById(id)
                .map(spot -> toResponse(spot, fetchEngagement(List.of(spot)).get(spot.getId())));
    }

    // 검색 결과가 너무 많아지는 걸 막는 상한. 코스 만들기 "+ 스팟 추가" 같은 자동완성성
    // 검색이라 페이지네이션 UI까지는 필요 없고, 적당히 잘라서 주는 정도면 충분하다.
    private static final int SEARCH_RESULT_LIMIT = 20;

    /** 제목/주소에 키워드가 포함된 스팟 검색 — 코스 만들기 "+ 스팟 추가" 등에서 사용. */
    public List<SpotResponse> search(String query) {
        List<Spot> spots = spotRepository
                .findByTitleContainingIgnoreCaseOrAddressContainingIgnoreCase(query, query)
                .stream()
                .limit(SEARCH_RESULT_LIMIT)
                .toList();
        Map<Long, long[]> engagementBySpotId = fetchEngagement(spots);
        return spots.stream()
                .map(s -> toResponse(s, engagementBySpotId.get(s.getId())))
                .toList();
    }

    /** 뷰포트 안 스팟들의 (게시물 수, 좋아요 합)을 한 번에 조회. 반환값: spotId -> [postCount, likeSum]. */
    private Map<Long, long[]> fetchEngagement(List<Spot> spots) {
        if (spots.isEmpty()) return Map.of();
        List<Long> spotIds = spots.stream().map(Spot::getId).toList();
        Map<Long, long[]> result = new HashMap<>();
        for (Object[] row : feedPostRepository.aggregateEngagementBySpotIds(spotIds)) {
            Long spotId = (Long) row[0];
            long postCount = ((Number) row[1]).longValue();
            long likeSum = ((Number) row[2]).longValue();
            result.put(spotId, new long[]{postCount, likeSum});
        }
        return result;
    }

    /**
     * 게시물 수/좋아요 합으로 "인기(trending)" 여부를 판정하는 기준.
     * 지도 탭 핀 크기(SpotService)뿐 아니라 피드 탭 인기 배지(FeedService)도
     * 같은 기준을 써야 해서 재사용 가능하게 public으로 뺐다.
     */
    public static boolean isTrending(long postCount, long likeSum) {
        return postCount >= TRENDING_POST_COUNT_THRESHOLD || likeSum >= TRENDING_LIKE_COUNT_THRESHOLD;
    }

    private SpotResponse toResponse(Spot s, long[] engagement) {
        long postCount = engagement != null ? engagement[0] : 0;
        long likeSum = engagement != null ? engagement[1] : 0;
        boolean trending = isTrending(postCount, likeSum);

        return SpotResponse.builder()
                .id(s.getId())
                .title(s.getTitle())
                .lat(s.getLat())
                .lng(s.getLng())
                .category(s.getCategory())
                .imageUrl(s.getImageUrl())
                .address(s.getAddress())
                .description(s.getDescription())
                .isLocalPick(Boolean.TRUE.equals(s.getIsLocalPick()))
                .trending(trending)
                .build();
    }
}
