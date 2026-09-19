// 로그인한 내 프로필 조회/수정 — coco_backend /api/users/me 연동.
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/user_profile.dart';

class UserRepository {
  final Dio _dio = DioClient.instance;

  /// 마이페이지에서 보여줄 내 프로필(닉네임/이메일/역할/자기소개/프로필사진).
  Future<UserProfile> fetchMyProfile() async {
    final response = await _dio.get('/api/users/me');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// 프로필 편집 — nickname/bio 둘 다 선택사항, 보낸 필드만 갱신된다.
  Future<UserProfile> updateMyProfile({String? nickname, String? bio}) async {
    final response = await _dio.patch('/api/users/me', data: {
      if (nickname != null) 'nickname': nickname,
      if (bio != null) 'bio': bio,
    });
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
