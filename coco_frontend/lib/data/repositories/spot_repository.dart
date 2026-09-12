// Spot 조회 — coco_backend GET /api/spot 연동.
// (POST /api/spot/import는 TourAPI 수집용 관리자 트리거라 프론트에서 호출할 일 없음)
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

  /// 스팟 상세 화면용 단건 조회. 없으면 null.
  Future<Spot?> fetchById(int id) async {
    try {
      final response = await _dio.get('/api/spot/$id');
      return Spot.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 제목/주소 키워드 검색 — 코스 만들기 "+ 스팟 추가" 등에서 사용.
  Future<List<Spot>> search(String query) async {
    final response = await _dio.get('/api/spot/search', queryParameters: {'q': query});
    return (response.data as List)
        .map((e) => Spot.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
