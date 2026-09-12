package com.coco.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 카카오맵(카카오 로컬 API)에서 COCO가 다루는 부산 전역(15개 구 + 기장군)의 관광 관련 장소
 * 후보를 가져오는 서비스. TourApiService와 데이터 소스가 완전히 달라서 별도 서비스로 분리했다.
 *
 * TourAPI는 관광공사가 애초에 "관광지/음식점"으로 등록해둔 콘텐츠만 다루는 반면, 카카오 로컬은
 * 카카오맵에 등록된 모든 업체(병원·은행·부동산 포함)를 다뤄서 커버리지는 훨씬 넓지만 그만큼
 * 관광이랑 전혀 무관한 카테고리도 섞여 있다. 그래서 결과를 받은 뒤에 거르는 게 아니라, 애초에
 * 조회 카테고리(category_group_code)를 관광 관련 4종(AT4 관광명소, FD6 음식점, CE7 카페,
 * CT1 문화시설)으로만 제한해서 요청한다 — 관광 무관 카테고리는 요청 단계에서부터 아예 안 들어옴.
 * "공원"은 카카오 카테고리 그룹 코드 목록에 대응하는 코드가 없어서, 동 이름 + "공원" 키워드로
 * category_group_code 없이 별도 조회한다.
 *
 * 카카오 키워드 검색은 쿼리(동×카테고리 조합) 하나당 최대 45건(15건 × 3페이지)까지만 제공하므로,
 * 그 상한까지 페이지를 순회해서 가져온다.
 *
 * TourApiService와 달리 "이미 유명함" 여부로 거르는 인기도 필터는 없다. 인기 판정(트렌딩 표시)은
 * SpotService에서 실제 피드 반응(FeedPost 게시물 수·좋아요) 기준으로 하기로 했으므로 여기서는
 * 다루지 않는다 — 이 서비스는 순수하게 "후보 수집 + 지역/카테고리 필터"만 담당.
 */
@Slf4j
@Service
public class KakaoLocalService {

    // TourApiService와 마찬가지로 RestClient.Builder 빈이 자동 등록되지 않아 직접 생성해서 쓴다.
    private final RestClient restClient = RestClient.create();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${kakao.rest-api-key}")
    private String restApiKey;

    private static final String KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json";

