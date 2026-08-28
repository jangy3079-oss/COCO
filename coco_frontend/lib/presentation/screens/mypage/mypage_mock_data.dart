import '../../../data/models/user_type.dart';

// TODO: 로그인 연동 전까지의 "현재 로그인한 나" 목업. AUTH_API_SPEC.md 기준
// AuthResponse(nickname/role 등)가 실제로 연동되면 이 값들을 로그인 응답으로 교체.
// nickname/bio는 프로필 수정 화면에서 바뀌므로 top-level mutable 변수로 둔다
// (feed_mock_data.dart의 mockFeedItems와 동일한 공유 상태 패턴).
String myNickname = '민지';
String myBio = '중구에서 20년 살았어요. 노포 좋아합니다.';
const String myEmail = 'minji@example.com';
const String myNeighborhood = '중구';
const UserType myRole = UserType.local;

String get myRoleLabel => myRole == UserType.local ? '로컬 주민' : '관광객';

/// 마이 메인 프로필 원형 아바타 등에 쓰는 이니셜.
String get myInitial => myNickname.isNotEmpty ? myNickname.substring(0, 1) : '';
