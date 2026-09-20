// Spot 조회 — coco_backend GET /api/spot 연동.
// (POST /api/spot/import는 TourAPI 수집용 관리자 트리거라 프론트에서 호출할 일 없음)
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/spot.dart';

class SpotRepository {
  final Dio _dio = DioClient.instance;

  /// 지도 뷰포트(화면에 보이는 영역) 안의 스팟만 조회 — 줌/이동 시마다 다시 호출.
  Future<List<Spot>> fetchSpotsInViewport({
    required double swLat,
    required double neLat,
    required double swLng,
    required double neLng,
    String? category,
    String locale = 'ko',
  }) async {
    final response = await _dio.get(
      '/api/spot',
      queryParameters: {
        'swLat': swLat,
        'neLat': neLat,
        'swLng': swLng,
        'neLng': neLng,
        if (category != null) 'category': category,
        'locale': locale,
      },
    );
    return (response.data as List)
        .map((e) => Spot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 지도 전용 조회 — 6개 카테고리 중 하나를 반드시 지정해야 한다("전체"/누락 호출 금지,
  /// 그런 경우는 프론트에서 API를 아예 안 부르고 빈 리스트로 처리해야 함).
  Future<List<Spot>> fetchMapSpots({
    required double swLat,
    required double neLat,
    required double swLng,
    required double neLng,
    required String category,
    String locale = 'ko',
  }) async {
    final response = await _dio.get(
      '/api/spot/map',
      queryParameters: {
        'swLat': swLat,
        'neLat': neLat,
        'swLng': swLng,
        'neLng': neLng,
        'category': category,
        'locale': locale,
      },
    );
    return (response.data as List)
        .map((e) => Spot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 스팟 상세 화면용 단건 조회. 없으면 null.
  Future<Spot?> fetchById(int id, {String locale = 'ko'}) async {
    try {
      final response = await _dio.get(
        '/api/spot/$id',
        queryParameters: {'locale': locale},
      );
      return Spot.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 제목/주소 키워드 검색 — 코스 만들기 "+ 스팟 추가" 등에서 사용.
  Future<List<Spot>> search(String query, {String locale = 'ko'}) async {
    final response = await _dio.get(
      '/api/spot/search',
      queryParameters: {'q': query, 'locale': locale},
    );
    return (response.data as List)
        .map((e) => Spot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 찜 토글 — 이미 찜했으면 취소, 아니면 새로 찜한다. 로그인 필요(401).
  Future<({bool liked, int likeCount})> toggleLike(int spotId) async {
    final response = await _dio.post('/api/spot/$spotId/like');
    final data = response.data as Map<String, dynamic>;
    return (liked: data['liked'] as bool, likeCount: data['likeCount'] as int);
  }

  /// 현재 로그인한 사용자가 찜한 스팟 목록. 로그인 필요(401).
  Future<List<Spot>> fetchLikedSpots({String locale = 'ko'}) async {
    final response = await _dio.get('/api/spot/liked', queryParameters: {'locale': locale});
    return (response.data as List)
        .map((e) => Spot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 정보가 부족한 스팟(설명/사진이 비어있는 경우, 주로 카카오 로컬 소스)에 사용자가
  /// 소개글/사진을 채워 넣는다. description·imageBytes 중 하나만 보내도 되고,
  /// 백엔드는 이미 값이 있는 필드는 덮어쓰지 않고 빈 필드만 채운다(요청서 Part 4).
  /// 갱신된 스팟 전체를 GET /api/spot/{id}와 같은 모양으로 반환한다고 가정 —
  /// 백엔드 응답 형태가 다르면 이 메서드만 맞춰 고치면 됨. 로그인 필요(401).
  Future<Spot> enrichSpot(
    int spotId, {
    String? description,
    Uint8List? imageBytes,
    String imageFilename = 'photo.jpg',
    String locale = 'ko',
  }) async {
    final trimmedDescription = description?.trim();
    final formData = FormData.fromMap({
      if (trimmedDescription != null && trimmedDescription.isNotEmpty) 'description': trimmedDescription,
      if (imageBytes != null) 'image': MultipartFile.fromBytes(imageBytes, filename: imageFilename),
      'locale': locale,
    });
    final response = await _dio.post('/api/spot/$spotId/enrich', data: formData);
    return Spot.fromJson(response.data as Map<String, dynamic>);
  }
}
