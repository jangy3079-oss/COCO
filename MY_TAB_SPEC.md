# 마이(MY)탭 기능 명세서

범위: 프로필 정보 / 나의 지도(찜한 스팟) / 내가 쓴 글 / 저장·좋아요 모아보기 / 앱 설정. 지도·피드·커뮤니티 탭에 이미 있는 좋아요·저장 상호작용을 한곳에 모아 보여주고 수정하는 탭.

## 1. 개요

MY탭은 "내 활동을 한눈에" 보여주는 허브다. 지도·피드·커뮤니티 탭에서 만든 콘텐츠(글, 찜한 스팟, 좋아요/저장)를 별도 화면 이동 없이 탭 전환만으로 확인·수정할 수 있게 한다.

핵심 아이디어 2가지:
- **나의 지도**: 내가 찜한 스팟들이 표시된 부산 지도를 작은 위젯(미리보기)으로 MY탭 상단에 노출하고, 탭하면 전체화면 지도로 이동.
- **탭 UI**: [내가 쓴 글] / [저장·좋아요] / [설정] 3개를 화면 전환이 아니라 같은 화면 안 탭(TabBar)으로 전환 — 탭을 눌러도 페이지가 안 바뀌고, 그 안에서 바로 수정·확인까지 끝낸다.

## 2. 정보구조 (화면 3개 + 인앱 탭 3개)

1. **MY 메인** (`/mypage`) — 프로필 헤더 + 나의 지도 위젯 + [내가 쓴 글]/[저장·좋아요]/[설정] 인앱 탭. 하단 탭바(ShellRoute) 유지.
2. **나의 지도 전체화면** (`/mypage/map`) — 지도 탭과 같은 지도 UI, 찜한 스팟만 표시. 하단 탭 없는 전체화면(지도 탭 스팟상세·피드 상세와 동일하게 ShellRoute 바깥 최상위 라우트).
3. **프로필 수정** (`/mypage/profile/edit`) — 닉네임·자기소개·프로필사진 수정. 하단 탭 없는 전체화면.

인앱 탭 3개는 모두 화면 1(MY 메인) 안의 `TabBarView`이며 별도 라우트가 없다 — 탭 전환 시 URL이 바뀌지 않는다.

## 3. 사용자 역할 및 권한

- MY탭 전체가 로그인 전제다. 비로그인 상태로 진입하면 로그인 화면으로 유도(다른 탭의 글쓰기 액션과 동일한 패턴).
- 로컬 주민/관광객 역할에 따른 기능 차이는 없음 — 프로필 배지 표시만 다르다(`UserType.local` → "로컬", `UserType.tourist` → "관광객").
- 가입 시 정한 역할(로컬/관광객)은 Q&A 답변 배지·권한과 직결되므로 **MY탭에서 수정 불가**로 우선 가정(9번 참고, 확정 필요).

## 4. 핵심 기능 상세

### 4.1 프로필 영역 (MY 메인 상단, 고정)
- 표시: 프로필 사진(원형, 미설정 시 닉네임 첫 글자 이니셜), 닉네임, 역할 배지(로컬/관광객), 자기소개 한 줄(없으면 "자기소개를 추가해보세요" 안내 문구), "프로필 수정" 버튼 → `/mypage/profile/edit`
- 수정 화면 입력 항목: 닉네임(필수), 자기소개(선택, 최대 60자), 프로필 사진(갤러리에서 선택 — 실제 업로드 연동 전까지는 로컬 미리보기만)
- 이메일은 표시만 하고 수정 불가(계정 식별자)

### 4.2 나의 지도
- MY 메인에 있는 **위젯(미리보기)**: 지도 탭의 목업 지도 배경을 축소한 카드(높이 약 140px), 내가 찜한 스팟 핀만 표시, 우측 상단에 "전체보기 >" 텍스트. 카드 전체가 탭 영역.
- 탭하면 **전체화면**(`/mypage/map`)으로 이동 — 지도 탭(`map_screen.dart`)의 지도 배경·핀·스팟 탭→상세 이동 로직을 그대로 재사용하되, `mockSpots` 전체가 아니라 찜한 스팟(`likedSpotIds`/`savedSpotIds`)만 필터링해서 표시. 검색바·카테고리 칩은 없음(찜한 스팟 개수가 적어 불필요), 대신 상단에 "찜한 스팟 N곳" 헤더.
- 찜한 스팟이 0개면 위젯 자리에 "아직 찜한 스팟이 없어요 · 지도 탭에서 스팟을 찜해보세요" 빈 상태 + 지도 탭으로 이동하는 버튼.

