// 유저 UGC 피드 CRUD + 좋아요/댓글 — coco_backend /api/feed 연동.
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/feed_post.dart';

class FeedRepository {
  final Dio _dio = DioClient.instance;

  /// 최신순 피드 목록 (백엔드가 최대 50개까지 내려준다). locale에 맞는 번역이 있으면
  /// 그걸로, 없으면 한국어 원문으로 description을 내려준다(SpotRepository와 동일 패턴).
  Future<List<FeedPost>> fetchFeed({String locale = 'ko'}) async {
    final response = await _dio.get('/api/feed', queryParameters: {'locale': locale});
    return (response.data as List)
        .map((e) => FeedPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 로그인한 사용자가 글을 쓴다. 스팟 태그·코스 공유는 선택 — 로그인 안 된 상태면 백엔드가 401을 준다.
  /// locale은 description이 작성된 언어 — 백엔드가 이걸 기준으로 나머지 두 언어를 번역해 저장한다.
  Future<FeedPost> createPost({
    String? imageUrl,
    String? description,
    int? spotId,
    int? routeId,
    String locale = 'ko',
  }) async {
    final response = await _dio.post('/api/feed', data: {
      'imageUrl': imageUrl,
      'description': description,
      'spotId': spotId,
      'routeId': routeId,
      'locale': locale,
    });
    return FeedPost.fromJson(response.data as Map<String, dynamic>);
  }

  /// 게시물 작성 전, 사진 바이트를 먼저 올려 상대경로 imageUrl을 받아온다.
  /// (반환값을 그대로 createPost의 imageUrl로 넘기면 됨)
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post('/api/feed/images', data: formData);
    return response.data['imageUrl'] as String;
  }

  /// 로그인한 사용자가 좋아요한 피드만 가져온다 — GET /api/feed/liked.
  /// my_saved_screen.dart의 "좋아요한 피드" 탭 전용.
  Future<List<FeedPost>> fetchLikedFeed({String locale = 'ko'}) async {
    final response = await _dio.get('/api/feed/liked', queryParameters: {'locale': locale});
    return (response.data as List)
        .map((e) => FeedPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 좋아요 토글 — 이미 눌렀으면 취소, 아니면 새로 누른다. {liked, likeCount} 반환.
  Future<({bool liked, int likeCount})> toggleLike(int postId) async {
    final response = await _dio.post('/api/feed/$postId/like');
    final data = response.data as Map<String, dynamic>;
    return (liked: data['liked'] as bool, likeCount: data['likeCount'] as int);
  }

  /// 저장(북마크) 토글 — 이미 저장했으면 취소, 아니면 새로 저장한다. {saved, saveCount} 반환.
  Future<({bool saved, int saveCount})> toggleSave(int postId) async {
    final response = await _dio.post('/api/feed/$postId/save');
    final data = response.data as Map<String, dynamic>;
    return (saved: data['saved'] as bool, saveCount: data['saveCount'] as int);
  }

  /// 로그인한 사용자가 저장한 피드 목록 — GET /api/feed/saved.
  /// my_saved_screen.dart의 "저장한 피드" 탭 전용.
  Future<List<FeedPost>> fetchSavedFeed({String locale = 'ko'}) async {
    final response = await _dio.get('/api/feed/saved', queryParameters: {'locale': locale});
    return (response.data as List)
        .map((e) => FeedPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FeedCommentDto>> fetchComments(int postId) async {
    final response = await _dio.get('/api/feed/$postId/comments');
    return (response.data as List)
        .map((e) => FeedCommentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FeedCommentDto> createComment(int postId, String content) async {
    final response = await _dio.post('/api/feed/$postId/comments', data: {'content': content});
    return FeedCommentDto.fromJson(response.data as Map<String, dynamic>);
  }
}
