// 실제 백엔드(GET/PATCH /api/users/me)가 내려주는 내 프로필 모델.
// coco_backend UserProfileResponse와 1:1로 맞춘 형태.
class UserProfile {
  final int id;
  final String nickname;
  final String email;
  final String role;
  final String? bio;
  final String? profileImageUrl;

  const UserProfile({
    required this.id,
    required this.nickname,
    required this.email,
    required this.role,
    this.bio,
    this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      bio: json['bio'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}
