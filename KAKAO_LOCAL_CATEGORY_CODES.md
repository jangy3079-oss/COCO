# 카카오 로컬 API 장소 분류 코드 정리

`TOURAPI_RESPONSE_FORMAT.md`가 TourAPI 쪽 응답 포맷/분류 코드를 다뤘다면, 이 문서는 `KakaoLocalService`(`coco_backend`)가 쓰는 카카오 로컬 API의 장소 분류 정보를 정리한다. TourAPI(cat1/cat2/cat3 고정 코드 체계)와 구조가 근본적으로 달라서, 이 차이가 실제로 COCO의 카테고리 매핑(특히 "공원" 미분류) 버그의 원인이 된다.

## 두 가지 분류 정보가 따로 있다

카카오 로컬 API는 검색 방식에 따라 분류 정보가 다르게 온다.

| 필드 | 어디서 오나 | 형태 |
|---|---|---|
| `category_group_code` | 카테고리 검색(`/v2/local/search/category.json`)의 검색 조건이자 결과 필드 | 고정된 18개 코드 중 하나 (또는 없음) |
| `category_name` | 키워드 검색(`/v2/local/search/keyword.json`) 결과 필드 | `"대분류 > 중분류 > 소분류 > ..."` 형태의 자유 텍스트 경로 |

`KakaoLocalService`가 쓰는 키워드 검색 방식은 `category_name`만 준다 — TourAPI의 `cat3`처럼 딱 떨어지는 고정 소분류 코드가 없다는 게 핵심 차이.

## category_group_code — 고정 18개 코드

| 코드 | 의미 |
|---|---|
| MT1 | 대형마트 |
| CS2 | 편의점 |
| PS3 | 어린이집, 유치원 |
| SC4 | 학교 |
| AC5 | 학원 |
| PK6 | 주차장 |
| OL7 | 주유소, 충전소 |
| SW8 | 지하철역 |
| BK9 | 은행 |
| CT1 | 문화시설 |
| AG2 | 중개업소 |
| PO3 | 공공기관 |
| AT4 | 관광명소 |
| AD5 | 숙박 |
| FD6 | 음식점 |
| CE7 | 카페 |
| HP8 | 병원 |
| PM9 | 약국 |

`KakaoLocalService.fetchCandidates()`가 지금 도는 AT4(관광명소)/FD6(음식점)/CE7(카페)/CT1(문화시설) 루프가 바로 이 코드들이다.

**여기 "공원" 전용 코드가 없다.** 동네 공원은 관광명소(AT4)로도 잘 안 잡히고, 그렇다고 별도 그룹 코드도 없어서, 카테고리 검색만으로는 공원을 안정적으로 걸러낼 방법이 없다.

## category_name — 자유 텍스트 경로

키워드 검색(`"{동} 공원"` 같은) 결과에는 대신 이런 필드가 온다.

```json
{
  "id": "27305835",
  "place_name": "삼일공원",
  "category_name": "여행 > 관광,명소 > 공원 > 도시공원",
  "category_group_code": "",
  "category_group_name": "",
  "x": "129.0303077",
  "y": "35.1023459",
  "address_name": "부산 동구 초량동 1-1"
}
```

공원은 `category_group_code`가 아예 빈 문자열로 오고, `category_name` 안에 "공원"이라는 글자가 들어있는 것으로만 구분 가능하다. 즉 지금 프로젝트가 "{동} 공원" 키워드로 별도 검색하는 방식(코드 필터가 아니라 검색어 자체에 의존)이 사실상 유일하게 안정적인 방법이고, 다른 루프(AT4/FD6/CE7/CT1)가 먼저 돌면서 같은 장소를 다른 카테고리로 먼저 dedupe해버리면 공원 검색 결과가 무시되는 게 지금 있는 버그의 원인이다.

## x/y 좌표 필드 — TourAPI와 순서가 반대

- 카카오: `x` = 경도, `y` = 위도
- TourAPI: `mapx` = 경도, `mapy` = 위도 (이름은 다르지만 순서는 같음)

이름만 보면 헷갈리기 쉬운데, 실제로는 둘 다 "x=경도, y=위도" 순서라 값 자체는 동일한 규칙이다. `KakaoLocalService`에서 이 필드를 파싱할 때 실수로 뒤집지 않았는지 확인해두면 좋다.

## COCO 카테고리 매핑 시 참고

| COCO 카테고리 | TourAPI 기준 | 카카오 로컬 기준 |
|---|---|---|
| 노포/음식점 | `contenttypeid=39` + cat3 | `category_group_code=FD6` |
| 카페 | cat1=A05 계열 cat3 | `category_group_code=CE7` |
| 골목(문화/관광) | `contenttypeid=12/14` + cat3 | `category_group_code=AT4`/`CT1` |
| 공원 | `cat3=A02020700` (고정 코드로 명확) | 코드 없음 — `category_name`에 "공원" 포함 여부로만 판별 |

TourAPI는 공원을 고정 코드(`A02020700`)로 깔끔하게 잡을 수 있는 반면, 카카오는 코드가 없어서 텍스트 매칭에 의존할 수밖에 없다는 게 두 API의 근본적인 차이다.

## 참고 자료

- [카카오 로컬 API - 카테고리로 장소 검색하기](https://developers.kakao.com/docs/latest/ko/local/dev-guide#search-by-category)
- [카카오 로컬 API - 키워드로 장소 검색하기](https://developers.kakao.com/docs/latest/ko/local/dev-guide#search-by-keyword)
