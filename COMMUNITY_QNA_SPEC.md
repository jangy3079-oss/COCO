# 커뮤니티(Q&A) 탭 기능 명세서

범위: 로컬-관광객 실시간 Q&A만. (자유게시판/이벤트 등 추가 커뮤니티 기능은 이번 범위에서 제외 — 필요해지면 별도 명세로 추가)

## 1. 개요

기획 컨셉: "한국인 로컬이 외국인 관광객의 질문에 실시간으로 답변, 채택 기능 포함"

- 관광객이 궁금한 걸 질문으로 올리면, 로컬 주민이 답변한다.
- 질문 작성자는 마음에 드는 답변을 하나 채택할 수 있다 (네이버 지식인과 유사한 구조).
- 방향은 "관광객 질문 → 로컬 답변"이 기본 컨셉이지만, MVP에서는 질문/답변 작성 권한을 로컬/관광객 모두에게 열어둔다 (아래 3번 참고). 대신 답변자가 로컬 주민이면 답변 옆에 "로컬" 배지를 표시해 신뢰도를 구분한다.

## 2. 정보구조 (화면 3개)

1. **커뮤니티 목록** (`/qna`) — 질문 리스트
2. **질문 상세** (`/qna/post/:id`) — 질문 본문 + 답변 목록 + 답변 작성 + 채택
3. **질문 작성** (`/qna/compose`) — 제목/본문/장소 태그(선택) 입력

지도 탭·피드 탭과 동일하게 상세/작성 화면은 하단 탭 없는 전체화면으로, `app_router.dart`의 ShellRoute 바깥 최상위 라우트로 추가한다.

## 3. 사용자 역할 및 권한

| 액션 | 로컬 주민 | 관광객 |
|---|---|---|
| 질문 작성 | 가능 | 가능 |
| 답변 작성 | 가능 (배지 표시) | 가능 (배지 없음) |
| 답변 채택 | 본인이 쓴 질문에 한해 가능 | 본인이 쓴 질문에 한해 가능 |
| 질문/답변 신고 | 가능 | 가능 |

- 로그인하지 않은 상태에서는 목록/상세는 볼 수 있지만 질문·답변·채택·신고는 로그인 필요 (auth 흐름과 동일하게 로그인 화면으로 유도).
- 채택은 질문 작성자만, 질문 하나당 답변 1개만 채택 가능. 채택 후에도 다른 사용자가 답변을 계속 달 수는 있지만 재채택(채택 변경)은 MVP에서는 지원하지 않음 — 한번 채택하면 고정.

## 4. 핵심 기능 상세

### 4.1 커뮤니티 목록
- 정렬: 최신순 / 미답변 우선순(답변 0개인 질문을 위로) — 지도·피드 탭의 정렬 UI 패턴과 통일
- 필터: 전체 / 미답변 / 내 질문 (로그인 시)
- 카드에 표시: 제목, 본문 미리보기(1~2줄), 작성자 유형 배지(로컬/관광객), 답변 수, 채택 여부(✓ 아이콘), 작성 시각
- 무한스크롤 (피드 탭과 동일한 패턴 재사용)
- 우측 하단 FAB로 질문 작성 화면 진입 (피드 탭 글쓰기 FAB와 동일 패턴, 색상은 `CocoTheme.primary`)

### 4.2 질문 작성
- 입력 항목: 제목(필수), 본문(필수), 장소 태그(선택 — 지도 탭 스팟과 연결, `spots` 테이블 참조)
- 장소 태그를 넣으면 상세 화면에 "관련 스팟" 카드가 함께 노출되도록 — 지도 탭의 스팟 상세와 자연스럽게 연결
- 제출 시 목록 맨 위에 반영, 질문 상세로 이동

### 4.3 질문 상세 + 답변
- 질문 본문 전체 표시 (제목/본문/작성자/작성시각/장소 태그 카드)
- 답변 목록: 채택된 답변이 있으면 최상단 고정 노출(채택 배지 강조), 나머지는 최신순
- 답변 작성: 하단 고정 입력창 (피드 탭 댓글 입력 UI 재사용)
- 채택 버튼: 질문 작성자에게만 각 답변 옆에 노출. 채택하면 질문 카드에 "해결됨" 상태로 전환

### 4.4 실시간성 (MVP 범위 결정)
진짜 웹소켓 기반 실시간은 이번 범위에서 제외한다. 백엔드가 아직 기본 REST API도 없는 단계라 웹소켓까지 가면 일정 리스크가 큼.

MVP는 **폴링 기반 준실시간**으로 처리: 질문 상세 화면을 열어두고 있는 동안 일정 주기(예: 10~15초)로 답변 목록을 다시 조회해서 새 답변이 오면 화면에 반영. 진짜 실시간(웹소켓/SSE)은 이후 과제로 남긴다.

