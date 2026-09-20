// 코스(골목지도) — coco_backend RouteResponse/RouteSpotResponse 매핑.
// 클래스명은 RouteMap/RouteMapSpot으로 뒀다 — "Route"는 flutter/material.dart가
// 이미 내보내는 이름이라 그대로 쓰면 충돌한다(백엔드 엔티티명도 RouteMap이라 자연스럽게 맞춤).
import '../../core/utils/backend_datetime.dart';

class RouteMapSpot {
  final int spotId;
  final String title;
  final double lat;
  final double lng;
  final String? imageUrl;
  final int order;

  const RouteMapSpot({
    required this.spotId,
    required this.title,
    required this.lat,
    required this.lng,
    this.imageUrl,
    required this.order,
  });

  factory RouteMapSpot.fromJson(Map<String, dynamic> json) => RouteMapSpot(
        spotId: json['spotId'] as int,
        title: json['title'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String?,
        order: json['order'] as int? ?? 0,
      );
}

class RouteMap {
  final int id;
  final String userNickname;
  final String name;
  final String visibility; // PUBLIC | PRIVATE
  final bool isDraft;
  final List<RouteMapSpot> spots;
  final int likeCount;
  final int saveCount;
  final int shareCount;
  final bool liked;
  final bool saved;
  final DateTime createdAt;

  const RouteMap({
    required this.id,
    required this.userNickname,
    required this.name,
    required this.visibility,
    required this.isDraft,
    required this.spots,
    required this.likeCount,
    required this.saveCount,
    required this.shareCount,
    required this.liked,
    required this.saved,
    required this.createdAt,
  });

  factory RouteMap.fromJson(Map<String, dynamic> json) => RouteMap(
        id: json['id'] as int,
        userNickname: json['userNickname'] as String? ?? '',
        name: json['name'] as String? ?? '',
        visibility: json['visibility'] as String? ?? 'PRIVATE',
        isDraft: json['isDraft'] as bool? ?? false,
        spots: (json['spots'] as List? ?? [])
            .map((e) => RouteMapSpot.fromJson(e as Map<String, dynamic>))
            .toList(),
        likeCount: json['likeCount'] as int? ?? 0,
        saveCount: json['saveCount'] as int? ?? 0,
        shareCount: json['shareCount'] as int? ?? 0,
        liked: json['liked'] as bool? ?? false,
        saved: json['saved'] as bool? ?? false,
        createdAt: parseBackendDateTime(json['createdAt'] as String),
      );
}
