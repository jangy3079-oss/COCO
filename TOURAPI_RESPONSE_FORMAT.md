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

## 참고 자료

- [TourAPI 사용하기 - 한국관광공사국문 관광정보](https://velog.io/@seongmin0302/api)
