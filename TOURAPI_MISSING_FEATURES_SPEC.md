# TourAPI 활용방안 미구현 항목 — 백엔드 반영 명세서

이 문서는 공모전 슬라이드("데이터 활용" 표)에 적힌 5개 API 활용방안 중 실제 코드에
없거나 축소 구현된 항목을 실제로 맞추기 위해 **백엔드에 필요한 수정사항만** 정리한
것이다. 코드는 건드리지 않았고, 아래 내용은 구현 시 참고할 명세다.

대상:
- **③ detailIntro2** (운영시간/요금) — 미구현
- **⑤ 관광사진정보서비스** (갤러리 사진) — 미구현
- **④ TarRlteTarService1** — 필터링에만 쓰이고 "연관 관광지 추천" 기능은 없음, 확장 필요
- (부록) **② detailCommon2** — 설명 문구와 실제 소스 불일치, 코드보다는 문구 정합 문제

현재 관련 코드 위치 참고:
- `coco_backend/src/main/java/com/coco/backend/service/TourApiService.java`
- `coco_backend/src/main/java/com/coco/backend/service/SpotService.java`
- `coco_backend/src/main/java/com/coco/backend/entity/Spot.java`
- `coco_backend/src/main/java/com/coco/backend/dto/response/SpotResponse.java`
- `coco_backend/src/main/java/com/coco/backend/controller/SpotController.java`
- `coco_backend/src/main/resources/schema.sql`

---

## 1. detailIntro2 — 운영시간/요금 정보

### 1.1 왜 필요한가
슬라이드 설명("운영시간·요금 등 콘텐츠 타입별 상세 정보 제공에 활용")과 달리, 현재
`TourApiService`에는 `detailIntro2` 호출이 전혀 없고 `Spot` 엔티티에도 운영시간/요금
관련 컬럼이 없다. 스팟 상세 화면에 이 정보가 노출되지 않는다.

### 1.2 API 특성 — contentTypeId별 응답 필드가 다름
`detailIntro2`는 `contentTypeId`에 따라 반환 필드명이 달라진다. COCO가 수집 대상으로
쓰는 3개 타입(`TARGET_CONTENT_TYPE_IDS = 12, 14, 39`) 기준으로 필요한 필드만 추리면:

| COCO 카테고리 | contentTypeId | 운영시간 | 휴무일 | 주차 | 요금 | 문의처 |
|---|---|---|---|---|---|---|
| 명소/공원/골목 | 12 (관광지) | `usetime` | `restdate` | `parking` | (보통 없음, 무료가 많음) | `infocenter` |
| 문화시설 | 14 (문화시설) | `usetimeculture` | `restdateculture` | `parkingculture` | `usefee` | `infocenterculture` |
| 음식점/카페 | 39 (음식점) | `opentimefood` | `restdatefood` | `parkingfood` | (메뉴별 가격은 `firstmenu`/`treatmenu`) | `infocenterfood` |

> **검증 필요**: 위 필드명은 TourAPI 공식 문서 기준 추정값이다. 이 프로젝트 기존 코드
> 컨벤션(`TourApiService.java` 상단 TODO 주석 참고)대로, 실제 서비스키로 호출해본 뒤
> 필드명을 확정해야 한다.

### 1.3 필요한 변경사항

**(1) `TourApiService`에 메서드 추가**
```java
public IntroInfo fetchIntro(String contentId, String contentTypeId) {
    // {baseUrl}/{korServicePath}/detailIntro2
    //   ?serviceKey=...&contentId={contentId}&contentTypeId={contentTypeId}
    // contentTypeId별로 usetime/usetimeculture/opentimefood 등 필드명이 다르므로
    // contentTypeId 기준 분기해서 공통 레코드(IntroInfo)로 정규화해 반환.
    // 실패/필드 없음 시 null 필드로 채워서 반환 (fetchOverview와 동일하게 신규 스팟
    // 저장 자체를 막지 않음).
}

public record IntroInfo(
        String operatingHours,
        String restDate,
        String parkingInfo,
        String usageFee,
        String phone
) {}
```
- `contentTypeId`는 `TourApiCandidate`에 이미 없으므로, `toCandidate()`에서
  `item.path("contenttypeid").asText("")` 값을 `TourApiCandidate`에 필드로 추가해서
  `SpotService`까지 전달해야 한다 (현재는 카테고리 매핑에만 쓰고 버려짐).

