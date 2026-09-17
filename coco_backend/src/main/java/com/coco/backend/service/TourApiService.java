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
import java.util.Set;

/**
 * 한국관광공사 TourAPI에서 부산 전역의 관광지/음식점/문화시설 후보를 가져오는 서비스.
 * COCO는 "광안리·해운대 너머 숨겨진 로컬 골목"을 큐레이션하는 컨셉이라, TourAPI 데이터를
 * 있는 그대로 다 지도에 뿌리면 오히려 컨셉과 어긋나고 핀도 너무 많아진다 — 그래서 아래
 * 2단계로 후보 자체를 좁힌 뒤에 저장한다.
 *
 * <ol>
 *   <li>지역 — 부산 15개 구 + 기장군 전체 시군구 코드로 조회한다 (부산 전역이 목표라
 *       더 이상 법정동 단위로 좁히지 않는다).</li>
 *   <li>카테고리 — contentTypeId(관광지=12, 문화시설=14, 음식점=39)로 좁히고, 그 안에서도
 *       cat3(소분류) 화이트리스트에 있는 것만 통과시킨다.</li>
 *   <li>인기도 — 제목이 랜드마크 블랙리스트에 걸리거나, 관광지별 연관 관광지
 *       (TarRlteTarService) 연결성 순위가 지역 내 상위 N위 안에 들면 "이미 유명한 곳"으로
 *       보고 제외한다.</li>
 * </ol>
 *
 * TODO(운영 전 재확인): KOR_SERVICE_PATH(KorService1 vs KorService2)는 아직 실제 인증키로
 * 검증 전 추정값이다. CAT3_WHITELIST는 실제 서비스키로 조회한 후보를 직접 확인한 뒤
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

    // 관광지(12), 문화시설(14), 음식점(39) — 골목 큐레이션 컨셉과 무관한 숙박/쇼핑/레포츠/축제는 제외.
    private static final List<Integer> TARGET_CONTENT_TYPE_IDS = List.of(12, 14, 39);

    // COCO 카테고리(음식점|카페|공원|골목|명소) 확정 매핑 기준으로 좁힌 cat3 화이트리스트.
    // (2026-09-10 실제 API 키로 검증, 2026-09-17 Notion "데이터셋" 문서 기준 카테고리 재정의 반영)
    //   A05020100 한식(음식점), A05020900 카페/전통찻집(카페), A02020700 공원(공원),
    //   A02030600 이색거리(골목), A02020200/A02010800/A02010700/A02050600 관광단지/사찰/
    //   유적지·사적지/유명건물(명소)
    // contenttypeid=14(문화시설)는 화이트리스트 미적용, 추후 실데이터 검증 후 좁힐 예정.
    private static final Set<String> CAT3_WHITELIST = Set.of(
            "A02030600", // 이색거리 (골목)
            "A02020200", // 관광단지 (명소)
            "A02020700", // 공원 (공원)
            "A02010800", // 사찰 (명소)
            "A02010700", // 유적지/사적지 (명소)
            "A02050600", // 유명건물 (명소)
            "A05020100", // 한식 (음식점)
            "A05020900"  // 카페/전통찻집 (카페)
    );

    // 이미 다 아는 대형 랜드마크는 오히려 제외 — 제목에 이 키워드가 포함되면 후보에서 뺀다.
    private static final List<String> LANDMARK_BLACKLIST = List.of(
            "해운대해수욕장", "광안리해수욕장", "광안대교", "감천문화마을", "태종대", "자갈치시장", "국제시장"
    );

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

    // 관광지별 연관 관광지(TarRlteTarService) 연결성 상위 몇 위까지를 "이미 유명함"으로 보고 뺄지.
    private static final int FAMOUS_RANK_CUTOFF = 10;

    /** 부산 전역 시군구 × 카테고리 조합으로 2단계 필터를 모두 통과한 후보 목록을 가져온다. */
    public List<TourApiCandidate> fetchCandidates() {
        Set<String> famousContentIds = fetchFamousContentIds();
        List<TourApiCandidate> result = new ArrayList<>();

        for (int sigunguCode : BUSAN_SIGUNGU_CODES) {
            for (int contentTypeId : TARGET_CONTENT_TYPE_IDS) {
                try {
                    for (JsonNode item : callAreaBasedList(sigunguCode, contentTypeId)) {
                        TourApiCandidate candidate = toCandidate(item);
                        if (candidate == null) continue;
                        if (isBlacklisted(candidate.title())) continue;
                        if (famousContentIds.contains(candidate.tourApiId())) continue;
                        // contenttypeid=14(문화시설)는 아직 화이트리스트가 없어 무조건 통과.
                        if (contentTypeId != 14 && !CAT3_WHITELIST.contains(candidate.cat3())) continue;
                        result.add(candidate);
                    }
                } catch (Exception e) {
                    log.warn("TourAPI 조회 실패 (sigunguCode={}, contentTypeId={}): {}", sigunguCode, contentTypeId, e.getMessage());
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

        for (int sigunguCode : BUSAN_SIGUNGU_CODES) {
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

    // TourAPI 카테고리 → COCO 스팟 카테고리(음식점|카페|공원|골목|문화시설|명소) 매핑.
    private String mapToCocoCategory(String contentTypeId, String cat3) {
        if ("A02020700".equals(cat3)) return "공원";
        if ("A05020900".equals(cat3)) return "카페";
        if ("A02030600".equals(cat3)) return "골목"; // 이색거리
        if ("A05020100".equals(cat3) || "39".equals(contentTypeId)) return "음식점";
        if ("14".equals(contentTypeId)) return "문화시설";
        return "명소"; // 관광단지/사찰/유적지/유명건물 등 나머지 관광지(12) 계열
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
