# 코스(routes) + 커뮤니티(Q&A) 목업 → 백엔드 전환 요구사항

이 문서는 코드를 직접 건드리지 않고, "코스"(골목지도)와 "커뮤니티(Q&A)" 두 기능이 지금 프론트 목업 데이터로만 동작하는 상태를 실제 백엔드로 연동하기 위해 **필요한 수정사항만** 정리한 것이다. 기존 `MY_TAB_SPEC.md`, `COMMUNITY_QNA_SPEC.md`를 베이스로, 그 문서 작성 이후 프론트가 더 진행되면서 생긴 차이(주로 코스 쪽)를 반영해 갱신했다.

---

## 1. 코스(routes) — 신규 기능, 백엔드 테이블 자체가 없음

### 1.1 왜 필요한가
`coco_frontend/lib/presentation/screens/map/map_mock_data.dart`의 `MockRoute`/`mockMyRoutes`가 "코스"의 유일한 데이터 소스다. 지도 탭 "코스 저장하기", 마이탭 "내가 만든 코스", 코스 상세/미리보기, 피드에 코스 공유(`feed_route_compose_screen.dart`)까지 전부 이 메모리상 리스트 하나에 의존한다 — 앱을 새로고침하면 사라진다.

프로젝트 지침의 DB 테이블 목록(`users, spots, qna_posts, qna_answers, feed_posts, feed_comments, spot_likes, feed_post_likes`)에는 코스 관련 테이블이 아예 없다. `MY_TAB_SPEC.md`가 초안 스키마를 제안했지만, 그 이후 프론트에 `isPublic`(전체공개/나만보기), `isDraft`(작성중), `likes`/`saves`/`shares` 카운트가 추가돼서 스키마를 갱신해야 한다.

### 1.2 현재 프론트 데이터 모양 (그대로 백엔드가 채워줘야 하는 필드)

```dart
class MockRoute {
  String id;
  String name;
  List<MockSpot> stops;   // 순서가 있는 스팟 리스트
  bool isPublic;          // true: 전체 공유, false: 나만 보기
  bool isDraft;           // true: 스팟만 담고 아직 이름 등 완성 안 한 "작성 중" 코스
  int likes;
  int saves;
  int shares;
}
```

