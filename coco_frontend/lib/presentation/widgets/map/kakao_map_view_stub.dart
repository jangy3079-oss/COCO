// 웹이 아닌 플랫폼(Android/iOS)용 대체 구현.
// COCO는 웹앱(Flutter Web)으로만 제출하지만, 개발 중 `flutter run`으로 안드로이드에서
// 다른 화면을 빠르게 확인할 때 dart:html import 때문에 빌드가 깨지지 않도록 최소 스텁만 둔다.
import 'package:flutter/material.dart';

class KakaoMapMarker {
  final String id;
  final double lat;
  final double lng;
  final String? name;
  final String? subtitle; // 핀 탭 시 뜨는 말풍선의 보조 정보(카테고리 등)
  final bool isLocalPick;
  final bool trending;
  const KakaoMapMarker({
    required this.id,
    required this.lat,
    required this.lng,
    this.name,
    this.subtitle,
    this.isLocalPick = false,
    this.trending = false,
  });
}

class KakaoMapView extends StatelessWidget {
  final double centerLat;
  final double centerLng;
  final int level;
  final List<KakaoMapMarker> markers;
  final ValueChanged<String>? onMarkerTap;
  final double? myLocationLat;
  final double? myLocationLng;
  final void Function(double lat, double lng)? onMapTap;
  final void Function(double swLat, double swLng, double neLat, double neLng)? onBoundsChanged;

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E2D8),
      alignment: Alignment.center,
      child: const Text('카카오맵은 웹 빌드에서만 표시됩니다'),
    );
  }
}
