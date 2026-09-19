# 마이페이지 "좋아요한 피드 · 저장한 피드" — 백엔드 수정 요청

목업 데이터 제거 작업하다가 `my_saved_screen.dart`(마이페이지 "저장 · 좋아요" 화면)의
"좋아요한 피드"/"저장한 피드" 두 탭이 아직 `mockFeedItems`(하드코딩된 데모 피드
13개)를 그대로 필터링해서 보여주고 있던 걸 발견했어요. 프론트는 제가 오늘 바로
고쳐놨는데, 그 과정에서 백엔드가 필요한 부분이 나뉘어서 정리해서 보냅니다.

## 0. 지금 상태 (프론트 수정 후 기준)

- **찜한 스팟(spots)/저장한 코스(routes) 탭**: 이미 실제 API(`GET /api/spot/liked`,
  코스 저장 토글) 연동 완료 — 이번 건과 무관, 참고용으로만 언급.
- **좋아요한 피드(likedFeed) 탭**: `mockFeedItems.where((f) => f.liked)` 대신
  `GET /api/feed`(feed_screen.dart와 동일하게 `feedItemFromPost`로 변환) 결과를
  `liked == true`로 필터링하도록 고쳤습니다. `FeedPostResponse.liked`가 이미
  로그인 유저 기준으로 내려오고 있어서 지금 당장은 동작은 해요. 다만 `GET
  /api/feed`가 최신 50개까지만 내려주는 캡(`findTop50ByOrderByCreatedAtDesc`)이
  있어서, 50개 밖으로 밀린 오래된 글에 좋아요가 남아있으면 마이페이지엔 안 보이는
  한계가 있습니다 — 아래 요청 A 참고.
- **저장한 피드(savedFeed) 탭**: 백엔드에 피드 "저장(북마크)" 개념 자체가 아예
  없습니다(`feed_post_likes` 테이블만 있고 save/bookmark 테이블 없음). 확인해보니
  프론트의 북마크 아이콘도 3군데(피드 카드, 골목지도 랭킹 리스트, 피드 상세 화면)
  모두 `item.saved = !item.saved`로 로컬 상태만 토글하고 서버엔 전혀 반영이 안
  되고 있었어요 — 그러니까 "저장" 기능 자체가 프론트 전체에서 사실상 가짜였던
  셈입니다. 일단 마이페이지의 저장한 피드 탭은 있지도 않은 기능을 로컬 목업으로
  채워 보여주는 것보다 정직하게 빈 목록으로 고쳐뒀습니다 — 아래 요청 B가 처리되면
  이 탭과 나머지 3군데 UI를 전부 실제 API로 마저 연결할게요.

## 1. 요청 A — `GET /api/feed/liked` (좋아요한 피드 전용 엔드포인트)

### 왜 필요한지
`GET /api/spot/liked`(찜한 스팟 전체 — 캡 없음)와 같은 이유로, "좋아요한 피드"도
최신 50개 캡에 걸리지 않는 전용 목록 엔드포인트가 있어야 정확합니다. 지금처럼
`GET /api/feed` 결과를 프론트에서 필터링하는 방식은 캡 때문에 오래된 좋아요가
누락될 수 있는 임시방편이에요.

### 필요한 변경

**(1) `FeedPostLikeRepository` — `findPostsByUserId` 추가**
(`SpotLikeRepository.findSpotsByUserId`와 완전히 동일한 패턴)
```java
@Query("SELECT l.feedPost FROM FeedPostLike l WHERE l.user.id = :userId ORDER BY l.createdAt DESC")
List<FeedPost> findPostsByUserId(@Param("userId") Long userId);
```

**(2) `FeedService` — `getLikedFeed(userId)` 추가**
```java
/** 마이페이지 "좋아요한 피드" — 캡 없이 전체. 여기 있다는 것 자체가 좋아요를
 *  눌렀다는 뜻이라 liked는 항상 true로 채운다. trending 계산은 listFeed와 동일. */
public List<FeedPostResponse> getLikedFeed(Long userId) {
    List<FeedPost> posts = feedPostLikeRepository.findPostsByUserId(userId);
    if (posts.isEmpty()) return List.of();

    List<Long> spotIds = posts.stream()
            .filter(p -> p.getSpot() != null)
            .map(p -> p.getSpot().getId())
            .distinct()
            .toList();
    Map<Long, Boolean> trendingBySpotId = new HashMap<>();
    if (!spotIds.isEmpty()) {
        for (Object[] row : feedPostRepository.aggregateEngagementBySpotIds(spotIds)) {
            Long spotId = (Long) row[0];
            trendingBySpotId.put(spotId, SpotService.isTrending(((Number) row[1]).longValue(), ((Number) row[2]).longValue()));
        }
    }
    return posts.stream()
            .map(p -> toResponse(p, p.getSpot() != null && Boolean.TRUE.equals(trendingBySpotId.get(p.getSpot().getId())), true))
            .toList();
}
```
(trending 집계 로직이 `listFeed()`와 완전히 겹치니, 원하시면 공통 private
메서드로 뽑아써도 좋을 것 같아요 — 지금은 기존 스타일 그대로 붙여넣는 형태로만
적어놨습니다.)

