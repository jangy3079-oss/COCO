// Q&A 게시글 CRUD + 답변/채택 — coco_backend /api/qna 연동.
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/qna_post.dart';

class QnaRepository {
  final Dio _dio = DioClient.instance;

  /// 질문 목록. filter: all|unanswered|mine(로그인 필요), sort: latest|unanswered_first.
  Future<List<QnaPost>> listPosts({String filter = 'all', String sort = 'latest'}) async {
    final response = await _dio.get(
      '/api/qna/posts',
      queryParameters: {'filter': filter, 'sort': sort},
    );
    return (response.data as List)
        .map((e) => QnaPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 질문 작성. spotId는 선택 — 로그인 필요.
  Future<QnaPost> createPost({
    required String title,
    required String content,
    int? spotId,
    String locale = 'ko',
  }) async {
    final response = await _dio.post('/api/qna/posts', data: {
      'title': title,
      'content': content,
      'spotId': spotId,
      'locale': locale,
    });
    return QnaPost.fromJson(response.data as Map<String, dynamic>);
  }

  /// 질문 상세 + 답변 목록.
  Future<QnaPostDetail> getPostDetail(int postId) async {
    final response = await _dio.get('/api/qna/posts/$postId');
    return QnaPostDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// 답변 등록 — 로그인 필요.
  Future<QnaAnswer> createAnswer(int postId, String content) async {
    final response = await _dio.post('/api/qna/posts/$postId/answers', data: {'content': content});
    return QnaAnswer.fromJson(response.data as Map<String, dynamic>);
  }

  /// 답변 채택 — 질문 작성자 본인만 가능(아니면 403).
  Future<void> adopt(int postId, int answerId) async {
    await _dio.post('/api/qna/posts/$postId/adopt', data: {'answerId': answerId});
  }
}
