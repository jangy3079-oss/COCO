/// 로그인 시 발급받은 JWT를 앱 실행 중에만 보관하는 메모리 저장소.
/// DioClient의 인증 인터셉터가 여기서 토큰을 읽어 Authorization 헤더에 붙인다.
/// (재실행 후에도 로그인 유지가 필요해지면 shared_preferences 등 영속 저장소로 교체)
class AuthTokenStore {
  AuthTokenStore._();

  static String? _token;

  static String? get token => _token;

  static void setToken(String token) => _token = token;

  static void clear() => _token = null;
}
