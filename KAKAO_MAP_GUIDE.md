# 카카오맵 API 설정 가이드 (COCO 프론트엔드)

작성일: 2026-08-28
수정일: 2026-08-31 — 제출 방식이 웹앱(Flutter Web)으로 확정되면서 지도 구현 방식을 WebView → JS interop 직접 구현으로 변경

## 왜 WebView가 아니라 JS interop인가

원래는 카카오맵 JS SDK를 `webview_flutter`로 감싸서 띄우는 방식으로 계획했었다(네이티브 지도 플러그인이 끌어오는 `jni` 패키지가 Gradle/Kotlin 툴체인과 충돌했던 전례 때문). 하지만 공모전 제출을 **웹앱(Flutter Web)** 으로 확정하면서 이 계획이 무효가 됐다 — `webview_flutter`는 애초에 Flutter Web 플랫폼 자체를 지원하지 않는다.

그래서 지금은 **카카오맵 JS SDK를 Flutter Web 페이지의 DOM에 직접 심는 방식**을 쓴다. `dart:ui_web.platformViewRegistry`로 빈 `<div>`를 Flutter 위젯 트리에 등록하고, `dart:js_util`로 그 안에 `kakao.maps.Map`을 생성한다. WebView를 한 겹 씌우는 것보다 오히려 더 단순하고, 웹 타겟에서 확실히 동작한다.

## 0. 사전 준비 — web/ 폴더 먼저 생성해야 함

현재 프로젝트는 `android/`만 있고 **`web/` 폴더가 아직 없다**(처음에 안드로이드만 타겟으로 `flutter create`한 상태). 아래 명령을 로컬에서 한 번 실행해야 한다.

```bash
cd coco_frontend
flutter create --platforms=web .
```

기존 코드는 건드리지 않고 `web/` 폴더(기본 `index.html`, `manifest.json`, 아이콘 등)만 새로 생성된다.

## 1. Kakao Developers 앱 생성