**(2) `Spot` 엔티티에 컬럼 추가**
```java
@Column(name = "operating_hours", length = 200)
private String operatingHours;

@Column(name = "rest_date", length = 100)
private String restDate;

@Column(name = "parking_info", length = 200)
private String parkingInfo;

@Column(name = "usage_fee", length = 200)
private String usageFee;

@Column(length = 30)
private String phone;
```
`ddl-auto: update`라 엔티티에 추가하면 테이블에 자동 반영되지만, `schema.sql`은 초기
스키마 참고 문서이므로 위 5개 컬럼을 `CREATE TABLE spots` 블록에도 같이 추가해 문서와
실제 스키마가 어긋나지 않게 해야 한다. (참고: 현재 `schema.sql`은 이미
`description`/`is_local_pick`/`kakao_place_id` 등 엔티티에 있는 컬럼 일부가 빠져
있어 실제와 다른 상태 — 이번 기회에 같이 맞추는 걸 권장.)

**(3) `SpotService.importFromTourApi()` 수정**
```java
String description = tourApiService.fetchOverview(c.tourApiId());
var intro = tourApiService.fetchIntro(c.tourApiId(), c.contentTypeId());

Spot spot = Spot.builder()
        // ...기존 필드...
        .operatingHours(intro.operatingHours())
        .restDate(intro.restDate())
        .parkingInfo(intro.parkingInfo())
        .usageFee(intro.usageFee())
        .phone(intro.phone())
        .build();
```
카카오 로컬 소스(`importFromKakaoLocal`)는 이 필드들을 채울 방법이 없으므로 null로
유지(기존 `description` 처리와 동일한 패턴).

**(4) `SpotResponse` DTO에 필드 추가 + `SpotService.toResponse()`에서 매핑**
```java
private String operatingHours;
private String restDate;
private String parkingInfo;
private String usageFee;
private String phone;
```
프론트 `spot_detail_screen.dart`에서 이 필드들이 null이면 "운영시간 정보 없음" 같은
안내 문구로 대체하는 처리 필요(카카오 로컬 소스 스팟 대비).

### 1.4 주의사항
- `detailIntro2`는 신규 스팟마다 1회 호출이라 `fetchOverview`와 마찬가지로 dedupe
  통과한 것만 호출하도록 배치 (이미 `importFromTourApi` 루프 구조가 그렇게 되어 있어
  자연스럽게 맞음).
- `usetime` 등 값이 아주 긴 자유 텍스트로 오는 경우가 있어 컬럼 길이(200)가 부족하면
  잘릴 수 있음 — 실제 응답 샘플을 받아본 뒤 길이 조정 필요.

---

## 2. 관광사진정보서비스 — 갤러리 사진

### 2.1 왜 필요한가
슬라이드 설명("감성 로컬 스팟 사진 탐색 피드에 활용할 고품질 관광 사진 데이터 수집")과
달리 현재 백엔드/프론트 어디에도 호출 코드가 없다. `Spot.imageUrl`은 대표 이미지 1장
뿐이라, "사진 피드"를 만들려면 스팟당 여러 장의 사진을 가져와야 한다.

> **명칭 확인 필요**: "관광사진정보서비스"는 TourAPI `KorService2` 내 스팟 상세용
> 오퍼레이션 `detailImage2`(소개이미지조회, `contentId` 기준으로 `originimgurl`/
> `smallimageurl` 목록 반환)를 가리키는 것으로 추정된다. `TourApiService.java`의 기존
> 컨벤션처럼, 실제 서비스키로 호출해 오퍼레이션명과 응답 필드를 확정해야 한다.

### 2.2 필요한 변경사항

**(1) 신규 테이블 `spot_images` (1:N)**
```sql
CREATE TABLE spot_images (
    spot_image_id BIGSERIAL NOT NULL,
    spot_id       BIGINT    NOT NULL,
    image_url     TEXT      NOT NULL,
    thumbnail_url TEXT,
    sort_order    INT       NOT NULL DEFAULT 0,
    PRIMARY KEY (spot_image_id),
    CONSTRAINT fk_spotimage_spot FOREIGN KEY (spot_id) REFERENCES spots(spot_id) ON DELETE CASCADE
);

CREATE INDEX idx_spotimage_spot ON spot_images (spot_id);
```
대표 이미지(`spots.image_url`)는 그대로 두고, 갤러리용 추가 사진만 별도 테이블로
분리 — 기존 `route_map_spots`/`course_spots` 같은 1:N 패턴과 동일한 컨벤션.

**(2) 신규 엔티티 `SpotImage` + `SpotImageRepository`**
```java
@Entity
@Table(name = "spot_images")
public class SpotImage {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "spot_image_id")
    private Long id;

    @Column(name = "spot_id", nullable = false)
    private Long spotId;

    @Column(name = "image_url", columnDefinition = "TEXT", nullable = false)
    private String imageUrl;

    @Column(name = "thumbnail_url", columnDefinition = "TEXT")
    private String thumbnailUrl;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;
}
```

