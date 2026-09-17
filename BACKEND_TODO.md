# 백엔드 필요 작업 정리 (코스 / 찜 / QnA / 프로필 / 스팟등록)

목업 데이터를 걷어내기 전에, 실제로 붙여야 하는 백엔드 작업을 기능별로 정리한 문서. 기존에
`MY_TAB_SPEC.md`, `COMMUNITY_QNA_SPEC.md`, `AUTH_API_SPEC.md`가 이미 있어서 그 내용을
기준으로 삼되, **실제로 구현된 엔티티가 스펙과 어긋난 부분**을 짚고, 스펙에 없던 스팟 등록
신청 기능은 이번에 새로 정리했다.

## 0. 현재 상태 요약

| 기능 | 프론트 | 백엔드 |
|---|---|---|
| 지도 스팟 조회/검색/필터 | 실 API 연동 완료 | ✅ 완료 (`SpotController`) |
| 피드(글/좋아요/댓글/이미지) | 실 API 연동 완료 | ✅ 완료 (`FeedController`) |
| 스팟 찜(좋아요) | 클라이언트 메모리만 (`savedSpotIds`) | `SpotLike` 엔티티만 존재, API 0개 |
| 코스(골목지도) | 클라이언트 메모리만 (`mockMyRoutes`) | `RouteMap`/`RouteMapSpot`/`Course`/`CourseSpot` 4개 엔티티 존재하나 **어디서도 참조 안 됨(죽은 스캐폴딩)**, API 0개 |
| QnA | 100% 목업 (`qnaMockPosts`) | 엔티티 존재하나 스펙과 필드 불일치, `QnaController`/`QnaService`는 `// TODO` 뿐인 완전 빈 스텁 |
| 마이페이지 프로필(닉네임 외) | 목업 (`mypage_mock_data.dart`) | GET/PATCH 없음, `bio`/`neighborhood` 컬럼 자체가 없음 |
| 스팟 등록 신청 | 100% 목업 (검색→제출 전체) | 제출/심사 엔드포인트 전무, 관련 스펙 문서도 없었음(이 문서에서 처음 정리) |

## 1. 진행 순서 제안

난이도·영향 범위 기준 추천 순서. 강제 아님, 팀 사정에 맞게 조정 가능.

1. **찜(스팟 좋아요)** — 엔티티가 이미 있어서 가장 빠름. Controller/Service만 새로 작성.
2. **코스(골목지도)** — 기존 스캐폴딩을 정리하는 결정만 하면(아래 3-2 참고) 나머지는 찜과 비슷한 난이도.
3. **QnA** — 엔티티 마이그레이션(컬럼 추가)이 먼저 필요해서 순서상 뒤로.
4. **마이페이지 프로필** — users 테이블 컬럼 추가 + 간단한 GET/PATCH.
5. **스팟 등록 신청** — 심사 워크플로우까지 가면 범위가 커지므로, 제출/상태조회만 먼저 하고 심사는 후순위로 미루는 걸 제안.

## 2. 작업별 상세

### 2-1. 스팟 찜(좋아요) API

`SpotLike`(user_id, spot_id, created_at) 엔티티·리포지토리는 이미 구현돼 있고 필드도 충분함.
Controller/Service만 새로 작성하면 됨.

- `POST /api/spot/{id}/like` — 토글 (이미 찜했으면 해제, 아니면 추가)
- `GET /api/spot/liked` — 내가 찜한 스팟 목록

### 2-2. 코스(골목지도) API

**먼저 결정할 것**: 현재 `RouteMap`→`Course`(2단계 계층, 엔티티 4개)가 이미 스캐폴딩돼
있지만, 코드베이스 어디서도(Service/Controller/DTO) 참조되지 않는 죽은 코드다. 게다가
`MY_TAB_SPEC.md` 6번이 이미 제안했던 구조는 이 4개짜리 계층이 아니라 훨씬 단순한
`routes`/`route_stops` 2테이블이고, 실제 프론트의 `MockRoute`(이름 + 정렬된 스팟 리스트
하나, wrapping "route map" 레이어 없음)도 이 단순 구조와 정확히 일치한다.

추천: `RouteMap`을 "코스" 자체로 재활용(테이블명은 유지해도 무방), `RouteMapSpot`을
스팟 순서 목록으로 재활용하고, `Course`/`CourseSpot`은 사용하지 않고 남겨두거나 정리.
`RouteMap`에 컬럼 추가 필요:

```sql
ALTER TABLE route_maps ADD COLUMN is_draft BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE route_likes (
  route_like_id BIGSERIAL PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(user_id),
  route_map_id  BIGINT NOT NULL REFERENCES route_maps(route_map_id),
  created_at    TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (user_id, route_map_id)
);

CREATE TABLE route_saves (
  route_save_id BIGSERIAL PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(user_id),
  route_map_id  BIGINT NOT NULL REFERENCES route_maps(route_map_id),
  created_at    TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (user_id, route_map_id)
);
```

