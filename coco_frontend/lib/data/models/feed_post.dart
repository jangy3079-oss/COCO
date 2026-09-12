// 실제 백엔드(GET/POST /api/feed)가 내려주는/받는 피드 게시물 모델.
// coco_backend FeedPostResponse와 1:1로 맞춘 형태.
class FeedPost {
  final int id;
  final String userNickname;
  final String? imageUrl;
  final String? description;
  final int spotId;
  final String spotName;
  final double lat;
  final double lng;
  final int likeCount;
  final DateTime createdAt;
  final bool trending; // SpotService.isTrending 기준 — 피드 카드 "인기" 배지용
  final bool liked; // 로그인한 요청자가 이 게시물에 좋아요를 눌렀는지 (비로그인이면 항상 false)

  const FeedPost({
    required this.id,
    required this.userNickname,
    this.imageUrl,
    this.description,
    required this.spotId,
    required this.spotName,
    required this.lat,
    required this.lng,
    required this.likeCount,
    required this.createdAt,
    required this.trending,
    required this.liked,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as int,
      userNickname: json['userNickname'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      spotId: json['spotId'] as int,
      spotName: json['spotName'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      likeCount: json['likeCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      trending: json['trending'] as bool? ?? false,
      liked: json['liked'] as bool? ?? false,
    );
  }
}

// coco_backend FeedCommentResponse와 1:1로 맞춘 댓글 모델.
class FeedCommentDto {
  final int id;
  final String userNickname;
  final String content;
  final DateTime createdAt;

  const FeedCommentDto({
    required this.id,
    required this.userNickname,
    required this.content,
    required this.createdAt,
  });

  factory FeedCommentDto.fromJson(Map<String, dynamic> json) {
    return FeedCommentDto(
      id: json['id'] as int,
      userNickname: json['userNickname'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