**(3) `FeedController`**
```java
@GetMapping("/liked")
public ResponseEntity<?> getLikedFeed() {
    Long userId = currentUserId();
    if (userId == null) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(new ErrorResponse("로그인이 필요합니다."));
    }
    return ResponseEntity.ok(feedService.getLikedFeed(userId));
}
```

**(4) 프론트 반영 계획** (백엔드 반영되면 제가 바로 처리할게요)
`FeedRepository.fetchLikedFeed()`를 `fetchLikedSpots()`와 동일한 모양으로
추가하고, `my_saved_screen.dart`의 `_loadFeed()`가 지금처럼 `fetchFeed()`를
필터링하는 대신 이 엔드포인트를 직접 호출하도록 교체하겠습니다.

## 2. 요청 B — 피드 저장(북마크) 기능 신설

### 왜 필요한지
찜(스팟)·좋아요(피드)는 이미 `*_likes` 테이블 + 토글 API로 실제 동작하는데,
피드 "저장"만 테이블도 API도 없이 프론트 로컬 state로만 흉내 내고 있었어요.
앱을 새로고침하면 초기화되고, 다른 기기/세션에서는 아예 안 보이는 상태라
사실상 없는 기능이나 마찬가지입니다. 기존 좋아요 패턴(`FeedPostLike`/
`feedPostLikeRepository.toggleLike`/`spot_likes`↔`SpotLike`)을 그대로 복제하면
되는 구조라 큰 설계 고민은 필요 없을 것 같고, 아래처럼 정리해봤습니다.

### 필요한 변경

**(1) `schema.sql` — `feed_post_saves` 테이블 신설**
(`feed_post_likes`와 완전히 동일한 패턴)
```sql
CREATE TABLE feed_post_saves (
    feed_post_save_id BIGSERIAL NOT NULL,
    user_id           BIGINT,
    feed_post_id      BIGINT,
    created_at        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (feed_post_save_id),
    CONSTRAINT fk_fsave_user FOREIGN KEY (user_id)      REFERENCES users(user_id)           ON DELETE CASCADE,
    CONSTRAINT fk_fsave_post FOREIGN KEY (feed_post_id) REFERENCES feed_posts(feed_post_id) ON DELETE CASCADE,
    CONSTRAINT uq_feed_save  UNIQUE (user_id, feed_post_id)
);
CREATE INDEX idx_fsave_user ON feed_post_saves (user_id);
```
`feed_posts` 테이블에도 `like_count`와 나란히 `save_count` 캐시 컬럼 추가:
```sql
ALTER TABLE feed_posts ADD COLUMN save_count INT DEFAULT 0;
-- (또는 CREATE TABLE feed_posts 블록 안에 like_count 바로 아래 save_count 줄 추가)
```

**(2) `FeedPostSave` 엔티티 (신규)** — `FeedPostLike.java`를 그대로 복제
```java
@Entity
@Table(name = "feed_post_saves")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FeedPostSave {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "feed_post_save_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "feed_post_id", nullable = false)
    private FeedPost feedPost;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public FeedPostSave(User user, FeedPost feedPost) {
        this.user = user;
        this.feedPost = feedPost;
    }
}
```

**(3) `FeedPostSaveRepository` (신규)** — `FeedPostLikeRepository`와 동일 패턴
```java
public interface FeedPostSaveRepository extends JpaRepository<FeedPostSave, Long> {
    Optional<FeedPostSave> findByUser_IdAndFeedPost_Id(Long userId, Long feedPostId);

    @Query("SELECT s.feedPost.id FROM FeedPostSave s WHERE s.user.id = :userId AND s.feedPost.id IN :postIds")
    List<Long> findSavedPostIds(@Param("userId") Long userId, @Param("postIds") List<Long> postIds);

    @Query("SELECT s.feedPost FROM FeedPostSave s WHERE s.user.id = :userId ORDER BY s.createdAt DESC")
    List<FeedPost> findPostsByUserId(@Param("userId") Long userId);
}
```

**(4) `FeedPost` 엔티티 — `saveCount` 필드 + 증감 메서드**
(`likeCount`/`increaseLike`/`decreaseLike`와 완전히 동일한 패턴)
```java
@Column(name = "save_count", nullable = false)
private Integer saveCount;

// 빌더 생성자 안, likeCount 초기화 옆에 추가
this.saveCount = saveCount != null ? saveCount : 0;

public void increaseSave() { this.saveCount++; }
public void decreaseSave() { if (this.saveCount > 0) this.saveCount--; }
```

**(5) `FeedPostResponse` — `saved`/`saveCount` 필드 추가**
```java
private boolean saved;
private int saveCount;
```

**(6) `FeedService`**
- `toggleSave(userId, postId)` — `toggleLike`를 그대로 복제(`increaseSave`/
  `decreaseSave` 호출만 다름), `LikeToggleResponse`와 형태가 같은
  `SaveToggleResponse{saved, saveCount}` 신규 또는 기존 `LikeToggleResponse`를
  `{liked/saved, count}`처럼 필드명을 일반화해서 재사용 — 편하신 쪽으로 결정해주세요.