### 4.3 인앱 탭 — 내가 쓴 글
- 서브 필터: 전체 / 피드 게시물 / 질문(Q&A) — `feed_mock_data.dart`의 `mockFeedItems` 중 작성자가 나인 것 + `qna_mock_data.dart`의 `qnaMockPosts` 중 `mine == true`인 것을 시간순으로 합쳐서 리스트.
- 카드에 표시: (피드) 사진 썸네일·장소명·좋아요/댓글 수, (질문) 제목·답변 수·해결됨 여부 — 각각 기존 피드/커뮤니티 카드 스타일 재사용.
- 탭하면 기존 상세 화면(`feed_post_detail_screen.dart` / `qna_post_detail_screen.dart`)으로 이동(재사용, 신규 화면 없음).
- 각 카드 우측에 ⋯ 메뉴 → "삭제"(확인 다이얼로그 후 목록에서 제거). "수정"은 9번에서 범위 확정 필요(현재 작성 화면들이 신규 작성 전용이라 수정 모드가 없음).

### 4.4 인앱 탭 — 저장·좋아요 모아보기
- 서브 필터: 찜한 스팟 / 좋아요한 피드 / 저장한 피드 / 저장한 코스
  - 찜한 스팟: `likedSpotIds` ∪ `savedSpotIds`에 해당하는 `MockSpot` 리스트 (지도 탭 스팟 리스트 타일 스타일 재사용)
  - 좋아요한 피드 / 저장한 피드: `mockFeedItems.where((f) => f.liked)` / `.where((f) => f.saved)` (피드 카드 스타일 재사용)
  - 저장한 코스: 골목지도 만들기(`route_builder_screen.dart`)로 내가 만든 코스 목록 — **9번 참고, 코스가 아직 영속 저장되지 않아 신규 데이터 모델 필요**
- 각 아이템에 좋아요/저장 아이콘이 그대로 노출되어, 탭 안에서 바로 눌러서 해제 가능(별도 화면 이동 없이 즉시 목록에서 사라짐) — "확인뿐 아니라 그 자리에서 수정"이라는 요청을 반영.

### 4.5 인앱 탭 — 설정
- 언어: 한국어/English/日本語 선택(라디오 또는 드롭다운) — 이미 구축된 `lib/l10n/app_{ko,en,ja}.arb` 인프라와 연결
- 알림: 켜기/끄기 스위치 (실제 푸시 연동 전까지는 로컬 상태만 토글, 서버 반영 TODO)
- 로그아웃: 확인 다이얼로그 → 토큰 삭제 후 `/login`으로 이동
- 회원 탈퇴: 위험 액션이라 별도 확인 다이얼로그("정말 탈퇴하시겠어요? 이 작업은 되돌릴 수 없어요") — MVP 범위 포함 여부 9번에서 확정 필요

## 5. 화면별 UI 구성요소 (지도·피드·커뮤니티 탭과 톤 통일)

| 요소 | 스타일 |
|---|---|
| 색상 | `CocoTheme.primary`(스카이블루) 포인트, 배지·아이콘 활성 상태 모두 동일 컬러 시스템 |
| 인앱 탭바 | Material `TabBar`, 선택 인디케이터 `CocoTheme.primary`, 비선택 텍스트는 커뮤니티 탭 하단 네비와 동일한 회색(`#616161`) |
| 카드 | 흰 배경, 옅은 하단 구분선 (피드·커뮤니티 카드와 동일 톤) |
| 나의 지도 위젯 | 지도 탭 `_MockMapBackground`를 축소 재사용, 카드 모서리 `borderRadius: 16` |
| 빈 상태 | 각 탭마다 안내 문구 + 해당 탭(지도/피드)으로 이동하는 버튼 |

## 6. 데이터 모델 (DB 반영안 — 기존 스키마 대비 변경/신규 필요)

프로젝트 지침의 DB 테이블 목록(`users, spots, qna_posts, qna_answers, feed_posts, feed_comments, spot_likes, feed_post_likes`)만으로는 MY탭 요구사항을 다 못 담는다. 아래 변경/신규가 필요하다(스키마 컨벤션: snake_case, 외래키 인라인 `FOREIGN KEY`).

```sql
-- 1) users 테이블에 컬럼 추가 (프로필 사진·자기소개)
ALTER TABLE users ADD COLUMN profile_image_url VARCHAR(255);
ALTER TABLE users ADD COLUMN bio VARCHAR(60);

-- 2) "좋아요"와 "저장(찜)"은 별개 개념인데 기존 spot_likes/feed_post_likes는
--    이름상 "좋아요"만 가리킴. 저장(찜) 전용 테이블을 새로 추가하거나,
--    기존 테이블에 구분 컬럼을 두는 두 가지 방식 중 택1 (9번 참고)
CREATE TABLE spot_saves (
  id       BIGSERIAL PRIMARY KEY,
  user_id  BIGINT NOT NULL REFERENCES users(id),
  spot_id  BIGINT NOT NULL REFERENCES spots(id),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (user_id, spot_id)
);

CREATE TABLE feed_post_saves (
  id       BIGSERIAL PRIMARY KEY,
  user_id  BIGINT NOT NULL REFERENCES users(id),
  feed_post_id BIGINT NOT NULL REFERENCES feed_posts(id),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (user_id, feed_post_id)
);

-- 3) "코스(골목지도)" 자체가 프로젝트 DB 테이블 목록에 없음.
--    나의 지도 / 저장한 코스 기능의 전제 조건이라 신규 테이블 필요
CREATE TABLE routes (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users(id),
  name       VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE route_stops (
  id        BIGSERIAL PRIMARY KEY,
  route_id  BIGINT NOT NULL REFERENCES routes(id),
  spot_id   BIGINT NOT NULL REFERENCES spots(id),
  stop_order INT NOT NULL
);
```