엔드포인트:

- `POST /api/routes` — 코스 생성 `{ name, spotIds: [...], visibility, isDraft? }`
- `GET /api/routes/mine` — 내가 만든 코스 목록
- `GET /api/routes/{id}` — 상세 (정렬된 스팟 목록 포함)
- `PUT /api/routes/{id}` — 이름/스팟 순서/공개범위 수정
- `DELETE /api/routes/{id}`
- `POST /api/routes/{id}/like`, `POST /api/routes/{id}/save` — 토글

### 2-3. QnA API — `COMMUNITY_QNA_SPEC.md` 기준

**엔티티부터 스펙에 맞춰야 함.** 현재 `QnaPost`는 `question`(단일 500자) + `locale`만
있고, 스펙 6번이 요구하는 `title`, `content`(본문 분리), `spot_id`(장소 태그, nullable),
`adopted_answer_id`(채택 답변, nullable)가 없다. 마이그레이션 먼저 필요.

`QnaController`/`QnaService`는 지금 `// TODO` 뿐인 완전 빈 스텁이라, 스펙 7번 표의
5개 엔드포인트를 전부 새로 작성해야 한다:

- `GET /api/qna/posts?filter=all|unanswered|mine&sort=latest|unanswered_first`
- `POST /api/qna/posts` `{ title, content, spotId?, locale }`
- `GET /api/qna/posts/{id}`
- `POST /api/qna/posts/{id}/answers` `{ content }`
- `POST /api/qna/posts/{id}/adopt` `{ answerId }` (질문 작성자만)

프론트는 `QnaRepository` 자체가 없는 상태라, 백엔드 완료 후 프론트 레포지토리부터 새로
만들어야 한다(피드 때 `FeedRepository` 만들었던 것과 동일 패턴).

### 2-4. 마이페이지 프로필 API — `MY_TAB_SPEC.md` 기준

`users` 테이블에 컬럼 추가:

```sql
ALTER TABLE users ADD COLUMN bio VARCHAR(60);
ALTER TABLE users ADD COLUMN profile_image_url VARCHAR(255);
```

(`neighborhood`는 이전 답변에서 설명한 것처럼 구조화된 컬럼이 없어서 별도 결정 필요 —
당장은 빼고 진행해도 무방)

- `GET /api/users/me` — 닉네임/역할/이메일/자기소개/프로필사진
- `PATCH /api/users/me` — `{ nickname?, bio?, profileImageUrl? }`

참고: `my_posts_screen.dart`가 지금 `myNickname` 문자열 비교로 "내가 쓴 글"을 거르고
있는데, 이 API가 붙으면 실제 로그인 사용자 id 기준 비교로 바꿔야 한다.

### 2-5. 스팟 등록 신청(심사) API — 기존 스펙 문서 없음, 신규

어느 문서에도 다뤄진 적 없는 영역. 최소로 필요한 것:

```sql
CREATE TABLE spot_registrations (
  spot_registration_id BIGSERIAL PRIMARY KEY,
  user_id     BIGINT NOT NULL REFERENCES users(user_id),
  name        VARCHAR(100) NOT NULL,
  category    VARCHAR(20) NOT NULL,
  address     VARCHAR(255) NOT NULL,
  lat         DOUBLE PRECISION NOT NULL,
  lng         DOUBLE PRECISION NOT NULL,
  description TEXT,
  status      VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING | APPROVED | REJECTED
  created_at  TIMESTAMP NOT NULL DEFAULT now()
);
```

- `POST /api/spot/register` — 신청 제출
- `GET /api/spot/register/mine` — 내 신청 상태 조회

심사(승인/반려) 관리자 화면은 이번 범위 밖으로 미루는 걸 제안 — 공모전 데모 수준에서는
"심사 대기" 상태만 보여줘도 충분하고, 실제 승인 로직·관리자 UI는 후순위 과제로 남겨도 됨.

## 3. 기존 컨벤션 (새 Controller 작성 시 맞출 것)

- 인증: JWT 필터가 `SecurityContext`에 `userId`를 심어둠 → `currentUserId()` 헬퍼로 꺼내 씀.
  비로그인 시 401 + `{message: ...}`.
- 클래스: `@RestController @RequestMapping("/api/xxx") @RequiredArgsConstructor`
- 응답: `ResponseEntity<?>` 또는 단순 `List<DTO>`(목록류), DTO는 `@Getter @Builder`
- 에러: `IllegalArgumentException` catch 후 400 + `{message: ...}` (`AUTH_API_SPEC.md` 컨벤션과 동일)
- 예시 (`FeedController`):
  ```java
  @PostMapping("/{id}/like")
  public ResponseEntity<?> toggleLike(@PathVariable Long id) { ... }
  ```

## 4. 참고

이 문서는 스펙/작업 목록 정리까지만 다룬다. 실제 Java 코드(엔티티 마이그레이션,
Controller/Service 구현)가 필요하면 항목별로 말씀해 주시면 이어서 작성 가능.
