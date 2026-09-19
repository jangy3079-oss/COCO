// 카카오맵 실제 구현 (Flutter Web 전용).
//
// WebView를 쓰지 않고, 카카오맵 JS SDK를 페이지 DOM에 직접 붙인다.
// - HtmlElementView + dart:ui_web.platformViewRegistry로 빈 <div>를 Flutter 위젯 트리에 심고
// - web/index.html에 미리 넣어둔 JS 브릿지 함수(cocoLoadKakaoSdk 등)를 dart:js_interop으로 호출해
//   그 <div> 안에 kakao.maps.Map을 생성한다.
// (dart:html/dart:js_util는 이 SDK에서 이미 접근 불가/제거됐길래 최신 방식인
//  dart:js_interop + package:web으로 작성함 — flutter analyze로 확인 완료)
// 필요한 JS 브릿지 함수 정의는 KAKAO_MAP_GUIDE.md의 "web/index.html 설정" 항목 참고.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web/web.dart' as web;

class KakaoMapMarker {
  final String id;
  final double lat;
  final double lng;
  final String? name; // 마커 위에 띄울 이름 태그 (null이면 태그 없이 핀만)
  final String? subtitle; // 핀 탭 시 뜨는 말풍선의 보조 정보(카테고리 등)
  final bool isLocalPick; // true면 핀 색을 강조색(주황)으로
  final bool trending; // true면 핀을 더 크게
  // 코스("지도에서 보기")처럼 방문 순서를 핀 안에 숫자로 보여줘야 할 때만 값이 있다.
  // 값이 있으면 로컬픽(2단계)과 동일한 크기/색으로 통일되고, 그 안에 이 번호가 찍힌다.
  final int? order;
  const KakaoMapMarker({
    required this.id,
    required this.lat,
    required this.lng,
    this.name,
    this.subtitle,
    this.isLocalPick = false,
    this.trending = false,
    this.order,
  });
}

// web/index.html에 정의해둔 JS 브릿지 함수들. top-level external 선언은
// 기본적으로 전역(window) 객체의 동명 프로퍼티에 바인딩된다.
@JS('cocoLoadKakaoSdk')
external JSPromise<JSAny?> _cocoLoadKakaoSdk(JSString appKey);

@JS('cocoInitKakaoMap')
external void _cocoInitKakaoMap(JSString divId, JSNumber lat, JSNumber lng, JSNumber level);

@JS('cocoSetKakaoMarkers')
external void _cocoSetKakaoMarkers(JSString divId, JSString markersJson, JSFunction onMarkerClick);

@JS('cocoSetKakaoCenter')
external void _cocoSetKakaoCenter(JSString divId, JSNumber lat, JSNumber lng);

@JS('cocoSetMyLocation')
external void _cocoSetMyLocation(JSString divId, JSNumber lat, JSNumber lng);

@JS('cocoStopHeadingWatch')
external void _cocoStopHeadingWatch(JSString divId);

@JS('cocoSetMapClickHandler')
external void _cocoSetMapClickHandler(JSString divId, JSFunction onClick);

@JS('cocoSetBoundsChangedHandler')
external void _cocoSetBoundsChangedHandler(JSString divId, JSFunction onBoundsChanged);

@JS('cocoFocusSpot')
external void _cocoFocusSpot(JSString divId, JSString markerJson);

@JS('cocoFitKakaoBounds')
external void _cocoFitKakaoBounds(JSString divId, JSString pointsJson);

@JS('cocoSetClusteringEnabled')
external void _cocoSetClusteringEnabled(JSString divId, JSBoolean enabled);

// 검색 결과 탭처럼 "특정 스팟으로 살짝 확대해서 이동 + 도착하면 핀 탭과 동일한
// 말풍선(뿅 애니메이션)을 띄운다"를 요청할 때 쓰는 값. centerLat/centerLng(단순
// 재중심, 콜아웃 없음)와는 별개 경로 — 매번 새 인스턴스를 만들어서 넘기면 동일
// 좌표라도(같은 스팟 재검색) 매번 새로 포커스가 걸린다(기본 == 이 identity 비교라서).
class MapFocusTarget {
  final String id;
  final double lat;
  final double lng;
  final String? name;
  final String? subtitle;
  const MapFocusTarget({required this.id, required this.lat, required this.lng, this.name, this.subtitle});
}

