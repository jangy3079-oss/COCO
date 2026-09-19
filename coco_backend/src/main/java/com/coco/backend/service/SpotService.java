package com.coco.backend.service;

import com.coco.backend.dto.response.LikeToggleResponse;
import com.coco.backend.dto.response.SpotResponse;
import com.coco.backend.entity.Spot;
import com.coco.backend.entity.SpotLike;
import com.coco.backend.entity.User;
import com.coco.backend.repository.FeedPostRepository;
import com.coco.backend.repository.SpotLikeRepository;
import com.coco.backend.repository.SpotRepository;
import com.coco.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class SpotService {

    private final SpotRepository spotRepository;
    private final TourApiService tourApiService;
    private final KakaoLocalService kakaoLocalService;
    private final FeedPostRepository feedPostRepository;
    private final SpotLikeRepository spotLikeRepository;
    private final UserRepository userRepository;

    // "인기 핀"(trending) 판정 기준값. 아직 실사용 데이터가 없어 임의로 정한 값이라,
    // 실제 유저 활동이 쌓이면 데모/운영 상황에 맞게 조정 필요.
    private static final int TRENDING_POST_COUNT_THRESHOLD = 3;
    private static final long TRENDING_LIKE_COUNT_THRESHOLD = 20;

    /**
     * TourAPI에서 필터링된 후보를 가져와 아직 DB에 없는 것만 저장한다.
     * (TourAPI가 현재 한국어 서비스만 연동되어 있어서 titleKo만 채우고, titleEn/titleJa는 번역이 붙을 때까지 null로 둔다.)
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
                    .titleKo(c.title())
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

    // 이름 정규화 후 동일 판정을 내릴 좌표 오차 허용 범위(위도/경도 각각). 약 30m 이내.
    private static final double DUPLICATE_COORD_TOLERANCE = 0.0003;

    /**
     * 카카오 로컬 API에서 관광 관련 카테고리로 좁힌 후보를 가져와 아직 DB에 없는 것만 저장한다.
     * TourAPI 임포트와 데이터 소스만 다를 뿐 흐름은 동일 — kakao_place_id 중복 체크에 더해,
     * TourAPI로 이미 저장된 동일 실제 장소도 걸러낸다(TourAPI 우선).
     */
    public int importFromKakaoLocal() {
        List<KakaoLocalService.KakaoLocalCandidate> candidates = kakaoLocalService.fetchCandidates();

        // TourAPI 출처 스팟을 정규화된 제목 기준으로 그룹핑해두고, 후보를 순회하는 동안
        // DB 재조회 없이 이 메모리 맵만으로 중복 여부를 판단한다.
        Map<String, List<Spot>> tourApiSpotsByNormalizedTitle = spotRepository.findByTourApiidIsNotNull()
                .stream()
                .collect(Collectors.groupingBy(s -> normalizeTitle(s.getTitleKo())));

        int inserted = 0;

        for (var c : candidates) {
            if (spotRepository.findByKakaoPlaceId(c.kakaoPlaceId()).isPresent()) continue;

            if (isDuplicateOfTourApiSpot(c, tourApiSpotsByNormalizedTitle)) continue;

            Spot spot = Spot.builder()
                    .kakaoPlaceId(c.kakaoPlaceId())
                    .titleKo(c.title())
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

    /**
     * 카카오 후보가 TourAPI로 이미 저장된 스팟과 같은 실제 장소인지 판단한다.
     * 판단 기준: 정규화된 제목이 같고, lat/lng 차이가 각각 DUPLICATE_COORD_TOLERANCE 이내.
     *
     * 한계: "낙동강집" vs "낙동강매운탕"처럼 정규화해도 서로 다른 단어가 남는 경우는 이름이
     * 달라서 걸러내지 못한다 — 필요해지면 문자열 유사도(edit distance 등) 도입을 검토할 것.
     */
    private boolean isDuplicateOfTourApiSpot(KakaoLocalService.KakaoLocalCandidate candidate,
                                              Map<String, List<Spot>> tourApiSpotsByNormalizedTitle) {
        String normalizedTitle = normalizeTitle(candidate.title());
        List<Spot> sameTitleSpots = tourApiSpotsByNormalizedTitle.get(normalizedTitle);
        if (sameTitleSpots == null) return false;

        return sameTitleSpots.stream().anyMatch(s ->
                Math.abs(s.getLat() - candidate.lat()) <= DUPLICATE_COORD_TOLERANCE
                        && Math.abs(s.getLng() - candidate.lng()) <= DUPLICATE_COORD_TOLERANCE);
    }

    /** 상호명 표기 차이(공백/괄호/"본점"·"점" 접미사)를 없애 이름 비교를 위한 정규화된 제목을 만든다. */
    private String normalizeTitle(String title) {
        if (title == null) return "";
        return title
                .replaceAll("\\s+", "")
                .replaceAll("\\(.*?\\)", "")
                .replaceAll("본점$|점$", "")
                .trim();
    }

    /** 지도 화면에 보이는 영역(뷰포트) 안의 스팟만 조회 — 핀 밀집 방지의 핵심. */
    public List<SpotResponse> findInViewport(double swLat, double neLat, double swLng, double neLng,
                                              String category, String locale) {
        List<Spot> spots = spotRepository.findInBounds(swLat, neLat, swLng, neLng, category);
        Map<Long, long[]> engagementBySpotId = fetchEngagement(spots);

        return spots.stream()
                .map(s -> toResponse(s, engagementBySpotId.get(s.getId()), locale))
                .toList();
    }

    /** 스팟 상세 화면용 단건 조회. 존재하지 않으면 빈 Optional. */
    public Optional<SpotResponse> getById(Long id, String locale) {
        return spotRepository.findById(id)
                .map(spot -> toResponse(spot, fetchEngagement(List.of(spot)).get(spot.getId()), locale));
    }

    /** 스팟 찜 토글 — 이미 찜했으면 취소, 아니면 새로 찜한다. */
    @Transactional
    public LikeToggleResponse toggleLike(Long userId, Long spotId) {
        Spot spot = spotRepository.findById(spotId)
                .orElseThrow(() -> new IllegalArgumentException("스팟을 찾을 수 없습니다."));

        var existing = spotLikeRepository.findByUser_IdAndSpot_Id(userId, spotId);
        boolean liked;
        if (existing.isPresent()) {
            spotLikeRepository.delete(existing.get());
            liked = false;
        } else {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
            spotLikeRepository.save(SpotLike.builder().user(user).spot(spot).build());
            liked = true;
        }
        int likeCount = (int) spotLikeRepository.countBySpot_Id(spotId);
        return LikeToggleResponse.builder().liked(liked).likeCount(likeCount).build();
    }

    /** 현재 로그인한 유저가 찜한 스팟 목록. */
    public List<SpotResponse> getLikedSpots(Long userId, String locale) {
        List<Spot> spots = spotLikeRepository.findSpotsByUserId(userId);
        Map<Long, long[]> engagementBySpotId = fetchEngagement(spots);
        return spots.stream()
                .map(s -> toResponse(s, engagementBySpotId.get(s.getId()), locale))
                .toList();
    }

    // 검색 결과가 너무 많아지는 걸 막는 상한. 코스 만들기 "+ 스팟 추가" 같은 자동완성성
    // 검색이라 페이지네이션 UI까지는 필요 없고, 적당히 잘라서 주는 정도면 충분하다.
    private static final int SEARCH_RESULT_LIMIT = 20;

    /** 제목/주소에 키워드가 포함된 스팟 검색 — 코스 만들기 "+ 스팟 추가" 등에서 사용. */
    public List<SpotResponse> search(String query, String locale) {
        List<Spot> spots = spotRepository
                .searchByKeyword(query)
                .stream()
                .limit(SEARCH_RESULT_LIMIT)
                .toList();
        Map<Long, long[]> engagementBySpotId = fetchEngagement(spots);
        return spots.stream()
                .map(s -> toResponse(s, engagementBySpotId.get(s.getId()), locale))
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

    private SpotResponse toResponse(Spot s, long[] engagement, String locale) {
        long postCount = engagement != null ? engagement[0] : 0;
        long likeSum = engagement != null ? engagement[1] : 0;
        boolean trending = isTrending(postCount, likeSum);

        return SpotResponse.builder()
                .id(s.getId())
                .title(resolveTitle(s, locale))
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
