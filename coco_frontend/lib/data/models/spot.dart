// 로컬 스팟 모델 — coco_backend GET /api/spot 응답과 1:1 매칭.
// (기존엔 title/titleEn/titleJa 다국어 필드였지만, 백엔드 Spot 엔티티가 단일 title
//  컬럼으로 단순화되면서 현재 API는 title 하나만 내려줌 — 다국어 지원은 추후 백엔드
//  엔티티가 복원되면 이 모델도 함께 확장해야 함.)
class Spot {
  final int id;
  final String title;
  final double lat;
  final double lng;
  final String category; // 노포 | 공원 | 카페 | 골목
  final String imageUrl;
  final String address;
  final String? description; // 카카오 로컬 소스는 소개글이 없어 null일 수 있음
  // 지도 핀 크기/색 차별화용 — SpotResponse가 내려주는데도 이 모델이 안 받아서
  // 지금까지 지도에 전혀 반영이 안 되고 있었다.
  final bool isLocalPick; // 팀이 수동 검증한 로컬 픽 여부 → 핀 색(강조)
  final bool trending; // 유저 반응(게시물 수/좋아요) 기준치 이상 → 핀 크기(확대)

  const Spot({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    required this.category,
    required this.imageUrl,
    required this.address,
    this.description,
    this.isLocalPick = false,
    this.trending = false,
  });

  factory Spot.fromJson(Map<String, dynamic> json) => Spot(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        category: json['category'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        address: json['address'] as String? ?? '',
        description: json['description'] as String?,
        isLocalPick: json['isLocalPick'] as bool? ?? false,
        trending: json['trending'] as bool? ?? false,
      );
}
