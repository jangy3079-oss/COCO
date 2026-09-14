# TourAPI 응답 포맷 정리

`API_REFERENCE.md`에서 COCO에 쓰기로 한 한국관광공사 TourAPI 오퍼레이션들의 실제 JSON 응답 형태를 정리한다. `coco_backend`의 `TourApiService` 구현 시 참고용.

## 요청 시 주의사항

- 응답 기본 포맷은 XML이다. JSON을 받으려면 요청 파라미터에 `_type=json`을 반드시 추가한다.
- `MobileOS`, `MobileApp`은 서비스 식별용 필수 파라미터 — 아무 값이나 넣어도 되지만 누락하면 에러난다.
- `serviceKey`는 공공데이터포털에서 발급받은 인증키.

## 공통 응답 구조

모든 오퍼레이션이 동일한 봉투(envelope) 구조를 쓴다.

```json
{
  "response": {
    "header": {
      "resultCode": "0000",
      "resultMsg": "OK"
    },
    "body": {
      "items": {
        "item": [ /* 결과 배열 */ ]
      },
      "numOfRows": 10,
      "pageNo": 1,
      "totalCount": 790
    }
  }
}
```

`resultCode`가 `"0000"`이면 정상, 그 외 값이면 에러(파라미터 누락, 인증키 오류 등)이므로 매 호출마다 확인해야 한다.

## 실제 조회 흐름

상세 정보는 한 번의 호출로 안 오고, 여러 오퍼레이션을 조합해야 한다.

1. 사용자가 검색어 입력 또는 지도에서 영역 조회
2. `searchKeyword`(키워드) 또는 `areaBasedList`/`locationBasedList`(지역/좌표)로 목록 조회 → 각 항목의 `contentid`, `contenttypeid` 확보
3. 그 `contentid`로 아래 3개를 각각 별도 호출해서 하나로 합침
   - `detailCommon` → 이름/주소/개요/좌표/대표사진
   - `detailIntro` → 운영시간/요금 등 (콘텐츠 타입별로 필드 다름)
   - `detailImage` → 추가 사진 목록

즉 스팟 상세화면 하나를 채우려면 API를 최소 3~4번 호출해야 한다. `TourApiService`에서 이 호출들을 조합해 하나의 DTO로 묶어주는 메서드가 필요하다.

## 오퍼레이션별 응답 예시

### 1. 키워드검색조회 (searchKeyword) / 지역·위치기반조회 공통 필드

지도·검색 목록에 쓰는 오퍼레이션들(`searchKeyword`, `areaBasedList`, `locationBasedList`)은 필드 구성이 거의 동일하다.

```json
{
  "contentid": "1433504",
  "contenttypeid": "38",
  "title": "가경 터미널시장",
  "addr1": "충청북도 청주시 흥덕구 가경동",
  "addr2": "1438",
  "mapx": "127.4341171334",
  "mapy": "36.6286485111",
  "firstimage": "",
  "firstimage2": "",
  "cat1": "A04",
  "cat2": "A0401",
  "cat3": "A04010200",
  "areacode": "33",
  "sigungucode": "10"
}
```

### 2. 공통정보조회 (detailCommon) — 스팟 상세 기본정보

```json
{
  "contentid": "2674675",
  "title": "수원화성의 비밀",
  "addr1": "경기도 수원시 팔달구 행궁로 11",
  "tel": "031-290-3563",
  "firstimage": "http://tong.visitkorea.or.kr/cms/resource/74/2674674_image2_1.jpg",
  "firstimage2": "http://tong.visitkorea.or.kr/cms/resource/74/2674674_image2_1.jpg",
  "mapx": "127.0152812635",
  "mapy": "37.2810769133",
  "overview": "스마트폰으로 수원화성 일원에서 진행하는 방탈출 게임 형식의 콘텐츠로 증강현실 등 다양한 정보통신기술과 역사를 직접 체험할 수 있는 관광 콘텐츠"
}
```

### 3. 소개정보조회 (detailIntro) — 운영시간/요금 등

콘텐츠 타입(`contenttypeid`)에 따라 필드셋이 아예 다르다. 예: 행사/축제 타입 응답.

```json
{
  "contentid": "2674675",
  "eventstartdate": "20220101",
  "eventenddate": "20241231",
  "playtime": "연중(밤 10시 이후 제한)",
  "eventplace": "수원화성 일원",
  "usetimefestival": "7,500원"
}
```