- 생성/수정은 `route_builder_screen.dart`에서 하나의 화면으로 처리(신규 생성과 기존 코스 편집이 같은 화면) — 편집 시 `isPublic`/`likes`/`saves`/`shares`는 기존 값을 유지하고 `name`/`stops`만 갱신.
- 피드에 코스를 공유하면(`feed_route_compose_screen.dart`) 생성되는 피드 게시물이 원본 코스의 `routeId`를 들고 있어야, 피드 상세에서 "코스 상세 보기"로 다시 코스 화면으로 돌아올 수 있다 (task #84).

### 1.3 제안 스키마 (snake_case, 외래키 인라인 `FOREIGN KEY` 컨벤션)

```sql
CREATE TABLE routes (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users(id),
  name       VARCHAR(100) NOT NULL,
  is_public  BOOLEAN NOT NULL DEFAULT false,
  is_draft   BOOLEAN NOT NULL DEFAULT false,
  share_count INT NOT NULL DEFAULT 0,   -- 공유는 취소 개념이 없어서 카운터 컬럼으로 충분
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE route_stops (
  id         BIGSERIAL PRIMARY KEY,
  route_id   BIGINT NOT NULL REFERENCES routes(id),
  spot_id    BIGINT NOT NULL REFERENCES spots(id),
  stop_order INT NOT NULL
);

-- likes/saves는 spot_likes·feed_post_likes와 동일한 패턴(관계 테이블 + COUNT)으로 통일.
-- "내가 이미 좋아요/찜 눌렀는지" 프론트에서 판정하려면 이 방식이 카운터 컬럼보다 낫다.
CREATE TABLE route_likes (
  id       BIGSERIAL PRIMARY KEY,
  user_id  BIGINT NOT NULL REFERENCES users(id),
  route_id BIGINT NOT NULL REFERENCES routes(id),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (user_id, route_id)
);

CREATE TABLE route_saves (
  id       BIGSERIAL PRIMARY KEY,
  user_id  BIGINT NOT NULL REFERENCES users(id),
  route_id BIGINT NOT NULL REFERENCES routes(id),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (user_id, route_id)
);

-- 피드에서 코스를 공유했을 때, 그 피드 게시물이 원본 코스를 가리키게 하는 FK.
-- nullable (일반 피드 게시물은 코스와 무관).
ALTER TABLE feed_posts ADD COLUMN route_id BIGINT REFERENCES routes(id);
```

### 1.4 API 엔드포인트 초안

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/api/routes?owner=me\|public` | 코스 목록 (마이탭 "내가 만든 코스" / 공개 코스 랭킹용) |
| GET | `/api/routes/{id}` | 코스 상세 (stops 포함, 순서대로) |
| POST | `/api/routes` | 코스 생성 `{ name, stops: [spotId, ...], isPublic, isDraft }` |
| PUT | `/api/routes/{id}` | 코스 수정 `{ name?, stops?, isPublic? }` — 본인 코스만 |
| DELETE | `/api/routes/{id}` | 코스 삭제 — 본인 코스만 |
| POST/DELETE | `/api/routes/{id}/like` | 좋아요 토글 |
| POST/DELETE | `/api/routes/{id}/save` | 저장(찜) 토글 |
| POST | `/api/routes/{id}/share` | 공유 카운트만 +1 (피드 공유 화면 진입 시 호출) |

응답 DTO는 최소한 `id, name, stops:[{spotId, order, ...spot 요약}], isPublic, isDraft, likes, saves, shares, likedByMe, savedByMe`를 포함해야 프론트가 지금 화면(좋아요/찜 버튼 하이라이트 포함)을 그대로 채울 수 있다.

모든 쓰기 요청은 `Authorization: Bearer {accessToken}` 헤더 필요, 에러 응답은 `{ "message": "..." }` 포맷 (`AUTH_API_SPEC.md` 컨벤션과 동일).

---

## 2. 커뮤니티(Q&A) — 테이블은 이미 있음, API/서비스 레이어가 없음

### 2.1 현재 상태
`qna_posts`, `qna_answers`는 프로젝트 DB 테이블 목록에 이미 있다 — 즉 백엔드팀이 스키마 자체는 이미 알고 있거나 만들어뒀을 가능성이 높다. 다만 프론트(`qna_screen.dart`, `qna_post_detail_screen.dart`, `qna_composer_screen.dart`)는 지금 전부 `qna_mock_data.dart`의 메모리 리스트만 쓰고 있고, 실제 `SpotController`/`FeedController`처럼 이 둘을 읽고 쓰는 `QnaController`/`QnaService`/`QnaRepository`가 아직 백엔드에 없다(피드는 이미 있음 — task #106).

`COMMUNITY_QNA_SPEC.md`의 6~7번(스키마/API 초안)이 이미 상세하게 나와 있고 지금 프론트 목업 모양과도 일치한다 — 그대로 구현 가능한 상태다. 아래는 그 문서의 핵심을 바로 실행 가능한 체크리스트로 압축한 것.

### 2.2 필요한 작업 (체크리스트)

- [ ] `QnaPost`/`QnaAnswer` JPA 엔티티 추가 (`qna_posts`/`qna_answers` 테이블, `COMMUNITY_QNA_SPEC.md` §6 스키마 그대로)
- [ ] `QnaController` — 아래 5개 엔드포인트
  - `GET /api/qna/posts?filter=all|unanswered|mine&sort=latest|unanswered_first`
  - `POST /api/qna/posts` `{ title, content, spotId?, locale }`
  - `GET /api/qna/posts/{id}` (답변 목록 포함)
  - `POST /api/qna/posts/{id}/answers` `{ content }`
  - `POST /api/qna/posts/{id}/adopt` `{ answerId }` — 질문 작성자 본인만 (서버 검증 필수)
- [ ] 답변 조회 시 `users.role`을 조인해서 응답에 `isLocal`(로컬 배지용) 포함
- [ ] 채택은 `qna_posts.adopted_answer_id` 컬럼으로만 관리, 1회 고정(재채택 미지원 — `COMMUNITY_QNA_SPEC.md` §9)
- [ ] 프론트 `QnaRepository`(신규) 작성 후 `qna_mock_data.dart` 참조를 실제 API 호출로 교체 — 이건 "백엔드 API가 준비된 뒤" 프론트에서 별도로 진행

### 2.3 라우트 실시간성
진짜 웹소켓은 이번 범위 제외, 질문 상세 화면에서 10~15초 폴링으로 답변 목록만 재조회하는 방식으로 충분 (`COMMUNITY_QNA_SPEC.md` §4.4).

---

## 3. 작업 순서 제안

1. **Q&A 먼저** — 테이블이 이미 있고 스펙도 확정돼 있어서 가장 빨리 끝낼 수 있음 (컨트롤러/서비스만 추가하면 됨).
2. **코스** — 신규 테이블 4개(`routes`, `route_stops`, `route_likes`, `route_saves`) + `feed_posts.route_id` 컬럼 추가부터 시작. 코스는 마이탭·지도탭·피드탭 세 군데에서 참조하므로 스키마 확정을 먼저 하고 진행하는 게 안전.

두 작업 모두 백엔드 API가 준비된 뒤에 프론트의 `qna_mock_data.dart`/`map_mock_data.dart`(코스 부분) 참조를 리포지토리 호출로 바꾸는 프론트 작업이 별도로 필요하다 — 이 문서는 백엔드 쪽 요구사항까지만 다룬다.