- `getSavedFeed(userId)` — 요청 A의 `getLikedFeed`와 완전히 동일한 패턴(저장한
  게시물 전체, 캡 없음).
- `listFeed()`/`toResponse()` — `liked` 배치 조회 옆에 `saved` 배치 조회도
  추가해서 `FeedPostResponse.saved`/`saveCount`를 같이 채워줘야 함(지금 `liked`
  채우는 자리에 `saved`도 나란히).

**(7) `FeedController`**
```java
@PostMapping("/{id}/save")
public ResponseEntity<?> toggleSave(@PathVariable Long id) { ... } // toggleLike와 동일 형태

@GetMapping("/saved")
public ResponseEntity<?> getSavedFeed() { ... } // getLikedFeed(요청 A)와 동일 형태
```

**(8) 이 기능을 기다리는 프론트 4곳** (전부 지금은 로컬 전용 토글이라 새로고침하면
초기화됨 — 이번 요청엔 프론트 변경을 포함 안 시켰고, 백엔드 반영되면 이어서
같이 정리하겠습니다)
- `feed_screen.dart` 피드 카드 북마크 아이콘 (`onToggleSave: (item) =>
  setState(() => item.saved = !item.saved)`)
- `feed_screen.dart` 골목지도 랭킹 리스트의 저장 버튼(`_RouteRankRow`)
- `feed_post_detail_screen.dart` 상세 화면 북마크 아이콘
- `my_saved_screen.dart` "저장한 피드" 탭 (지금은 위에서 설명한 이유로 빈 목록
  고정 — `// TODO(backend): FEED_SAVE_REQUEST.md 참고` 주석 달아뒀습니다)

## 3. 참고 — 이번에 백엔드 변경 없이 프론트만 고친 부분 (확인차 정리)

목업 제거하다가 같이 발견된 다른 두 군데는 백엔드가 이미 다 갖추고 있어서
프론트만 고쳤습니다. 혹시 몰라 정리해서 남겨요.

- **QnA 질문 작성 스팟 태그** (`qna_composer_screen.dart`): 고정 데모 스팟
  5개(`mockSpots`)를 칩으로 보여주고 실제로는 `spotId`를 안 보내던 부분을,
  `feed_composer_screen.dart`와 동일한 실검색(`GET /api/spot/search`) 패턴으로
  교체했습니다. `QnaPostRequest.spotId`/`QnaPost.spot`/
  `QnaPostResponse.spotId·spotName`이 이미 전부 구현돼 있어서 백엔드 변경은
  없었습니다.
- **스팟 상세 "이런 스팟은 어때요"** (`spot_detail_screen.dart`): 실제 DB
  스팟일 때는 이미 `GET /api/spot`(뷰포트 재조회)로 진짜 연관 스팟을 보여주고
  있었는데, 고정 데모 스팟(`spot-1` 등)일 때만 `mockSpots` 중에서 자기 자신만
  빼고 채우던 부분이 남아있었어요. 데모 스팟도 실제 부산 좌표(lat/lng)를 갖고
  있어서 동일한 방식으로 조회하도록 통일했습니다. 이것도 백엔드 변경 없음 —
  다만 지금 방식이 "좌표 ±0.01도 bbox 재조회"로 근사한 것뿐이라, 나중에 진짜
  반경 기반 정렬(거리순)이 필요해지면 그때 별도 엔드포인트를 요청드릴게요.

## 4. 변경 파일 체크리스트

| 파일 | 변경 내용 |
|---|---|
| `FeedPostLikeRepository.java` | `findPostsByUserId` 추가 (요청 A) |
| `FeedPostSave.java` (신규) | `feed_post_saves` 엔티티 (요청 B) |
| `FeedPostSaveRepository.java` (신규) | `findByUser_IdAndFeedPost_Id`/`findSavedPostIds`/`findPostsByUserId` |
| `FeedPost.java` | `saveCount` 필드 + `increaseSave`/`decreaseSave` |
| `FeedPostResponse.java` | `saved`, `saveCount` 필드 추가 |
| `FeedService.java` | `getLikedFeed`(A), `toggleSave`/`getSavedFeed`(B), `listFeed`/`toResponse`에 `saved` 반영 |
| `FeedController.java` | `GET /api/feed/liked`(A), `POST /api/feed/{id}/save` + `GET /api/feed/saved`(B) |
| `schema.sql` | `feed_posts.save_count` 컬럼, `feed_post_saves` 테이블 + 인덱스 |

우선순위는 **요청 A(좋아요한 피드 캡 문제)가 먼저**인 것 같아요 — 기존
`SpotLikeRepository`/`getLikedSpots` 패턴을 그대로 복사하는 수준이라 가볍고
빨리 끝날 것 같습니다. **요청 B(저장 기능 신설)**는 테이블이 새로 생기고
프론트도 4곳을 같이 손봐야 해서 조금 더 걸릴 것 같아요 — 우선순위 조정 필요하면
말씀해주세요.
