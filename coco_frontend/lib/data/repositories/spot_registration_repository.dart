// 스팟 등록 신청 — coco_backend /api/spot/register 연동.
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/spot_registration.dart';

class SpotRegistrationRepository {
  final Dio _dio = DioClient.instance;

  /// 새 스팟 등록 신청 — 로그인 필요(401).
  Future<SpotRegistration> register({
    required String name,
    required String category,
    required String address,
    required double lat,
    required double lng,
    String? description,
  }) async {
    final response = await _dio.post('/api/spot/register', data: {
      'name': name,
      'category': category,
      'address': address,
      'lat': lat,
      'lng': lng,
      'description': description,
    });
    return SpotRegistration.fromJson(response.data as Map<String, dynamic>);
  }

  /// 내가 신청한 등록 목록 + 심사 상태 — 로그인 필요(401).
  Future<List<SpotRegistration>> fetchMine() async {
    final response = await _dio.get('/api/spot/register/mine');
    return (response.data as List)
        .map((e) => SpotRegistration.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 실시간 장소 검색(카카오 로컬 키워드 검색 프록시) — 스팟 등록 검색 화면 전용.
  /// GET /api/spot/search/external?q=&locale= 을 호출하고,
  /// 응답 형태(name/address/lat/lng)를 그대로 반환한다 — 화면이 SpotSearchCandidate.fromJson으로 변환.

  Future<List<dynamic>> searchExternal(String q, {String locale = 'ko'}) async {
    final response = await _dio.get(
      '/api/spot/search/external',
      queryParameters: {'q': q, 'locale': locale},
    );
    return response.data as List;
  }
}