관광지 타입은 `usetime`/`restdate`/`parking`, 숙박 타입은 `checkintime`/`checkouttime` 등으로 필드가 바뀐다.

### 4. 이미지정보조회 (detailImage) — 갤러리용 추가 사진

`item`이 사진 개수만큼 배열로 온다.

```json
{
  "contentid": "2674675",
  "originimgurl": "http://tong.visitkorea.or.kr/cms/resource/05/2674805_image2_1.jpg",
  "smallimageurl": "http://tong.visitkorea.or.kr/cms/resource/05/2674805_image2_1.jpg",
  "imgname": "수원화성의 비밀 2020(2)"
}
```

## 분류 코드 정리

목록 조회(`searchKeyword`/`areaBasedList`/`locationBasedList`) 응답에 같이 오는 `contenttypeid`, `cat1`/`cat2`/`cat3`, `areacode`/`sigungucode`가 실제로 뭘 뜻하는지 정리한다. `TourApiService.mapToCocoCategory`가 COCO 카테고리(노포/골목/공원/카페)로 매핑할 때 이 코드들을 보고 판단한다.

### contenttypeid — 콘텐츠 대분류

| 코드 | 의미 |
|---|---|
| 12 | 관광지 |
| 14 | 문화시설 |
| 15 | 축제/공연/행사 |
| 25 | 여행코스 |
| 28 | 레포츠 |
| 32 | 숙박 |
| 38 | 쇼핑 |
| 39 | 음식점 |

### cat1 / cat2 / cat3 — 대/중/소분류 (3단계)

`cat1`(대분류) → `cat2`(중분류) → `cat3`(소분류) 순으로 갈수록 세분화된다. `cat3`가 실제 카테고리 매핑에 쓰는 값.

**cat1 (대분류) 전체**

| 코드 | 의미 |
|---|---|
| A01 | 자연 |
| A02 | 인문(문화/예술/역사) |
| A03 | 레포츠 |
| A04 | 쇼핑 |
| A05 | 음식점 |
| B02 | 숙박 |
| C01 | 추천코스 |

**COCO 카테고리와 관련된 cat2/cat3 예시** (전체 목록은 공공데이터포털 TourAPI 문서 참고 — 아래는 발췌)

| cat1 | cat2 | cat3 | 의미 |
|---|---|---|---|
| A02(인문) | A0202(휴양관광지) | A02020100 | 관광농원 |
| A02(인문) | A0202(휴양관광지) | A02020600 | 자연생태관광지 |
| A02(인문) | A0202(휴양관광지) | **A02020700** | **공원** ← COCO 화이트리스트에 있는 값 |
| A02(인문) | A0202(휴양관광지) | A02020800 | 유원지 |
| A02(인문) | A0202(휴양관광지) | A02020900 | 테마공원 |
| A02(인문) | A0201(역사관광지) | A02010100~ | 고궁/성/문화유적 등 |
| A02(인문) | A0206(문화시설) | A02060100~ | 박물관/미술관/공연장 등 |
| A05(음식점) | A0502(음식점) | A05020100~ | 한식/일식/중식/카페 등 세부 업종 (COCO "노포"가 여기서 갈림) |

### areacode / sigungucode — 지역 코드

시/도 단위 `areacode`, 그 아래 시/군/구 단위 `sigungucode`. COCO는 부산이 주 대상이라 `areaCode=6`으로 걸어두면 다른 지역 데이터 유입을 막을 수 있다.

| 코드 | 지역 |
|---|---|
| 1 | 서울 |
| 2 | 인천 |
| 3 | 대전 |
| 4 | 대구 |
| **6** | **부산** |
| 5 | 광주 |
| 7 | 울산 |
| 8 | 세종 |
| 31 | 경기 |
| 32 | 강원 |
| 33 | 충북 |
| 34 | 충남 |
| 35 | 경북 |
| 36 | 경남 |
| 37 | 전북 |
| 38 | 전남 |
| 39 | 제주 |

카카오 로컬 API 쪽 분류 체계(고정 코드가 없고 텍스트 경로만 있음)와의 차이는 `KAKAO_LOCAL_CATEGORY_CODES.md`에 정리해뒀다 — 특히 "공원"은 TourAPI는 `cat3=A02020700`으로 명확히 잡히는데 카카오는 그런 코드가 아예 없다는 게 두 소스를 같이 쓸 때 항상 헷갈리는 지점이다.

## 참고 자료

- [TourAPI 사용하기 - 한국관광공사국문 관광정보](https://velog.io/@seongmin0302/api)