### 4.5 다국어 처리
- 질문/답변 본문 자체는 번역하지 않고 작성자가 입력한 언어 그대로 노출 (자동 번역 API 연동은 이번 범위 밖)
- UI 라벨(버튼, 안내 문구 등)만 `lib/l10n/app_{ko,en,ja}.arb` 기준 다국어 처리
- 대신 질문 작성 시 "이 질문은 [한국어/영어/일본어]로 작성돼요" 같은 안내를 보여줘서, 로컬 답변자가 어떤 언어로 답변할지 판단하도록 함 (자동 번역 없이도 최소한의 다국어 배려)

## 5. 화면별 UI 구성요소 (지도·피드 탭과 톤 통일)

| 요소 | 스타일 |
|---|---|
| 색상 | `CocoTheme.primary`(스카이블루) 포인트, 나머지는 지도/피드 탭과 동일한 컬러 시스템 |
| 카드 | 흰 배경, 옅은 하단 구분선 (피드 카드와 동일 톤) |
| 배지 | 로컬 배지 = 연하늘색 pill + `CocoTheme.primary` 텍스트 (COCO 추천 배지와 동일 스타일 재사용) |
| 빈 상태 / 무한스크롤 / 새로고침 | 피드 탭에서 만든 `_EmptyState`, `_ListFooter` 패턴 재사용 |

## 6. 데이터 모델 (DB 반영안)

기존 프로젝트 지침의 `qna_posts`, `qna_answers` 테이블에 다음 컬럼 구성을 제안 (snake_case, 외래키 인라인 `FOREIGN KEY` 컨벤션 준수):

```sql
CREATE TABLE qna_posts (
  id             BIGSERIAL PRIMARY KEY,
  user_id        BIGINT NOT NULL REFERENCES users(id),
  spot_id        BIGINT REFERENCES spots(id),        -- 장소 태그, nullable
  title          VARCHAR(200) NOT NULL,
  content        TEXT NOT NULL,
  locale         VARCHAR(5) NOT NULL,                 -- ko | en | ja, 작성 시 UI 언어 기준
  adopted_answer_id BIGINT,                           -- 채택된 답변 id, nullable
  created_at     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE qna_answers (
  id          BIGSERIAL PRIMARY KEY,
  post_id     BIGINT NOT NULL REFERENCES qna_posts(id),
  user_id     BIGINT NOT NULL REFERENCES users(id),
  content     TEXT NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT now()
);
```

- 답변 채택 여부는 `qna_answers`에 별도 컬럼을 두지 않고 `qna_posts.adopted_answer_id`로만 관리 (질문당 채택 1개 제약을 자연스럽게 강제).
- "로컬 배지"는 별도 컬럼 없이 답변 조회 시 `users.role`을 조인해서 프론트에 내려주면 됨.

## 7. API 엔드포인트 초안 (프론트 ↔ 백엔드)

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/api/qna/posts?filter=all\|unanswered\|mine&sort=latest\|unanswered_first&page=` | 질문 목록 |
| POST | `/api/qna/posts` | 질문 작성 `{ title, content, spotId?, locale }` |
| GET | `/api/qna/posts/{id}` | 질문 상세 (답변 목록 포함) |
| POST | `/api/qna/posts/{id}/answers` | 답변 작성 `{ content }` |
| POST | `/api/qna/posts/{id}/adopt` | 답변 채택 `{ answerId }` — 질문 작성자만 호출 가능, 서버에서 권한 검증 |
| POST | `/api/qna/posts/{id}/report`, `/api/qna/answers/{id}/report` | 신고 |

모든 쓰기 요청은 로그인 API 스펙과 동일하게 `Authorization: Bearer {accessToken}` 헤더 필요. 에러 응답 포맷도 `{ "message": "..." }`로 통일 ([[AUTH_API_SPEC.md]] 컨벤션과 동일).

## 8. 프론트 연결 지점

- `lib/presentation/screens/qna/qna_screen.dart` — 현재 `Text('Qna Screen')`만 있는 스텁 상태, 이 명세 기준으로 목록 화면 구현 예정
- 상세/작성 화면은 `lib/presentation/screens/qna/` 아래 신규 파일로 추가 (`qna_post_detail_screen.dart`, `qna_composer_screen.dart` — 피드 탭 파일 구조와 동일 네이밍 패턴)
- 목업 데이터 단계에서는 `feed_mock_data.dart`와 동일한 패턴으로 `qna_mock_data.dart`를 만들어 화면부터 먼저 구현 가능

## 9. 아직 안 정해진 것 (상의 필요)

- 답변 채택 후 "재채택(채택 변경)" 허용 여부 — 현재는 1회 고정으로 가정
- 신고 누적 시 자동 블라인드 처리할지, 운영자 수동 검토만 할지 (공모전 데모 범위에서는 우선 신고 접수 UI만 두고 실제 처리 로직은 생략 제안)
- 진짜 실시간(웹소켓/SSE) 전환 시점 — 백엔드 여유가 되면 데모 임팩트를 위해 상세 화면만이라도 웹소켓 적용 고려
- 자동 번역 연동 여부 — 넣는다면 별도 API 키/비용이 필요해서 공모전 예산·일정상 이번 범위에서는 제외 권장
