// 회원 유형 — 로컬 주민 / 관광객
// DB users 테이블의 role 컬럼과 매핑됨 (Q&A 답변 권한 등 후속 기능에서 활용)
enum UserType {
  local,
  tourist;

  String get apiValue => switch (this) {
        UserType.local => 'LOCAL',
        UserType.tourist => 'TOURIST',
      };
}