1. [developers.kakao.com](https://developers.kakao.com) 로그인 → 내 애플리케이션 → 애플리케이션 추가하기
2. 앱 이름 `COCO`로 생성

## 2. JavaScript 키 확인

앱 생성 후 **[내 애플리케이션] → [앱 키]**로 이동하면 4종류 키가 자동 발급된다. 이 중 **JavaScript 키**를 쓴다 (네이티브 앱 키 아님 — 브라우저에서 동작하는 JS SDK이기 때문).

## 3. Web 플랫폼 도메인 등록 (중요 — 이거 안 하면 지도가 안 뜬다)

**[내 애플리케이션] → [플랫폼] → [Web 플랫폼 등록]**으로 이동해서 사이트 도메인을 등록한다. WebView 때와 달리 이제는 **실제로 그 페이지가 서비스되는 도메인**을 등록해야 한다.

- 로컬 개발 중 (`flutter run -d chrome`): `http://localhost:PORT` — 포트가 매번 랜덤이면 매번 등록해야 해서 번거로우니, 포트를 고정해서 실행하는 걸 추천한다.
  ```bash
  flutter run -d chrome --web-port=5173
  ```
  그리고 `http://localhost:5173`을 등록.
- 배포 후: 실제 배포 도메인(예: `https://coco-busan.vercel.app` 등, 배포처 정하면 그 도메인으로 등록)

## 4. web/index.html에 JS 브릿지 추가

`flutter create --platforms=web .`으로 생성된 `web/index.html`을 열어서, `</body>` 태그 직전에 아래 스크립트를 추가한다. Dart 쪽(`kakao_map_view_web.dart`)이 `dart:js_util`로 호출하는 함수들이다.

```html
<script>
  // COCO 카카오맵 JS interop 브릿지. Dart(kakao_map_view_web.dart)에서 직접 호출한다.
  window.__cocoKakaoMaps = {}; // divId -> kakao.maps.Map 인스턴스
  window.__cocoKakaoMarkers = {}; // divId -> kakao.maps.Marker[] 배열
  window.__cocoKakaoLoadPromise = null;

  window.cocoLoadKakaoSdk = function (appKey) {
    if (window.__cocoKakaoLoadPromise) return window.__cocoKakaoLoadPromise;
    window.__cocoKakaoLoadPromise = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=' + appKey + '&autoload=false';
      script.onload = function () {
        kakao.maps.load(function () { resolve(); });
      };
      script.onerror = function () { reject(new Error('카카오맵 SDK 로드 실패')); };
      document.head.appendChild(script);
    });
    return window.__cocoKakaoLoadPromise;
  };

  window.cocoInitKakaoMap = function (divId, lat, lng, level) {
    var container = document.getElementById(divId);
    var map = new kakao.maps.Map(container, {
      center: new kakao.maps.LatLng(lat, lng),
      level: level,
    });
    window.__cocoKakaoMaps[divId] = map;
    window.__cocoKakaoMarkers[divId] = [];
  };

  window.cocoSetKakaoMarkers = function (divId, markersJson, onMarkerClick) {
    var map = window.__cocoKakaoMaps[divId];
    if (!map) return;
    (window.__cocoKakaoMarkers[divId] || []).forEach(function (m) { m.setMap(null); });
    var markers = JSON.parse(markersJson);
    window.__cocoKakaoMarkers[divId] = markers.map(function (m) {
      var marker = new kakao.maps.Marker({
        position: new kakao.maps.LatLng(m.lat, m.lng),
        map: map,
      });
      kakao.maps.event.addListener(marker, 'click', function () { onMarkerClick(m.id); });
      return marker;
    });
  };

  window.cocoSetKakaoCenter = function (divId, lat, lng) {
    var map = window.__cocoKakaoMaps[divId];
    if (map) map.setCenter(new kakao.maps.LatLng(lat, lng));
  };
</script>
```

카카오맵 JS SDK `<script>` 태그는 여기서 넣지 않는다 — `cocoLoadKakaoSdk`가 `.env`의 키로 런타임에 동적으로 로드한다(SDK를 `index.html`에 하드코딩하면 키가 소스에 박혀버리는데, `.env` 하나로 관리하는 나머지 프로젝트 규칙과 어긋나서 이렇게 뺐다).

## 5. .env 설정

`coco_frontend/.env.example`을 복사해서 `.env`를 만들고 2번에서 확인한 JavaScript 키를 채운다 — 이 부분은 이미 완료된 상태다(`TOUR_API_KEY`처럼 `KAKAO_MAP_JS_KEY`도 이미 넣어놨다고 확인함).

```
KAKAO_MAP_JS_KEY=여기에_JavaScript_키
```

## 6. 완성된 코드

`web/` 폴더 생성 + 4번의 `index.html` 브릿지 스크립트 추가만 하면, 나머지 Dart 코드는 이미 다 붙어 있다.

- `lib/presentation/widgets/map/kakao_map_view.dart` — 플랫폼별 구현을 가르는 배럴 파일 (웹이면 실제 지도, 아니면 스텁)
- `lib/presentation/widgets/map/kakao_map_view_web.dart` — 실제 구현 (`dart:html` + `dart:js_util`로 위 브릿지 함수 호출)
- `lib/presentation/widgets/map/kakao_map_view_stub.dart` — 웹이 아닌 빌드(Android 등)용 대체 화면
- `lib/presentation/screens/map/map_screen.dart` — `MockMapBackground` 대신 `KakaoMapView` 사용하도록 교체 완료
- `lib/presentation/screens/map/map_mock_data.dart` — `MockSpot`에 실제 위경도(`lat`/`lng`) 필드 추가 (부산 중구·영도구 실좌표)

이 지도 위젯을 쓰지 않는 다른 화면들(`my_map_screen.dart`, `route_builder_screen.dart` 등)은 지금은 그대로 목업 캔버스(`MockMapBackground`, `left`/`top`)를 쓴다 — 이번 작업 범위가 아니라서 손대지 않았다. 필요하면 같은 패턴으로 나중에 바꾸면 된다.

## 7. 확인 방법

```bash
cd coco_frontend
flutter run -d chrome --web-port=5173
```

지도 탭으로 이동했을 때 실제 카카오맵이 뜨고, 5개 목업 스팟 마커가 남포동 일대에 찍혀 있으면 성공. 마커를 누르면 스팟 상세 화면으로 이동해야 한다.

## 보안 참고

JavaScript 키는 브라우저에서 항상 노출되는 공개 키라 `.env`에 넣어도 "비밀키"는 아니다(Supabase DB 비밀번호와는 성격이 다름). 다만 도메인 등록으로 사용처가 제한되므로, 등록 안 한 도메인에서는 이 키로 지도를 못 띄운다.

## 참고 자료
- [Kakao 지도 Web API 가이드](https://apis.map.kakao.com/web/guide/)
- [flutter_dotenv](https://pub.dev/packages/flutter_dotenv)
