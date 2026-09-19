import '../../../core/network/auth_token_store.dart';
import '../../../data/models/user_type.dart';

// nickname/role은 로그인 시 AuthTokenStore에 저장된 실제 로그인 응답(AuthResult)을 읽는다.
// 값이 없을 때(비정상 진입 등)만 아래 폴백을 쓴다.
// bio는 이제 백엔드(users.bio)에 저장되지만, 로그인 응답에는 포함되지 않고 프로필
// 편집 화면에서 GET/PATCH로만 주고받는다 — 그래서 세션 동안의 캐시 용도로 top-level
// mutable 변수를 그대로 둔다.
String get myNickname => AuthTokenStore.nickname ?? '';
set myNickname(String value) => AuthTokenStore.setNickname(value);
String myBio = '';
String get myEmail => AuthTokenStore.email ?? '';

// TODO: 동네(예: "중구")는 아직 users 테이블/AuthResponse 어디에도 없는 필드라
// 실제 로그인 유저 값으로 연결할 수 없음. 백엔드에 컬럼을 추가하기 전까지는
// 빈 문자열로 비워둠 — mypage_screen.dart에서 빈 값이면 칩 자체를 숨긴다.
const String myNeighborhood = '';

UserType get myRole => AuthTokenStore.role == 'TOURIST' ? UserType.tourist : UserType.local;

String get myRoleLabel => myRole == UserType.local ? '로컬 주민' : '관광객';

/// 마이 메인 프로필 원형 아바타 등에 쓰는 이니셜.
String get myInitial => myNickname.isNotEmpty ? myNickname.substring(0, 1) : '';
