package com.coco.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.URI;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 한국관광공사 TourAPI에서 COCO가 다루는 몇 개 동네(법정동)의 관광지/음식점 후보만
 * 좁혀서 가져오는 서비스. COCO는 "광안리·해운대 너머 숨겨진 로컬 골목"을 큐레이션하는
 * 컨셉이라, TourAPI 데이터를 있는 그대로 다 지도에 뿌리면 오히려 컨셉과 어긋나고
 * 핀도 너무 많아진다 — 그래서 아래 3단계로 후보 자체를 좁힌 뒤에 저장한다.
 *
 * <ol>
 *   <li>지역 — 부산 시군구 코드로 조회한 뒤, 응답의 주소 문자열에 목표 법정동 이름이
 *       포함된 것만 남긴다. (TourAPI areaBasedList는 시군구 단위까지만 파라미터로 지원하고
 *       법정동 단위 필터는 없어서, 응답을 받은 뒤 addr1/addr2 문자열로 한 번 더 거른다.)</li>
 *   <li>카테고리 — contentTypeId(관광지=12, 음식점=39)로 좁히고, 그 안에서도 cat3(소분류)
 *       화이트리스트에 있는 것만 통과시킨다.</li>
 *   <li>인기도 — 제목이 랜드마크 블랙리스트에 걸리거나, 관광지별 연관 관광지
 *       (TarRlteTarService) 연결성 순위가 지역 내 상위 N위 안에 들면 "이미 유명한 곳"으로
 *       보고 제외한다.</li>
 * </ol>
 *
 * TODO(운영 전 재확인): KOR_SERVICE_PATH(KorService1 vs KorService2)는 아직 실제 인증키로
 * 검증 전 추정값이다. CAT3_WHITELIST는 실제 서비스키로 3개 동 후보를 직접 조회한 뒤
 * categoryCode2로 이름을 대조해 확정한 값 — 아래 CAT3_WHITELIST 주석 참고.
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

    @Value("${tour-api.tar-rlte-tar-path:TarRlteTarService1}")
    private String tarRlteTarPath;

    private static final String MOBILE_APP = "coco";

    // 관광지(12), 음식점(39)만 — 골목 큐레이션 컨셉과 무관한 숙박/쇼핑/레포츠/문화시설/축제는 제외.
    private static final List<Integer> TARGET_CONTENT_TYPE_IDS = List.of(12, 39);

    // 3개 동에서 실제 조회되는 cat3는 12종뿐이라, 그 전수를 categoryCode2로 이름 대조해서
    // "관광이랑 연관 있는지"로 포함/제외를 확정했다 (2026-09-10 실제 API 키로 검증).
    // 제외한 4종과 이유:
    //   A02020800 유람선/잠수함관광 — 골목 큐레이션과 무관한 대형 투어 상품
    //   A02010900 종교성지            — 관광지라기보다 순수 신앙시설
    //   A05020200 서양식              — 프랜차이즈 성격이 강해 "노포/로컬" 컨셉과 거리
    //   A05020400 중식                — 위와 동일
    private static final Set<String> CAT3_WHITELIST = Set.of(
            "A02030600", // 이색거리
            "A02020200", // 관광단지
            "A02020700", // 공원
            "A02010800", // 사찰
            "A02010700", // 유적지/사적지
            "A02050600", // 유명건물
            "A05020100", // 한식
            "A05020900"  // 카페/전통찻집
    );

    // 이미 다 아는 대형 랜드마크는 오히려 제외 — 제목에 이 키워드가 포함되면 후보에서 뺀다.
    private static final List<String> LANDMARK_BLACKLIST = List.of(
            "해운대해수욕장", "광안리해수욕장", "광안대교", "감천문화마을", "태종대", "자갈치시장", "국제시장"
    );

    // COCO가 다루는 법정동 → 그 동이 속한 부산 시군구 코드.
    // (지역코드조회(areaCode2, areaCode=6) 실제 응답으로 검증한 값: 중구=15, 동구=5.
    //  이전엔 중구=1/동구=3으로 잘못 들어가 있었는데, 실제 1번은 강서구라 완전히 다른 동네
    //  데이터를 가져온 뒤 동 이름 필터에서 전부 걸러지고 있었음 — import 0건의 원인.)
    private static final int BUSAN_AREA_CODE = 6;
    private static final Map<String, Integer> TARGET_DONG_TO_SIGUNGU = Map.of(
            "남포동", 15,
            "영주동", 15,
            "초량동", 5
    );

    // 관광지별 연관 관광지(TarRlteTarService) 연결성 상위 몇 위까지를 "이미 유명함"으로 보고 뺄지.
    private static final int FAMOUS_RANK_CUTOFF = 10;

    /** 3단계 필터를 모두 통과한 후보 목록을 가져온다. */
    public List<TourApiCandidate> fetchCandidates() {
        Set<String> famousContentIds = fetchFamousContentIds();
        List<TourApiCandidate> result = new ArrayList<>();

        for (var entry : TARGET_DONG_TO_SIGUNGU.entrySet()) {
            String dong = entry.getKey();
            int sigunguCode = entry.getValue();

            for (int contentTypeId : TARGET_CONTENT_TYPE_IDS) {
                try {
                    for (JsonNode item : callAreaBasedList(sigunguCode, contentTypeId)) {
                        TourApiCandidate candidate = toCandidate(item, dong);
                        if (candidate == null) continue; // 주소에 목표 동 이름이 없어서 걸러짐
                        if (isBlacklisted(candidate.title())) continue;
                        if (famousContentIds.contains(candidate.tourApiId())) continue;
                        if (!CAT3_WHITELIST.contains(candidate.cat3())) continue;
                        result.add(candidate);
                    }
                } catch (Exception e) {
                    log.warn("TourAPI 조회 실패 (dong={}, contentTypeId={}): {}", dong, contentTypeId, e.getMessage());
                }
            }
        }
        return result;
    }

    private List<JsonNode> callAreaBasedList(int sigunguCode, int contentTypeId) {
        // serviceKey(공공데이터포털 Decoding 키)는 이미 URL에 넣을 수 있는 형태라 재인코딩하면
        // 오히려 이중 인코딩 오류가 난다 — 문자열을 그대로 이어붙인 뒤 URI.create로 감싼다.
        URI uri = URI.create(baseUrl + "/" + korServicePath + "/areaBasedList2"
                + "?serviceKey=" + serviceKey
                + "&MobileOS=ETC&MobileApp=" + MOBILE_APP
                + "&_type=json&numOfRows=100&pageNo=1&arrange=A"
                + "&areaCode=" + BUSAN_AREA_CODE
                + "&sigunguCode=" + sigunguCode
                + "&contentTypeId=" + contentTypeId);
        String body = restClient.get().uri(uri).retrieve().body(String.class);
        return extractItems(body);
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

    private Set<String> fetchFamousContentIds() {
        Set<String> famous = new HashSet<>();
        // TarRlteTarService는 월 단위 집계라 최신 달은 아직 안 쌓였을 수 있어 2개월 전 기준으로 조회.
        String baseYm = YearMonth.now().minusMonths(2).format(DateTimeFormatter.ofPattern("yyyyMM"));

        for (int sigunguCode : Set.copyOf(TARGET_DONG_TO_SIGUNGU.values())) {
            try {
                URI uri = URI.create(baseUrl + "/" + tarRlteTarPath + "/areaBasedList1"
                        + "?serviceKey=" + serviceKey
                        + "&MobileOS=ETC&MobileApp=" + MOBILE_APP
                        + "&_type=json&numOfRows=" + FAMOUS_RANK_CUTOFF + "&pageNo=1"
                        + "&baseYm=" + baseYm
                        + "&areaCd=" + BUSAN_AREA_CODE
                        + "&signguCd=" + sigunguCode);
                String body = restClient.get().uri(uri).retrieve().body(String.class);
                for (JsonNode item : extractItems(body)) {
                    // 응답 필드명(rlteCid 등)은 실제 키로 확인 전이라 없으면 contentid로 폴백.
                    JsonNode id = item.hasNonNull("rlteCid") ? item.get("rlteCid") : item.get("contentid");
                    if (id != null) famous.add(id.asText());
                }
            } catch (Exception e) {
                log.warn("연관 관광지 조회 실패 (sigunguCode={}): {}", sigunguCode, e.getMessage());
            }
        }
        return famous;
    }

    private List<JsonNode> extractItems(String jsonBody) {
        try {
            JsonNode root = objectMapper.readTree(jsonBody);
            JsonNode itemNode = root.path("response").path("body").path("items").path("item");
            if (itemNode.isMissingNode() || itemNode.isNull()) return List.of();
            if (itemNode.isArray()) {
                List<JsonNode> list = new ArrayList<>();
                itemNode.forEach(list::add);
                return list;
            }
            // TourAPI는 결과가 1건일 때 item이 배열이 아니라 객체 하나로 온다 — 그대로 감싸서 반환.
            return List.of(itemNode);
        } catch (Exception e) {
            log.warn("TourAPI 응답 파싱 실패: {}", e.getMessage());
            return List.of();
        }
    }

    private TourApiCandidate toCandidate(JsonNode item, String targetDong) {
        String addr1 = item.path("addr1").asText("");
        String addr2 = item.path("addr2").asText("");
        if (!addr1.contains(targetDong) && !addr2.contains(targetDong)) return null;

        String contentId = item.path("contentid").asText(null);
        String title = item.path("title").asText(null);
        if (contentId == null || title == null) return null;

        double lat = item.path("mapy").asDouble(0); // TourAPI 필드명 기준 mapy=위도, mapx=경도
        double lng = item.path("mapx").asDouble(0);
        if (lat == 0 || lng == 0) return null;

        String contentTypeId = item.path("contenttypeid").asText("");
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
                cat3
        );
    }

    // TourAPI 카테고리 → COCO 스팟 카테고리(노포|공원|카페|골목) 매핑.
    // TODO(검증 필요): cat3 실제값 확인 후 매핑 정교화.
    private String mapToCocoCategory(String contentTypeId, String cat3) {
        if ("39".equals(contentTypeId)) return "노포";
        if (cat3.startsWith("A0401")) return "골목"; // 시장/거리 계열(추정)
        return "골목";
    }

    private boolean isBlacklisted(String title) {
        return LANDMARK_BLACKLIST.stream().anyMatch(title::contains);
    }

    public record TourApiCandidate(
            String tourApiId,
            String title,
            String address,
            double lat,
            double lng,
            String imageUrl,
            String category,
            String cat3
    ) {}
}
