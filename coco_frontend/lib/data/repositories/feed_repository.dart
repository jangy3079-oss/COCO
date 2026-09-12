// 유저 UGC 피드 CRUD + 좋아요/댓글 — coco_backend /api/feed 연동.
// 코스(경로) 첨부 게시물은 아직 없음 — 그 부분은 여전히 feed_mock_data.dart의 목업이 담당한다.
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/feed_post.dart';

class FeedRepository {
  final Dio _dio = DioClient.instance;

  /// 최신순 피드 목록 (백엔드가 최대 50개까지 내려준다).
  Future<List<FeedPost>> fetchFeed() async {
    final response = await _dio.get('/api/feed');
    return (response.data as List)
        .map((e) => FeedPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 로그인한 사용자가 스팟을 태그해서 글을 쓴다. 로그인 안 된 상태면 백엔드가 401을 준다.
  Future<FeedPost> createPost({String? imageUrl, String? description, required int spotId}) async {
    final response = await _dio.post('/api/feed', data: {
      'imageUrl': imageUrl,
      'description': description,
      'spotId': spotId,
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

  /// 좋아요 토글 — 이미 눌렀으면 취소, 아니면 새로 누른다. {liked, likeCount} 반환.
  Future<({bool liked, int likeCount})> toggleLike(int postId) async {
    final response = await _dio.post('/api/feed/$postId/like');
    final data = response.data as Map<String, dynamic>;
    return (liked: data['liked'] as bool, likeCount: data['likeCount'] as int);
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
