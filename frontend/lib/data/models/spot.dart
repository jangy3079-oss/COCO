// 로컬 스팟 모델 (TourAPI contentId 기반)
class Spot {
  final String id;
  final String title;
  final String titleEn;
  final String titleJa;
  final double lat;
  final double lng;
  final String category;   // 노포 | 공원 | 카페 | 골목
  final String imageUrl;
  final String address;

  const Spot({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.titleJa,
    required this.lat,
    required this.lng,
    required this.category,
    required this.imageUrl,
    required this.address,
  });
}
