// 로그인/회원가입 — coco_backend POST /api/auth/login, /api/auth/signup 연동.
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';

/// AuthResponse(백엔드 응답) 매핑 모델.
class AuthResult {
  final String accessToken;
  final int userId;
  final String email;
  final String nickname;
  final String role;
  final String locale;

  const AuthResult({
    required this.accessToken,
    required this.userId,
    required this.email,
    required this.nickname,
    required this.role,
    required this.locale,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['accessToken'] as String,
        userId: json['userId'] as int,
        email: json['email'] as String,
        nickname: json['nickname'] as String,
        role: json['role'] as String,
        locale: json['locale'] as String? ?? 'ko',
      );
}

/// 로그인/회원가입 실패 시 사용자에게 그대로 보여줄 메시지.
/// (GlobalExceptionHandler가 { "message": "..." } 형태로 내려주는 걸 그대로 옮김)
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  final Dio _dio = DioClient.instance;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) {
    return _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<AuthResult> signup({
    required String email,
    required String password,
    required String nickname,
    required String role, // UserType.apiValue — 'LOCAL' | 'TOURIST'
    String locale = 'ko',
  }) {
    return _post('/api/auth/signup', {
      'email': email,
      'password': password,
      'nickname': nickname,
      'role': role,
      'locale': locale,
    });
  }

  Future<AuthResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(path, data: body);
      return AuthResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : '서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.';
      throw AuthException(message);
    }
  }
}