    // COCO가 다루는 법정동/읍면 — 부산 15개 구 + 기장군 전역. 카카오 로컬은 시군구 코드가 아니라
    // 자유 텍스트 쿼리로 지역을 찾기 때문에 동 이름만 있으면 된다.
    private static final List<String> TARGET_DONGS = List.of(
            // 중구
            "중앙동", "동광동", "대청동", "보수동", "부평동", "광복동", "남포동", "영주1동", "영주2동",
            // 서구
            "동대신1동", "동대신2동", "동대신3동", "서대신1동", "서대신2동", "서대신3동", "서대신4동",
            "부민동", "아미동", "초장동", "충무동", "남부민1동", "남부민2동", "암남동",
            // 동구
            "초량1동", "초량2동", "초량3동", "초량6동", "수정1동", "수정2동", "수정4동", "수정5동",
            "좌천동", "범일1동", "범일2동", "범일5동",
            // 영도구
            "남항동", "영선1동", "영선2동", "신선동", "봉래1동", "봉래2동", "청학1동", "청학2동",
            "동삼1동", "동삼2동", "동삼3동",
            // 부산진구
            "부전1동", "부전2동", "연지동", "초읍동", "양정1동", "양정2동", "전포1동", "전포2동",
            "부암1동", "부암3동", "당감1동", "당감2동", "당감4동", "가야1동", "가야2동",
            "개금1동", "개금2동", "개금3동", "범천1동", "범천2동",
            // 동래구
            "수민동", "복산동", "명륜동", "온천1동", "온천2동", "온천3동",
            "사직1동", "사직2동", "사직3동", "안락1동", "안락2동", "명장1동", "명장2동",
            // 남구
            "대연1동", "대연3동", "대연4동", "대연5동", "대연6동",
            "용호1동", "용호2동", "용호3동", "용호4동", "용당동",
            "감만1동", "감만2동", "우암동", "문현1동", "문현2동", "문현3동", "문현4동",
            // 북구
            "구포1동", "구포2동", "구포3동", "금곡동", "화명1동", "화명2동", "화명3동",
            "덕천1동", "덕천2동", "덕천3동", "만덕1동", "만덕2동", "만덕3동",
            // 해운대구
            "우1동", "우2동", "우3동", "중1동", "중2동", "좌1동", "좌2동", "좌3동", "좌4동", "송정동",
            "반여1동", "반여2동", "반여3동", "반여4동", "반송1동", "반송2동", "재송1동", "재송2동",
            // 사하구
            "괴정1동", "괴정2동", "괴정3동", "괴정4동", "당리동", "하단1동", "하단2동",
            "신평1동", "신평2동", "장림1동", "장림2동", "다대1동", "다대2동", "구평동", "감천1동", "감천2동",
            // 금정구
            "서1동", "서2동", "서3동", "금사동", "부곡1동", "부곡2동", "부곡3동", "부곡4동",
            "장전1동", "장전2동", "선두구동", "청룡노포동", "남산동", "구서1동", "구서2동", "금성동",
            // 강서구
            "대저1동", "대저2동", "강동동", "명지1동", "명지2동", "가락동", "녹산동", "가덕도동",
            // 연제구
            "거제1동", "거제2동", "거제3동", "거제4동",
            "연산1동", "연산2동", "연산3동", "연산4동", "연산5동", "연산6동", "연산8동", "연산9동",
            // 수영구
            "남천1동", "남천2동", "수영동", "망미1동", "망미2동",
            "광안1동", "광안2동", "광안3동", "광안4동", "민락동",
            // 사상구
            "삼락동", "모라1동", "모라3동", "덕포1동", "덕포2동", "괘법동", "감전동",
            "주례1동", "주례2동", "주례3동", "학장동", "엄궁동",
            // 기장군
            "기장읍", "장안읍", "정관읍", "일광읍", "철마면"
    );

    // 관광 컨셉과 관련 있는 카테고리 그룹만 조회 대상으로 삼는다 — 나머지(병원/은행/부동산/편의점 등)는
    // 애초에 요청조차 하지 않으므로 결과에 섞일 일이 없다.
    private static final List<String> TARGET_CATEGORY_GROUP_CODES = List.of("AT4", "FD6", "CE7", "CT1");

    // "공원"은 카카오 카테고리 그룹 코드 목록에 대응하는 코드가 없어서, 동 이름 뒤에 이 키워드를
    // 붙여 category_group_code 없는 순수 텍스트 검색으로 따로 조회한다.
    private static final String PARK_KEYWORD_SUFFIX = " 공원";

    private static final int PAGE_SIZE = 15; // 카카오 로컬 API 한 페이지 최대치
    private static final int MAX_PAGE = 3; // size 15 * 3페이지 = 45건 (카카오 키워드 검색 쿼리당 상한)

    /** 관광 관련 카테고리 + 공원 키워드로 좁힌 후보 목록을 가져온다. */
    public List<KakaoLocalCandidate> fetchCandidates() {
        List<KakaoLocalCandidate> result = new ArrayList<>();
        Set<String> seenPlaceIds = new HashSet<>();

        for (String dong : TARGET_DONGS) {
            for (String categoryGroupCode : TARGET_CATEGORY_GROUP_CODES) {
                try {
                    String cocoCategory = mapToCocoCategory(categoryGroupCode);
                    for (JsonNode item : callKeywordSearch(dong, categoryGroupCode)) {
                        addCandidate(result, seenPlaceIds, item, dong, cocoCategory);
                    }
                } catch (Exception e) {
                    log.warn("카카오 로컬 조회 실패 (dong={}, categoryGroupCode={}): {}", dong, categoryGroupCode, e.getMessage());
                }
            }
            // 공원은 카테고리 코드가 없어서 "{동} 공원" 자유 텍스트로 따로 조회한다.
            try {
                for (JsonNode item : callKeywordSearch(dong + PARK_KEYWORD_SUFFIX, null)) {
                    addCandidate(result, seenPlaceIds, item, dong, "공원");
                }
            } catch (Exception e) {
                log.warn("카카오 로컬 공원 조회 실패 (dong={}): {}", dong, e.getMessage());
            }
        }
        log.info("카카오 로컬 후보 수집 완료: {}건", result.size());
        return result;
    }

