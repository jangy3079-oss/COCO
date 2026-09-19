package com.coco.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * 한국관광공사 TourAPI에서 부산 전역(16개 구·군 × 전체 8개 콘텐츠 유형)의 관광 후보를
 * 전부 가져오는 서비스. 예전엔 "숨겨진 로컬 골목" 컨셉에 맞춰 콘텐츠 유형/소분류/인기도로
 * 후보 자체를 좁혀서 저장했지만, 이제 유명 관광지도 포함해 부산 전역 데이터를 다 수집하고
 * (원본 분류값도 spots 테이블에 그대로 보존) 카테고리 매핑만 해서 넘기기로 결정됐다 —
 * "명소/골목" 등 6개 지도 카테고리 밖으로 매핑되는 유형(숙박/쇼핑/레포츠 등)은 "기타"로
 * 분류되어 SpotService.findMapSpots()에서 걸러진다.
 *
 * <ol>
 *   <li>지역 — 부산 15개 구 + 기장군 전체 시군구 코드로 조회한다.</li>
 *   <li>콘텐츠 유형 — areaBasedList2가 지원하는 8종(관광지/문화시설/축제공연행사/여행코스/
 *       레포츠/숙박/쇼핑/음식점) 전체를 순회한다.</li>
 *   <li>페이지네이션 — 시군구×콘텐츠유형 조합마다 totalCount를 기준으로 마지막 페이지까지
 *       끝까지 조회한다(한 페이지 최대 100건).</li>
 * </ol>
 *
 * TODO(운영 전 재확인): KOR_SERVICE_PATH(KorService1 vs KorService2)는 아직 실제 인증키로
 * 검증 전 추정값이다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TourApiService {

    // 이 프로젝트의 spring-boot-starter-webmvc 구성에서는 RestClient.Builder 빈이
    // 자동 등록되지 않아(스프링 컨텍스트 로딩 시 NoSuchBeanDefinitionException 발생),
    // DI 대신 RestClient.create()로 직접 생성해서 쓴다.
    private final RestClient restClient = RestClient.create();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${tour-api.base-url}")
    private String baseUrl;

    @Value("${tour-api.key}")
    private String serviceKey;

    // TourAPI가 버전을 올릴 때 여기 값만 바꾸면 되도록 코드에서 분리 — application.yml 참고.
    @Value("${tour-api.kor-service-path:KorService2}")
    private String korServicePath;

    private static final String MOBILE_APP = "coco";

    // areaBasedList2가 지원하는 콘텐츠 유형 전체 — 이제 필터 없이 8종 모두 수집한다.
    // 12 관광지, 14 문화시설, 15 축제공연행사, 25 여행코스, 28 레포츠, 32 숙박, 38 쇼핑, 39 음식점.
    private static final List<Integer> ALL_CONTENT_TYPE_IDS = List.of(12, 14, 15, 25, 28, 32, 38, 39);

    // areaBasedList2 한 페이지 최대 건수 — totalCount 기준으로 이 값만큼씩 페이지를 넘긴다.
    private static final int AREA_BASED_PAGE_SIZE = 100;

    // 한 페이지 조회가 일시적으로 실패해도 바로 포기하지 않고 이만큼 재시도한다.
    private static final int MAX_RETRY = 3;

    // 부산 15개 구 + 기장군 시군구 코드 전체.
    // (지역코드조회(areaCode2, areaCode=6) 실제 응답으로 검증 — 2026-09-17.
    //  이전엔 3개 동만 하드코딩하면서 중구=1/동구=3으로 잘못 들어가 있었는데, 실제 1번은
    //  강서구라 완전히 다른 동네 데이터를 가져온 뒤 동 이름 필터에서 전부 걸러지고 있었음
    //  — import 0건의 원인. 이번엔 areaCode2 실제 호출 결과를 그대로 옮겨적었다:
    //  1=강서구, 2=금정구, 3=기장군, 4=남구, 5=동구, 6=동래구, 7=부산진구, 8=북구, 9=사상구,
    //  10=사하구, 11=서구, 12=수영구, 13=연제구, 14=영도구, 15=중구, 16=해운대구.
    //  부산 전역이 목표라 더 이상 "동 이름"으로 좁힐 필요가 없어 시군구 코드로만 순회한다.)
    private static final int BUSAN_AREA_CODE = 6;
    private static final List<Integer> BUSAN_SIGUNGU_CODES = List.of(
            1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
    );

    /** 부산 전역 시군구 × 콘텐츠 유형(8종) 조합으로 전체 페이지를 끝까지 조회한 후보 목록을 가져온다. */
    public List<TourApiCandidate> fetchCandidates() {
        List<TourApiCandidate> result = new ArrayList<>();

        for (int sigunguCode : BUSAN_SIGUNGU_CODES) {
            for (int contentTypeId : ALL_CONTENT_TYPE_IDS) {
                try {
                    for (JsonNode item : callAreaBasedList(sigunguCode, contentTypeId)) {
                        TourApiCandidate candidate = toCandidate(item);
                        if (candidate == null) continue;
                        result.add(candidate);
                    }
                } catch (Exception e) {
                    log.warn("TourAPI 조회 실패 (sigunguCode={}, contentTypeId={}): {}", sigunguCode, contentTypeId, e.getMessage());
                }
            }
        }
        return result;
    }

    /**
     * 시군구×콘텐츠유형 조합 하나에 대해 totalCount를 기준으로 마지막 페이지까지 끝까지 조회한다.
     * 페이지 하나가 재시도(MAX_RETRY)까지 전부 실패하면 그 지점에서 이 조합의 수집을 중단한다
     * (이미 모은 페이지까지는 버리지 않고 반환).
     */
    private List<JsonNode> callAreaBasedList(int sigunguCode, int contentTypeId) {
        List<JsonNode> all = new ArrayList<>();
        int pageNo = 1;
        int totalCount = Integer.MAX_VALUE; // 첫 응답을 받기 전엔 모르니 일단 큰 값으로 잡아 루프에 진입시킨다.

        while ((long) (pageNo - 1) * AREA_BASED_PAGE_SIZE < totalCount) {
            JsonNode root = fetchAreaBasedListPage(sigunguCode, contentTypeId, pageNo);
            if (root == null) break; // 재시도까지 다 실패 — 여기까지 모은 것만 반환.

            totalCount = root.path("response").path("body").path("totalCount").asInt(0);
            List<JsonNode> items = extractItems(root);
            if (items.isEmpty()) break;

            all.addAll(items);
            pageNo++;
        }
        return all;
    }

    /** areaBasedList2 한 페이지를 조회한다. 일시적 실패에 대비해 MAX_RETRY까지 재시도하고, 그래도 실패하면 null. */
    private JsonNode fetchAreaBasedListPage(int sigunguCode, int contentTypeId, int pageNo) {
        for (int attempt = 1; attempt <= MAX_RETRY; attempt++) {
            try {
                // serviceKey(공공데이터포털 Decoding 키)는 이미 URL에 넣을 수 있는 형태라 재인코딩하면
                // 오히려 이중 인코딩 오류가 난다 — 문자열을 그대로 이어붙인 뒤 URI.create로 감싼다.
                URI uri = URI.create(baseUrl + "/" + korServicePath + "/areaBasedList2"
                        + "?serviceKey=" + serviceKey
                        + "&MobileOS=ETC&MobileApp=" + MOBILE_APP
                        + "&_type=json&numOfRows=" + AREA_BASED_PAGE_SIZE + "&pageNo=" + pageNo + "&arrange=A"
                        + "&areaCode=" + BUSAN_AREA_CODE
                        + "&sigunguCode=" + sigunguCode
                        + "&contentTypeId=" + contentTypeId);
                String body = restClient.get().uri(uri).retrieve().body(String.class);
                return objectMapper.readTree(body);
            } catch (Exception e) {
                log.warn("TourAPI 지역기반 목록 조회 실패 (sigunguCode={}, contentTypeId={}, pageNo={}, {}/{}회 시도): {}",
                        sigunguCode, contentTypeId, pageNo, attempt, MAX_RETRY, e.getMessage());
            }
        }
        return null;
    }

    /**
     * 스팟 상세 화면 소개글용 — detailCommon2의 overview 필드.
     * (실제 키로 확인해보니 이 API는 contentTypeId/defaultYN 등 부가 파라미터를 같이 보내면
     * INVALID_REQUEST_PARAMETER_ERROR가 나고, contentId 하나만 보내야 정상 응답한다 — 문서와
     * 다르게 동작해서 실제 호출로 확인한 그대로 맞춰뒀다.)
     * 실패하거나 overview가 없으면 null — 신규 스팟 저장 자체를 막을 정도로 중요하지 않아서
     * 호출부에서 계속 진행 가능하게 null만 반환한다.
     */
    public String fetchOverview(String contentId) {
        try {
            URI uri = URI.create(baseUrl + "/" + korServicePath + "/detailCommon2"
                    + "?serviceKey=" + serviceKey
                    + "&MobileOS=ETC&MobileApp=" + MOBILE_APP
                    + "&_type=json&contentId=" + contentId);
            String body = restClient.get().uri(uri).retrieve().body(String.class);
            List<JsonNode> items = extractItems(body);
            if (items.isEmpty()) return null;
            String overview = items.get(0).path("overview").asText("");
            return overview.isBlank() ? null : overview;
        } catch (Exception e) {
            log.warn("TourAPI 소개글 조회 실패 (contentId={}): {}", contentId, e.getMessage());
            return null;
        }
    }

    /**
     * 스팟 상세 화면 사진 갤러리용 — detailImage2의 전체 이미지 목록.
     * (originimgurl이 있으면 원본 화질을 쓰고, 없으면 smallimageurl로 폴백한다.
     * TODO(운영 전 재확인): detailCommon2가 문서와 실제 동작이 달랐던 전례가 있어서
     * (아래 fetchOverview() 주석 참고), detailImage2도 실제 서비스키로 호출해서
     * 파라미터(imageYN 등)와 응답 필드명(originimgurl/smallimageurl)이 맞는지
     * 검증이 필요하다 — 이 프로젝트는 아직 그 검증 전이라 문서 기준으로 구현했다.)
     * fetchOverview()와 동일하게 실패하거나 결과가 없으면 빈 리스트를 반환하고,
     * 이 호출 실패가 스팟 저장 자체를 막지 않도록 한다.
     */
    public List<String> fetchDetailImages(String contentId) {
        try {
            URI uri = URI.create(baseUrl + "/" + korServicePath + "/detailImage2"
                    + "?serviceKey=" + serviceKey
                    + "&MobileOS=ETC&MobileApp=" + MOBILE_APP
                    + "&_type=json&contentId=" + contentId + "&imageYN=Y");
            String body = restClient.get().uri(uri).retrieve().body(String.class);
            List<JsonNode> items = extractItems(body);
            return items.stream()
                    .map(item -> {
                        String url = item.path("originimgurl").asText("");
                        return url.isBlank() ? item.path("smallimageurl").asText("") : url;
                    })
                    .filter(url -> !url.isBlank())
                    .toList();
        } catch (Exception e) {
            log.warn("TourAPI 이미지 목록 조회 실패 (contentId={}): {}", contentId, e.getMessage());
            return List.of();
        }
    }

    private List<JsonNode> extractItems(JsonNode root) {
        JsonNode itemNode = root.path("response").path("body").path("items").path("item");
        if (itemNode.isMissingNode() || itemNode.isNull()) return List.of();
        if (itemNode.isArray()) {
            List<JsonNode> list = new ArrayList<>();
            itemNode.forEach(list::add);
            return list;
        }
        // TourAPI는 결과가 1건일 때 item이 배열이 아니라 객체 하나로 온다 — 그대로 감싸서 반환.
        return List.of(itemNode);
    }

    private List<JsonNode> extractItems(String jsonBody) {
        try {
            return extractItems(objectMapper.readTree(jsonBody));
        } catch (Exception e) {
            log.warn("TourAPI 응답 파싱 실패: {}", e.getMessage());
            return List.of();
        }
    }

    private TourApiCandidate toCandidate(JsonNode item) {
        String addr1 = item.path("addr1").asText("");
        String addr2 = item.path("addr2").asText("");

        String contentId = item.path("contentid").asText(null);
        String title = item.path("title").asText(null);
        if (contentId == null || title == null) return null;

        double lat = item.path("mapy").asDouble(0); // TourAPI 필드명 기준 mapy=위도, mapx=경도
        double lng = item.path("mapx").asDouble(0);
        if (lat == 0 || lng == 0) return null;

        String contentTypeId = item.path("contenttypeid").asText("");
        String cat1 = item.path("cat1").asText("");
        String cat2 = item.path("cat2").asText("");
        String cat3 = item.path("cat3").asText("");
        String image = item.path("firstimage").asText("");

        return new TourApiCandidate(
                contentId,
                title,
                (addr1 + " " + addr2).trim(),
                lat,
                lng,
                image,
                mapToCocoCategory(contentTypeId, cat3),
                contentTypeId,
                cat1,
                cat2,
                cat3
        );
    }

    // TourAPI 원본 분류 → COCO 지도 카테고리 매핑. 화이트리스트가 없어졌으니 6개 카테고리에
    // 정확히 해당하는 조건만 명시적으로 매핑하고, 나머지는 전부 "기타"로 떨어뜨린다 — 여기서
    // "명소"를 default fallback으로 두면 목욕탕/스키장 같은 관광지(12) 계열이 전부 "명소"로
    // 잘못 분류된다.
    private String mapToCocoCategory(String contentTypeId, String cat3) {
        if ("A02020700".equals(cat3)) return "공원";
        if ("A05020900".equals(cat3)) return "카페";
        if ("A02030600".equals(cat3)) return "골목";
        if ("39".equals(contentTypeId)) return "음식점";
        if ("14".equals(contentTypeId)) return "문화시설";
        if ("12".equals(contentTypeId)
                && Set.of("A02020200", "A02010800", "A02010700", "A02050600").contains(cat3)) {
            return "명소"; // 관광단지/사찰/유적지·사적지/유명건물
        }
        return "기타"; // 15 축제공연행사, 25 여행코스, 28 레포츠, 32 숙박, 38 쇼핑,
                        // 그 외 미분류 관광지(12) 등
    }

    public record TourApiCandidate(
            String tourApiId,
            String title,
            String address,
            double lat,
            double lng,
            String imageUrl,
            String category,
            String contentTypeId,
            String cat1,
            String cat2,
            String cat3
    ) {}
}
