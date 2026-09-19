import 'dart:convert';
import 'dart:typed_data';

const _feedUploadPrefix = '/uploads/feed/';
const _imageListMarker = '~';
const _extensionCodes = {
  'jpg': 'j',
  'jpeg': 'e',
  'png': 'p',
  'webp': 'w',
  'heic': 'h',
  'gif': 'g',
};

/// 단일 imageUrl 필드를 유지하면서 최대 10개의 업로드 경로를 255자 안에 담는다.
/// UUID의 16바이트를 base64url로 줄여 저장하고, 화면에서 원래 경로로 복원한다.
String encodeFeedImageUrls(List<String> urls) {
  if (urls.isEmpty) return '';
  final pattern = RegExp(
    r'^/uploads/feed/([0-9a-fA-F]{8})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{12})\.([A-Za-z0-9]+)$',
  );
  final tokens = <String>[];
  for (final url in urls) {
    final match = pattern.firstMatch(url);
    final extension = match == null ? null : match.group(6)!.toLowerCase();
    final extensionCode = extension == null ? null : _extensionCodes[extension];
    if (match == null || extensionCode == null) return urls.join('|');
    final hex = [for (var i = 1; i <= 5; i++) match.group(i)!].join();
    final bytes = Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
    tokens.add('${base64Url.encode(bytes).replaceAll('=', '')}$extensionCode');
  }
  return '$_imageListMarker${tokens.join('.')}';
}

List<String> decodeFeedImageUrls(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  if (!value.startsWith(_imageListMarker)) {
    return value
        .split('|')
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
  }
  final extensionByCode = {
    for (final entry in _extensionCodes.entries) entry.value: entry.key
  };
  try {
    return value.substring(1).split('.').map((token) {
      final extension = extensionByCode[token.substring(token.length - 1)];
      if (extension == null)
        throw const FormatException('Unknown image extension');
      var encoded = token.substring(0, token.length - 1);
      encoded += '=' * ((4 - encoded.length % 4) % 4);
      final bytes = base64Url.decode(encoded);
      if (bytes.length != 16) throw const FormatException('Invalid image id');
      final hex =
          bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      return '$_feedUploadPrefix$uuid.$extension';
    }).toList(growable: false);
  } catch (_) {
    return const [];
  }
}

// 실제 백엔드(GET/POST /api/feed)가 내려주는/받는 피드 게시물 모델.
// coco_backend FeedPostResponse와 1:1로 맞춘 형태.
class FeedPost {
  final int id;
  final String userNickname;
  final String? imageUrl;
  final String? description;
  final int? spotId; // 스팟 태그 없이 쓴 글이면 null
  final String? spotName;
  final double? lat;
  final double? lng;
  final int? routeId; // 코스 공유로 만들어진 게시물이면 그 코스 id, 아니면 null
  final int likeCount;
  final DateTime createdAt;
  final bool trending; // SpotService.isTrending 기준 — 피드 카드 "인기" 배지용
  final bool liked; // 로그인한 요청자가 이 게시물에 좋아요를 눌렀는지 (비로그인이면 항상 false)
  final bool saved; // 로그인한 요청자가 이 게시물을 저장했는지 (비로그인이면 항상 false)
  final int saveCount; // 총 저장 수

  List<String> get imageUrls => decodeFeedImageUrls(imageUrl);

  const FeedPost({
    required this.id,
    required this.userNickname,
    this.imageUrl,
    this.description,
    this.spotId,
    this.spotName,
    this.lat,
    this.lng,
    this.routeId,
    required this.likeCount,
    required this.createdAt,
    required this.trending,
    required this.liked,
    required this.saved,
    required this.saveCount,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as int,
      userNickname: json['userNickname'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      spotId: json['spotId'] as int?,
      spotName: json['spotName'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      routeId: json['routeId'] as int?,
      likeCount: json['likeCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      trending: json['trending'] as bool? ?? false,
      liked: json['liked'] as bool? ?? false,
      saved: json['saved'] as bool? ?? false,
      saveCount: json['saveCount'] as int? ?? 0,
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