// 코스의 "지도에서 보기"처럼, 특정 스팟들이 전부 화면에 들어오도록 카메라를
// 맞출 때 쓰는 값. focusTarget(스팟 하나 확대+말풍선)과 달리 콜아웃 없이
// 여러 좌표를 감싸는 bounds로 중심/줌을 한 번에 맞춘다. focusTarget과 동일하게
// 매번 새 인스턴스로 넘겨야(identity 비교) 같은 코스를 다시 봐도 반영된다.
class MapBoundsTarget {
  final List<(double lat, double lng)> points;
  const MapBoundsTarget({required this.points});
}

class KakaoMapView extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final int level; // 카카오맵 확대 레벨(작을수록 확대). 기본값은 동네 골목이 보이는 정도.
  final List<KakaoMapMarker> markers;
  final ValueChanged<String>? onMarkerTap;
  final double? myLocationLat; // GPS로 실제 위치를 구했을 때만 값이 있음 — 지도 위 파란 점 표시용
  final double? myLocationLng;
  final void Function(double lat, double lng)? onMapTap; // 지도를 직접 눌러 좌표를 찍는 용도
  // 지도 화면(뷰포트)이 바뀔 때(드래그/줌 종료)마다 호출 — 화면에 보이는 범위만큼만
  // 서버에 다시 요청해서 핀 밀집을 막고 싶을 때 사용(뷰포트 쿼리).
  final void Function(double swLat, double swLng, double neLat, double neLng)? onBoundsChanged;
  final MapFocusTarget? focusTarget;
  final MapBoundsTarget? boundsTarget;
  // false면 핀끼리 겹쳐도 클러스터 버블로 뭉치지 않고 각자 그대로 그린다.
  // 코스 순서 핀(order)처럼 개수가 적고 번호가 꼭 다 보여야 하는 미리보기용 지도에서 쓴다.
  final bool clusteringEnabled;

  const KakaoMapView({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.level = 4,
    this.markers = const [],
    this.onMarkerTap,
    this.myLocationLat,
    this.myLocationLng,
    this.onMapTap,
    this.onBoundsChanged,
    this.focusTarget,
    this.boundsTarget,
    this.clusteringEnabled = true,
  });

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

// SDK 로딩은 앱 전체에서 한 번만 하면 되므로, 지도 위젯이 여러 개 떠도 재사용하도록 전역 캐싱.
Future<void>? _kakaoSdkLoadFuture;

Future<void> _ensureKakaoSdkLoaded() {
  final cached = _kakaoSdkLoadFuture;
  if (cached != null) return cached;

  final appKey = dotenv.maybeGet('KAKAO_MAP_JS_KEY') ?? '';
  if (appKey.isEmpty) {
    final failed = Future<void>.error(
      StateError('KAKAO_MAP_JS_KEY가 .env에 설정되어 있지 않습니다. coco_frontend/.env.example 참고.'),
    );
    _kakaoSdkLoadFuture = failed;
    return failed;
  }

  final future = _cocoLoadKakaoSdk(appKey.toJS).toDart;
  _kakaoSdkLoadFuture = future;
  return future;
}

class _KakaoMapViewState extends State<KakaoMapView> {
  late final String _divId;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _divId = 'coco-kakao-map-${identityHashCode(this)}';

    ui_web.platformViewRegistry.registerViewFactory(_divId, (int viewId) {
      final div = web.HTMLDivElement()..id = _divId;
      div.style.width = '100%';
      div.style.height = '100%';
      return div;
    });

