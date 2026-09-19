/// 로그인 시 발급받은 JWT를 앱 실행 중에만 보관하는 메모리 저장소.
/// DioClient의 인증 인터셉터가 여기서 토큰을 읽어 Authorization 헤더에 붙인다.
/// (재실행 후에도 로그인 유지가 필요해지면 shared_preferences 등 영속 저장소로 교체)
class AuthTokenStore {
  AuthTokenStore._();

  static String? _token;
  static String? _nickname;
  static String? _role; // 'LOCAL' | 'TOURIST' (AuthResult.role 그대로)
  static String? _email;

  static String? get token => _token;
  static String? get nickname => _nickname;
  static String? get role => _role;
  static String? get email => _email;

  static void setToken(String token) => _token = token;

  /// 로그인/회원가입 성공 시 setToken과 함께 호출 — 마이탭 등에서 쓰는
  /// "현재 로그인한 나" 정보(닉네임/역할/이메일)를 메모리에 보관한다.
  static void setUser({required String nickname, required String role, String? email}) {
    _nickname = nickname;
    _role = role;
    _email = email;
  }

  /// 프로필 수정 화면에서 닉네임만 바꿀 때 사용.
  /// (백엔드에 프로필 수정 API가 아직 없어 로컬 값만 갱신됨 — 새로고침하면 로그인 응답 값으로 되돌아감)
  static void setNickname(String nickname) => _nickname = nickname;

  static void clear() {
    _token = null;
    _nickname = null;
    _role = null;
    _email = null;
  }
}
