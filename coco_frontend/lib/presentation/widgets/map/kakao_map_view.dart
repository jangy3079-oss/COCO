// 카카오맵 위젯의 플랫폼별 구현을 갈라주는 배럴 파일.
// 웹 빌드에서는 kakao_map_view_web.dart(dart:html 기반 JS interop)를,
// 웹이 아닌 빌드(Android/iOS 등)에서는 kakao_map_view_stub.dart(안내 문구만 표시)를 쓴다.
// COCO는 공모전 제출을 웹앱(Flutter Web)으로 확정했지만, 개발 중 `flutter run`으로
// 안드로이드에서 화면을 확인할 때 dart:html import 때문에 빌드가 깨지지 않도록
// 조건부 export로 분리해둔다.
export 'kakao_map_view_stub.dart' if (dart.library.html) 'kakao_map_view_web.dart';