**(3) `TourApiService`에 메서드 추가**
```java
public List<GalleryImage> fetchGalleryImages(String contentId) {
    // {baseUrl}/{korServicePath}/detailImage2
    //   ?serviceKey=...&contentId={contentId}&imageYN=Y
    // 실패/이미지 없음 시 빈 리스트 반환 (신규 스팟 저장을 막지 않음 — fetchOverview와 동일 원칙).
}

public record GalleryImage(String originImageUrl, String thumbnailUrl) {}
```

**(4) `SpotService.importFromTourApi()`에서 저장**
```java
Spot saved = spotRepository.save(spot);

List<TourApiService.GalleryImage> images = tourApiService.fetchGalleryImages(c.tourApiId());
for (int i = 0; i < images.size(); i++) {
    var img = images.get(i);
    spotImageRepository.save(SpotImage.builder()
            .spotId(saved.getId())
            .imageUrl(img.originImageUrl())
            .thumbnailUrl(img.thumbnailUrl())
            .sortOrder(i)
            .build());
}
```

**(5) 신규 조회 엔드포인트**
```java
// SpotController
@GetMapping("/{id}/images")
public ResponseEntity<List<String>> getSpotImages(@PathVariable Long id) {
    return ResponseEntity.ok(spotService.getImageUrls(id));
}
```
스팟 상세 화면(사진 피드 섹션)에서 이 엔드포인트로 갤러리 이미지 목록을 별도 조회.
`SpotResponse`에 통째로 끼워 넣기보다 분리하는 이유: 지도 뷰포트 조회(`GET /api/spot`)
는 핀 여러 개를 한 번에 반환하는데, 여기에 스팟당 여러 장 사진까지 매번 실어 보내면
페이로드가 불필요하게 커짐 — 상세 화면 진입 시에만 필요한 정보라 분리.

### 2.3 주의사항
- 카카오 로컬 소스는 사진 갤러리 API가 없으므로 `importFromKakaoLocal()`에는 이 로직을
  추가하지 않음 — 해당 스팟은 `spot_images`가 비어 있는 채로 정상.
- `detailImage2` 호출도 신규 스팟당 1회이므로 `fetchOverview`/`fetchIntro`와 합쳐서
  "신규 스팟 상세 보강" 단계로 묶어 호출 실패 시 로깅만 하고 계속 진행하도록 유지.

---

## 3. TarRlteTarService1 확장 — 연관 관광지 추천

### 3.1 왜 필요한가
슬라이드 설명은 "스팟 상세 화면의 인근 연관 관광지 추천 **및** 이미 유명한 랜드마크를
골목 큐레이션에서 자동 제외하는 필터링 기준"이라고 되어 있는데, 현재
`TourApiService.fetchFamousContentIds()`는 뒷부분(필터링)만 구현되어 있다. 앞부분인
"상세 화면에서 연관 관광지 추천"은 컨트롤러/서비스 어디에도 없다.

### 3.2 필요한 변경사항

**(1) `TourApiService`에 추천용 메서드 추가**
```java
public List<String> fetchRelatedContentIds(double lat, double lng) {
    // {baseUrl}/{tarRlteTarPath}/locationBasedList1
    //   ?serviceKey=...&mapX={lng}&mapY={lat}&radius=2000&numOfRows=5
    // 좌표 기준으로 연관성 높은 관광지의 contentId(rlteCid 등) 목록 반환.
    // 필드명은 fetchFamousContentIds()와 마찬가지로 실제 키로 검증 전이라 폴백 로직 필요.
}
```
기존 `fetchFamousContentIds()`는 지역(시군구) 단위 `areaBasedList1`을 쓰지만, "이 스팟
근처의 연관 관광지"를 뽑으려면 좌표 기반 `locationBasedList1` 오퍼레이션이 필요하다
(TarRlteTarService1 문서 기준 — 실키로 오퍼레이션명/파라미터 검증 필요, 이 프로젝트
기존 TODO 컨벤션과 동일하게 처리).