    _init();
  }

  Future<void> _init() async {
    try {
      await _ensureKakaoSdkLoaded();
      // HtmlElementView가 실제로 div를 DOM에 붙일 때까지 한 프레임 정도 여유를 준다.
      await Future.delayed(const Duration(milliseconds: 50));
      _cocoInitKakaoMap(
        _divId.toJS,
        widget.centerLat.toJS,
        widget.centerLng.toJS,
        widget.level.toJS,
      );
      if (!mounted) return;
      setState(() => _mapReady = true);
      _updateMarkers();
      _updateMyLocation();
      final onMapTap = widget.onMapTap;
      if (onMapTap != null) {
        void onClick(JSNumber lat, JSNumber lng) => onMapTap(lat.toDartDouble, lng.toDartDouble);
        _cocoSetMapClickHandler(_divId.toJS, onClick.toJS);
      }
      final onBoundsChanged = widget.onBoundsChanged;
      if (onBoundsChanged != null) {
        void onBounds(JSNumber swLat, JSNumber swLng, JSNumber neLat, JSNumber neLng) =>
            onBoundsChanged(swLat.toDartDouble, swLng.toDartDouble, neLat.toDartDouble, neLng.toDartDouble);
        _cocoSetBoundsChangedHandler(_divId.toJS, onBounds.toJS);
      }
    } catch (e) {
      debugPrint('[KakaoMapView] 카카오맵 초기화 실패: $e');
    }
  }

  @override
  void didUpdateWidget(covariant KakaoMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    if (oldWidget.centerLat != widget.centerLat || oldWidget.centerLng != widget.centerLng) {
      _cocoSetKakaoCenter(_divId.toJS, widget.centerLat.toJS, widget.centerLng.toJS);
    }
    if (oldWidget.markers != widget.markers) {
      _updateMarkers();
    }
    // focusTarget은 매번 새 인스턴스로 넘어오는 일회성 요청이라 identity(!=)만으로
    // "새 요청인지"를 판단한다 — centerLat/centerLng 재중심(콜아웃 없음)과 달리
    // 확대 + panTo + 말풍선을 한번에 처리한다.
    final focusTarget = widget.focusTarget;
    if (focusTarget != null && focusTarget != oldWidget.focusTarget) {
      final json = jsonEncode({
        'id': focusTarget.id,
        'lat': focusTarget.lat,
        'lng': focusTarget.lng,
        'name': focusTarget.name,
        'subtitle': focusTarget.subtitle,
      });
      _cocoFocusSpot(_divId.toJS, json.toJS);
    }
    // boundsTarget도 focusTarget과 동일하게 매번 새 인스턴스로 오는 일회성 요청이라
    // identity(!=)로 "새 요청인지" 판단한다.
    final boundsTarget = widget.boundsTarget;
    if (boundsTarget != null && boundsTarget != oldWidget.boundsTarget) {
      final pointsJson = jsonEncode(
        boundsTarget.points.map((p) => {'lat': p.$1, 'lng': p.$2}).toList(),
      );
      _cocoFitKakaoBounds(_divId.toJS, pointsJson.toJS);
    }
    if (oldWidget.myLocationLat != widget.myLocationLat || oldWidget.myLocationLng != widget.myLocationLng) {
      _updateMyLocation();
    }
  }

  void _updateMarkers() {
    if (!_mapReady) return;
    // 마커를 새로 그릴 때마다 매번 같이 반영 — 값 자체는 거의 안 바뀌지만,
    // didUpdateWidget에서 별도로 변경 여부를 추적하지 않아도 항상 최신 상태로 맞는다.
    _cocoSetClusteringEnabled(_divId.toJS, widget.clusteringEnabled.toJS);
    final markersJson = jsonEncode(
      widget.markers
          .map((m) => {
                'id': m.id,
                'lat': m.lat,
                'lng': m.lng,
                'name': m.name,
                'subtitle': m.subtitle,
                'isLocalPick': m.isLocalPick,
                'trending': m.trending,
                'order': m.order,
              })
          .toList(),
    );
    void onMarkerClick(JSString id) => widget.onMarkerTap?.call(id.toDart);
    _cocoSetKakaoMarkers(_divId.toJS, markersJson.toJS, onMarkerClick.toJS);
  }

  void _updateMyLocation() {
    if (!_mapReady) return;
    final lat = widget.myLocationLat;
    final lng = widget.myLocationLng;
    if (lat == null || lng == null) return;
    _cocoSetMyLocation(_divId.toJS, lat.toJS, lng.toJS);
  }

  @override
  void dispose() {
    // 나침반(deviceorientation) 리스너는 divId별로 window에 전역 등록되므로,
    // 위젯이 사라질 때 반드시 해제해야 다른 화면에서 leak/중복 호출이 안 생긴다.
    _cocoStopHeadingWatch(_divId.toJS);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _divId);
  }
}
