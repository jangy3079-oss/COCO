// 유저 UGC 피드 포스트 모델
class FeedPost {
  final String id;
  final String userId;
  final String userNickname;
  final String imageUrl;
  final String description;
  final String spotId;      // 위치태그 (Spot.id 참조)
  final String spotName;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final int likeCount;
  final List<String> tags;

  const FeedPost({
    required this.id,
    required this.userId,
    required this.userNickname,
    required this.imageUrl,
    required this.description,
    required this.spotId,
    required this.spotName,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.likeCount,
    required this.tags,
  });
}
