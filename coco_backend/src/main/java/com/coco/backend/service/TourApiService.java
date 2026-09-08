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
 * TODO(운영 전 필수 확인): CAT3_WHITELIST와 KOR_SERVICE_PATH는 실제 인증키로 서비스분류코드조회
 * (categoryCode2)와 api.visitkorea.or.kr 문서를 직접 확인하며 검증한 값이 아니라, 이번 세션에서는
 * 실제 API 키가 없어 문서 조사만으로 추정해둔 값이다. 정확한 cat3 코드값과 현재 활성 버전
 * (KorService1 vs KorService2)을 확인한 뒤 교체해서 써야 한다.
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

    // TODO(검증 필요): 서비스분류코드조회(categoryCode2)로 실제 코드값을 확인한 뒤 교체할 것.
    // 지금은 "전통시장/골목/노포" 느낌에 해당할 것으로 추정만 해둔 값이라 그대로 쓰면 안 됨.
    private static final Set<String> CAT3_WHITELIST = Set.of(
            "A04010100", // 쇼핑 > 5일장 (추정)
            "A04010200", // 쇼핑 > 상설시장 (추정)
            "A05020100"  // 음식 > 한식 (추정 — 카페/노포 소분류는 별도 확인 필요)
    );

    // 이미 다 아는 대형 랜드마크는 오히려 제외 — 제목에 이 키워드가 포함되면 후보에서 뺀다.
    private static final List<String> LANDMARK_BLACKLIST = List.of(
            "해운대해수욕장", "광안리해수욕장", "광안대교", "감천문화마을", "태종대", "자갈치시장", "국제시장"
    );

    // COCO가 다루는 법정동 → 그 동이 속한 부산 시군구 코드.
    // (지역코드/시군구코드는 지역코드조회(areaCode2) 기준. 부산 areaCode=6, 중구=1, 동구=3)
    private static final int BUSAN_AREA_CODE = 6;
    private static final Map<String, Integer> TARGET_DONG_TO_SIGUNGU = Map.of(
            "남포동", 1,
            "영주동", 1,
            "초량동", 3
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