- 프론트 목업 단계에서는 백엔드 확정 전까지 `map_mock_data.dart`에 `Set<String> likedSpotIds`, `Set<String> savedSpotIds`(top-level 공유 상태로 승격 — 현재는 `spot_detail_screen.dart`/`map_screen.dart` 각 화면 로컬 상태라 MY탭에서 못 읽음, 이번에 반드시 공유 상태로 옮겨야 함)와, `my_mock_data.dart`(신규)에 `MyCourse`(id, name, stops, createdAt) 모델 + `mockMyCourses` 공유 리스트를 추가해서 화면부터 구현 가능.

## 7. API 엔드포인트 초안 (프론트 ↔ 백엔드)

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/api/users/me` | 내 프로필 조회 (닉네임/역할/이메일/프로필사진/자기소개) |
| PATCH | `/api/users/me` | 프로필 수정 `{ nickname?, bio?, profileImageUrl? }` |
| GET | `/api/users/me/posts?type=feed\|qna\|all` | 내가 쓴 글 모아보기 |
| DELETE | `/api/feed/posts/{id}`, `/api/qna/posts/{id}` | 내 글 삭제 (기존 피드/Q&A API에 작성자 본인 검증만 추가) |
| GET | `/api/users/me/saved?type=spot\|feed\|route` | 저장·좋아요 모아보기 |
| POST/DELETE | `/api/spots/{id}/save`, `/api/feed/posts/{id}/save` | 저장(찜) 토글 |
| GET | `/api/users/me/routes` | 내가 만든 코스 목록 (나의 지도용) |
| POST | `/api/auth/logout` | 로그아웃 (서버 세션/리프레시 토큰 무효화 방식에 따라 선택) |
| DELETE | `/api/users/me` | 회원 탈퇴 (범위 포함 시) |

모든 요청은 `Authorization: Bearer {accessToken}` 헤더 필요, 에러 응답은 `{ "message": "..." }` 포맷으로 통일 ([[AUTH_API_SPEC.md]] 컨벤션과 동일).

## 8. 프론트 연결 지점

- `lib/presentation/screens/mypage/mypage_screen.dart` — 현재 `Text('Mypage Screen')`만 있는 스텁, 이 명세 기준으로 프로필 헤더 + 나의 지도 위젯 + `TabBar`/`TabBarView` 구현 예정
- 신규 파일: `lib/presentation/screens/mypage/my_map_screen.dart`(전체화면 나의 지도), `lib/presentation/screens/mypage/profile_edit_screen.dart`
- 신규 목업 데이터: `lib/presentation/screens/mypage/my_mock_data.dart`(`MyCourse` 등), `map_mock_data.dart`에 찜 상태 공유 변수 추가
- 라우팅: `app_router.dart`에 `/mypage/map`, `/mypage/profile/edit`를 ShellRoute 바깥 최상위 라우트로 추가 (지도·피드·커뮤니티 탭과 동일 패턴)

## 9. 아직 안 정해진 것 (상의 필요)

- **찜한 스팟 상태 공유화**: 현재 스팟 좋아요/저장이 `spot_detail_screen.dart` 화면 자체의 로컬 State라 화면을 벗어나면 사라짐(다른 화면과 공유 안 됨). MY탭이 동작하려면 이걸 `map_mock_data.dart`의 top-level 공유 상태로 옮기는 선행 작업이 필요 — 지도 탭 동작(핀 색상 등)에 영향 없는지 확인 필요.
- **"좋아요" vs "저장(찜)" DB 분리 여부**: 6번처럼 테이블을 분리할지, 기존 `spot_likes`/`feed_post_likes`에 `type` 컬럼(LIKE/SAVE)을 추가해 한 테이블로 처리할지 — 백엔드 담당자와 상의 필요.
- **코스(routes) 기능 자체의 백엔드 존재 여부**: 프로젝트 DB 테이블 목록에 코스 관련 테이블이 없었음 — "나의 지도"·"저장한 코스" 요구사항의 전제 조건이라 이번에 새로 추가할지, 혹은 MVP에서는 코스를 서버 저장 없이 로컬(기기 내)에만 남기는 것으로 축소할지 결정 필요.
- **내 글 "수정" 기능 범위**: 현재 피드/Q&A 작성 화면은 신규 작성 전용이라 수정 모드가 없음. MY탭에서 "수정"까지 지원할지, 이번 범위는 "삭제"까지만 하고 수정은 다음 과제로 미룰지 확정 필요.
- **역할(로컬/관광객) 변경 가능 여부**: Q&A 배지·권한과 연결되는 값이라 신중해야 함 — 지금은 "수정 불가"로 가정.
- **회원 탈퇴 범위 포함 여부**: 공모전 데모 범위에서는 우선 로그아웃까지만 구현하고 탈퇴는 버튼만 두고 비활성 처리하는 것을 제안.
