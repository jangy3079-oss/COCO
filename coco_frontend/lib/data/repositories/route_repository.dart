// 코스(골목지도) CRUD + 좋아요/저장/공유 — coco_backend /api/routes 연동.
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/route.dart';

class RouteRepository {
  final Dio _dio = DioClient.instance;

  /// 공개 코스 전체 목록(최신순) — 로그인 없이도 조회 가능.
  Future<List<RouteMap>> listPublic() async {
    final response = await _dio.get('/api/routes', queryParameters: {'owner': 'public'});
    return (response.data as List).map((e) => RouteMap.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 내가 만든 코스 목록 — 로그인 필요(401).
  Future<List<RouteMap>> listMine() async {
    final response = await _dio.get('/api/routes/mine');
    return (response.data as List).map((e) => RouteMap.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 코스 상세 + 스팟 목록.
  Future<RouteMap> getById(int id) async {
    final response = await _dio.get('/api/routes/$id');
    return RouteMap.fromJson(response.data as Map<String, dynamic>);
  }

  /// 스팟들을 순서대로 엮어 코스를 만든다 — 로그인 필요(401).
  Future<RouteMap> create({
    required String name,
    required List<int> spotIds,
    String? visibility,
    bool? isDraft,
  }) async {
    final response = await _dio.post('/api/routes', data: {
      'name': name,
      'spotIds': spotIds,
      'visibility': visibility,
      'isDraft': isDraft,
    });
    return RouteMap.fromJson(response.data as Map<String, dynamic>);
  }

  /// 이름/스팟 목록/공개범위 수정 — 작성자 본인만 가능(아니면 403).
  Future<RouteMap> update(
    int id, {
    required String name,
    required List<int> spotIds,
    String? visibility,
    bool? isDraft,
  }) async {
    final response = await _dio.put('/api/routes/$id', data: {
      'name': name,
      'spotIds': spotIds,
      'visibility': visibility,
      'isDraft': isDraft,
    });
    return RouteMap.fromJson(response.data as Map<String, dynamic>);
  }

  /// 코스 삭제 — 작성자 본인만 가능(아니면 403).
  Future<void> delete(int id) async {
    await _dio.delete('/api/routes/$id');
  }

  /// 좋아요 토글 — 로그인 필요(401).
  Future<({bool liked, int likeCount})> toggleLike(int id) async {
    final response = await _dio.post('/api/routes/$id/like');
    final data = response.data as Map<String, dynamic>;
    return (liked: data['liked'] as bool, likeCount: data['likeCount'] as int);
  }

  /// 저장(북마크) 토글 — 로그인 필요(401).
  Future<({bool saved, int saveCount})> toggleSave(int id) async {
    final response = await _dio.post('/api/routes/$id/save');
    final data = response.data as Map<String, dynamic>;
    return (saved: data['saved'] as bool, saveCount: data['saveCount'] as int);
  }

  /// 공유 — 토글이 아니라 누를 때마다 shareCount가 증가한다. 로그인 불필요.
  Future<int> share(int id) async {
    final response = await _dio.post('/api/routes/$id/share');
    return (response.data as Map<String, dynamic>)['shareCount'] as int;
  }
}