    private void addCandidate(List<KakaoLocalCandidate> result, Set<String> seenPlaceIds,
                               JsonNode item, String targetDong, String cocoCategory) {
        KakaoLocalCandidate candidate = toCandidate(item, targetDong, cocoCategory);
        if (candidate == null) return; // 지번 주소에 동 이름이 없어서 걸러짐
        if (!seenPlaceIds.add(candidate.kakaoPlaceId())) return; // 여러 조회에 동시 매칭되는 경우 중복 방지
        result.add(candidate);
    }

    /**
     * query 하나당 최대 MAX_PAGE 페이지(총 45건)까지 가져온다.
     * categoryGroupCode가 null이면 필터 없이 순수 키워드 검색(공원 조회용).
     */
    private List<JsonNode> callKeywordSearch(String query, String categoryGroupCode) {
        List<JsonNode> all = new ArrayList<>();
        for (int page = 1; page <= MAX_PAGE; page++) {
            JsonNode root = fetchPage(query, categoryGroupCode, page);
            JsonNode documents = root.path("documents");
            documents.forEach(all::add);
            boolean isEnd = root.path("meta").path("is_end").asBoolean(true);
            if (isEnd || documents.isEmpty()) break; // 더 이상 페이지가 없으면 중단
        }
        return all;
    }

    private JsonNode fetchPage(String query, String categoryGroupCode, int page) {
        String encodedQuery = URLEncoder.encode(query, StandardCharsets.UTF_8);
        StringBuilder url = new StringBuilder(KEYWORD_SEARCH_URL)
                .append("?query=").append(encodedQuery);
        if (categoryGroupCode != null) {
            url.append("&category_group_code=").append(categoryGroupCode);
        }
        url.append("&page=").append(page).append("&size=").append(PAGE_SIZE);

        String body = restClient.get()
                .uri(URI.create(url.toString()))
                .header("Authorization", "KakaoAK " + restApiKey)
                .retrieve()
                .body(String.class);
        try {
            return objectMapper.readTree(body);
        } catch (Exception e) {
            log.warn("카카오 로컬 응답 파싱 실패: {}", e.getMessage());
            return objectMapper.createObjectNode();
        }
    }

    private KakaoLocalCandidate toCandidate(JsonNode item, String targetDong, String cocoCategory) {
        // 키워드 검색은 동명이인 지역이 섞여 나올 수 있어, 지번 주소에 목표 동 이름이 실제로
        // 있는지 한 번 더 확인한다 (도로명 주소는 동 이름을 안 담는 경우가 많아 지번만 본다).
        String addressName = item.path("address_name").asText("");
        if (!addressName.contains(targetDong)) return null;

        String placeId = item.path("id").asText(null);
        String title = item.path("place_name").asText(null);
        if (placeId == null || title == null) return null;

        // 카카오 로컬은 x=경도, y=위도 (TourAPI의 mapx/mapy와 반대 순서라 헷갈리기 쉬움).
        double lng = item.path("x").asDouble(0);
        double lat = item.path("y").asDouble(0);
        if (lat == 0 || lng == 0) return null;

        String roadAddressName = item.path("road_address_name").asText("");
        String address = !roadAddressName.isBlank() ? roadAddressName : addressName;

        return new KakaoLocalCandidate(placeId, title, address, lat, lng, cocoCategory);
    }

    // 카카오 카테고리 그룹 → COCO 스팟 카테고리(노포|공원|카페|골목) 매핑.
    // "공원"은 이 매핑을 안 거치고 fetchCandidates()에서 직접 지정한다(카테고리 그룹 코드가 없음).
    private String mapToCocoCategory(String categoryGroupCode) {
        return switch (categoryGroupCode) {
            case "FD6" -> "노포";
            case "CE7" -> "카페";
            default -> "골목"; // AT4(관광명소), CT1(문화시설)
        };
    }

    public record KakaoLocalCandidate(
            String kakaoPlaceId,
            String title,
            String address,
            double lat,
            double lng,
            String category
    ) {}
}
