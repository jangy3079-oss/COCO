// 백엔드(coco_backend) 호출용 공통 Dio 클라이언트.
// baseUrl 해석 + 인증 토큰 첨부 + (디버그 모드) 요청/응답 로깅을 담당한다.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth_token_store.dart';

class DioClient {
  DioClient._();

  static final Dio instance = _create();

  /// 백엔드가 내려주는 상대 경로(예: "/uploads/feed/xxx.jpg")를 실제로 불러오려면
  /// 이 baseUrl을 앞에 붙여야 한다 — 이미지 표시(Image.network)에서 사용.
  static String get baseUrl => instance.options.baseUrl;

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _resolveBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    // 로그인된 상태면 모든 요청에 Authorization 헤더를 자동으로 붙여준다.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AuthTokenStore.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    // 디버그 빌드에서만 요청/응답을 콘솔에 출력 (릴리즈에는 포함되지 않음).
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    return dio;
  }

  /// .env의 API_BASE_URL이 설정돼 있으면 그 값을 최우선으로 쓰고,
  /// 없으면 실행 플랫폼에 맞는 기본값으로 폴백한다.
  /// - 웹(Chrome): http://localhost:8080
  /// - 안드로이드 에뮬레이터: http://10.0.2.2 가 호스트 PC(localhost)를 가리킴
  /// - 그 외(iOS 시뮬레이터 등): http://localhost:8080
  static String _resolveBaseUrl() {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