**(2) `SpotService`에 조회 메서드 추가**
```java
public List<SpotResponse> getRelatedSpots(Long id, String locale) {
    Spot spot = spotRepository.findById(id).orElseThrow(...);
    // 카카오 로컬 소스(tour_apiid 없음)는 TarRlteTarService 대상이 아니므로 빈 리스트.
    List<String> relatedContentIds = tourApiService.fetchRelatedContentIds(spot.getLat(), spot.getLng());

    // TarRlteTarService가 돌려주는 contentId를 우리 DB의 spot_id로 재매핑.
    // (DB에 없는 관광지는 애초에 큐레이션 대상이 아니었던 곳이라 자연스럽게 걸러짐)
    List<Spot> related = relatedContentIds.stream()
            .map(spotRepository::findByTourApiid)
            .flatMap(Optional::stream)
            .filter(s -> !s.getId().equals(id))
            .limit(5)
            .toList();

    return related.stream().map(s -> toResponse(s, ..., locale)).toList();
}
```

**(3) 신규 엔드포인트**
```java
// SpotController
@GetMapping("/{id}/related")
public ResponseEntity<List<SpotResponse>> getRelatedSpots(@PathVariable Long id,
                                                            @RequestParam(defaultValue = "ko") String locale) {
    return ResponseEntity.ok(spotService.getRelatedSpots(id, locale));
}
```
스팟 상세 화면 하단 "근처 다른 스팟" 섹션에서 사용.

### 3.3 주의사항
- TarRlteTarService는 월 단위 집계 데이터라(`fetchFamousContentIds()`의
  `YearMonth.now().minusMonths(2)` 주석 참고) 최신성이 떨어질 수 있음 — 추천 결과가
  비어도 화면이 깨지지 않도록 프론트에서 "추천 정보 없음" 처리 필요.
- TarRlteTarService가 반환하는 관광지가 COCO DB에 없는 경우(큐레이션 필터에서 이미
  제외된 랜드마크 등)가 흔할 수 있으므로, 재매핑 후 결과가 5개 미만이어도 정상.
- 실패 시 빈 리스트 반환(예외로 화면 깨뜨리지 않음) — 기존 `fetchOverview`/
  `fetchFamousContentIds` 예외 처리 패턴과 동일하게.

---

## 4. (부록) detailCommon2 — 설명 문구 정합

이건 기능 추가가 아니라 슬라이드 설명과 코드의 "출처" 불일치 문제다. 현재 주소/좌표/
대표사진은 `detailCommon2`가 아니라 `areaBasedList2` 응답(`addr1`/`addr2`/`mapx`/
`mapy`/`firstimage`)에서 채워지고, `detailCommon2`는 `overview`(소개글) 하나만 쓴다.

두 가지 선택지 중 하나:
- **(A) 코드는 그대로 두고 슬라이드 설명만 수정** — "주소·좌표·대표사진은
  areaBasedList2로, 소개글만 detailCommon2로 보강"처럼 실제와 맞게 문구 정정.
  areaBasedList2 응답에 이미 그 필드들이 다 들어있어서 detailCommon2로 다시
  조회하는 건 API 호출만 늘고 실익이 없음 — **이 방향을 권장**.
- **(B) 실제로 detailCommon2에서 주소/좌표/사진을 재조회하도록 변경** — 스팟마다
  API 호출이 1회 더 늘고, areaBasedList2와 값이 달라질 경우 어느 쪽을 신뢰할지
  판단 로직이 추가로 필요해서 득보다 실이 큼.

---

## 5. 변경 파일 체크리스트

| 파일 | 변경 내용 |
|---|---|
| `TourApiService.java` | `fetchIntro()`, `fetchGalleryImages()`, `fetchRelatedContentIds()` 추가, `toCandidate()`에 contentTypeId 전달 |
| `TourApiService.TourApiCandidate` | `contentTypeId` 필드 추가 |
| `Spot.java` | `operatingHours`/`restDate`/`parkingInfo`/`usageFee`/`phone` 컬럼 추가 |
| `SpotImage.java` (신규) | 갤러리 이미지 엔티티 |
| `SpotImageRepository.java` (신규) | `findBySpotIdOrderBySortOrder` |
| `SpotService.java` | `importFromTourApi()`에 intro/이미지 저장 로직 추가, `getRelatedSpots()`/`getImageUrls()` 추가 |
| `SpotResponse.java` | `operatingHours`/`restDate`/`parkingInfo`/`usageFee`/`phone` 필드 추가 |
| `SpotController.java` | `GET /api/spot/{id}/images`, `GET /api/spot/{id}/related` 추가 |
| `schema.sql` | `spots` 테이블에 신규 컬럼 반영, `spot_images` 테이블 추가 (기존에 빠져 있던 `description`/`is_local_pick`/`kakao_place_id`도 같이 정리 권장) |

모든 신규 필드/API 호출은 기존 코드 컨벤션(`fetchOverview`처럼 실패 시 null/빈 리스트
반환, 신규 스팟 저장 자체를 막지 않음)을 그대로 따른다.
