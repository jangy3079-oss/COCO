# 스팟/피드 다국어 처리 — OpenAI API 연동 백엔드 수정 요청

스팟이랑 피드 다국어 처리를 OpenAI API(Chat Completions)로 하기로 해서, 백엔드에
필요한 수정사항 정리해서 보냅니다. 지금 코드 기준으로 어디가 비어있는지랑, 어떻게
채우면 좋을지 순서대로 적어놨어요. 급한 건 아니고 참고해서 진행 순서 맞춰주시면
될 것 같습니다.

## 0. 지금 상태 (확인차 정리)

- **스팟(`Spot`)**: `title_ko`/`title_en`/`title_ja` 컬럼은 이미 있는데, `SpotService.importFromTourApi()`
  주석에 "titleEn/titleJa는 번역이 붙을 때까지 null로 둔다"고 되어 있고 실제로 항상 null입니다.
  `description`(소개글)도 한국어 원문 한 컬럼뿐이라 영/일 버전이 아예 없어요.
- **피드(`FeedPost`, `FeedComment`)**: `description`/`content` 모두 언어 구분 컬럼이 없고,
  `FeedController`에도 `locale` 파라미터 자체가 없습니다. 즉 피드는 다국어 개념이 아직
  전혀 안 들어가 있는 상태예요.

## 1. 요청 A — 스팟 다국어 (title, description)

### 왜 import 시점에 "재작성 + 번역"을 같이 해서 저장하는 방식으로 가면 좋을지
스팟은 TourAPI/카카오 배치 import 때 한 번 생성되고 그 뒤로는 거의 안 바뀌는 데이터라,
`fetchOverview()`가 신규 스팟에 대해서만 1회 호출되는 것과 같은 패턴으로 번역도
**신규 스팟 저장 시점에 1회만 호출해서 컬럼에 박아두는 방식**을 제안합니다. 매 요청마다
OpenAI를 부르면 응답 느려지고 비용도 계속 나가니까, "쓰기 시점 1회 처리, 읽기는 DB에서"
가 맞는 것 같아요.

추가로, `fetchOverview()`가 가져오는 TourAPI 원문(`description`)은 공공데이터 특유의
딱딱한 문체라 그대로 쓰기보다 **한국어 원문 자체도 자연스러운 문체로 재작성**해서
저장하고, en/ja는 그 재작성본을 번역하는 방식으로 가려고 합니다. 프론트 스팟 상세
화면에 방금 "기본 3줄만 보여주고 구분선 아래 버튼으로 전체 펼쳐보기" UI를 붙였는데
(`spot_detail_screen.dart`의 `_ExpandableDescription`), TourAPI 원문은 앞부분이 밋밋해서
3줄 미리보기로는 매력이 안 살고, "역사"처럼 뒤에 이어지는 배경 설명도 문단 구분 없이
뭉텅이로 오는 경우가 많아요. 그래서 재작성 단계에서 "앞 2~3문장은 그 자체로 미리보기가
매력적이게, 뒤이어 역사/유래 등 배경 설명을 자연스러운 문단으로" 만들어달라고 프롬프트에
지시해서, 재작성된 한국어 버전을 `description`에 덮어쓰고 en/ja는 그 버전을 번역한
걸로 채우면 될 것 같습니다. (사실관계는 원문 그대로 유지, 문체/구성만 다듬는 정도로.)

### 필요한 변경
**(1) `Spot` 엔티티 — 컬럼 추가**
```java
@Column(name = "description_en", columnDefinition = "TEXT")
private String descriptionEn;

@Column(name = "description_ja", columnDefinition = "TEXT")
private String descriptionJa;
```
(`title_en`/`title_ja`는 이미 있어서 컬럼 추가 없이 값만 채우면 됨. `description`은
기존 컬럼을 그대로 쓰되, 값은 raw 원문이 아니라 재작성본으로 대체됨)

**(2) 신규 `TranslationService` (OpenAI API 래퍼)**
```java
@Service
@RequiredArgsConstructor
public class TranslationService {

    private final RestClient restClient = RestClient.create();

    @Value("${openai.api-key}")
    private String apiKey;

    @Value("${openai.model:gpt-4o-mini}")
    private String model;

    /**
     * title은 번역만, description(원문)은 "자연스러운 문체로 재작성 + en/ja 번역"까지
     * 한 번의 호출로 처리해 반환한다. 실패 시 null 필드로 채움(호출부에서 raw 원문 폴백).
     */
    public LocalizedContent rewriteAndTranslate(String titleKo, String rawDescriptionKo) {
        // POST https://api.openai.com/v1/chat/completions
        // 헤더: Authorization: Bearer {apiKey}
        // response_format: {"type": "json_object"} 로 지정해서 파싱 안정성 확보
        // 프롬프트 지시사항:
        //   - title: en/ja로 번역만 (재작성 X)
        //   - description: 먼저 한국어 원문을 자연스러운 에디토리얼 문체로 재작성
        //     (앞 2~3문장은 3줄 미리보기로도 매력적인 도입부, 이후 역사/유래 등은
        //     자연스러운 문단으로 이어지게 — 사실관계는 원문 그대로 유지)
        //   - 재작성된 한국어 버전을 기준으로 en/ja 번역본도 같이 생성
        //   - 응답은 JSON 한 덩어리로만:
        //     {"titleEn":"...","titleJa":"...",
        //      "descriptionKo":"...","descriptionEn":"...","descriptionJa":"..."}
        // 응답 파싱 실패/네트워크 실패 시 예외를 삼키고 null 반환 — 실패가
        // 스팟 저장 자체를 막으면 안 됨 (fetchOverview와 동일 원칙).
    }

    public record LocalizedContent(
            String titleEn, String titleJa,
            String descriptionKo, String descriptionEn, String descriptionJa
    ) {}
}
```
- 스팟 하나당 API 호출 1회로 title 번역 + description 재작성/번역을 한꺼번에 받도록
  프롬프트에서 요청하는 게 비용/속도 면에서 나을 것 같습니다.
- `description`이 없는 스팟(카카오 로컬 소스)은 재작성/번역 대상 자체가 없으니 title
  번역만 요청(또는 이 메서드 호출을 아예 건너뜀).

**(3) `SpotService.importFromTourApi()` / `importFromKakaoLocal()` 수정**
```java
String rawDescription = tourApiService.fetchOverview(c.tourApiId());
var localized = translationService.rewriteAndTranslate(c.title(), rawDescription);

Spot spot = Spot.builder()
        // ...기존 필드...
        .titleEn(localized != null ? localized.titleEn() : null)
        .titleJa(localized != null ? localized.titleJa() : null)
        // 재작성 성공 시 그 버전으로, 실패하면 raw 원문 그대로 폴백.
        .description(localized != null && localized.descriptionKo() != null
                ? localized.descriptionKo() : rawDescription)
        .descriptionEn(localized != null ? localized.descriptionEn() : null)
        .descriptionJa(localized != null ? localized.descriptionJa() : null)
        .build();
```
카카오 로컬 임포트에도 동일하게 title 번역만 추가(description 관련 필드는 항상 null).

**(4) `SpotService`의 `resolveTitle()` 옆에 `resolveDescription()` 추가**
지금 `toResponse()`가 `s.getDescription()`을 locale 상관없이 그대로 내려주고 있어서,
`resolveTitle()`과 같은 패턴으로 description도 locale 분기 + 한국어(재작성본) 폴백
처리 필요.
```java
private String resolveDescription(Spot s, String locale) {
    String desc = switch (locale == null ? "" : locale) {
        case "en" -> s.getDescriptionEn();
        case "ja" -> s.getDescriptionJa();
        default -> s.getDescription();
    };
    return desc != null ? desc : s.getDescription();
}
```
`toResponse()`에서 `.description(s.getDescription())` → `.description(resolveDescription(s, locale))`
로 교체.

### 참고 — 프론트 펼치기 UI와의 관계
`spot_detail_screen.dart`에 추가한 `_ExpandableDescription`은 `TextPainter`로 실제
3줄 초과 여부를 재서, 넘칠 때만 구분선+"전체보기" 버튼을 보여주는 방식이라 백엔드에서
description 길이를 신경 써서 조정할 필요는 없습니다(짧은 글은 버튼 자체가 안 뜸). 다만
재작성 프롬프트에서 "앞부분이 미리보기로 매력적이게"를 지시하는 건 이 UI가 3줄까지만
먼저 보여준다는 전제가 있어서 넣은 거라, 프론트 UI가 바뀌면 이 지시사항도 같이 재검토
필요합니다.

## 2. 요청 B — 피드 다국어 (게시글 description, 댓글 content)

### 피드는 스팟이랑 상황이 다름
피드는 사용자가 실시간으로 작성하는 UGC라 미리 채워둘 수 없고, **글/댓글 작성 시점에
1회 번역해서 같이 저장**하는 방식이 맞을 것 같습니다(다른 유저가 그 글을 볼 때마다
매번 번역 호출하면 너무 느리고 비쌈). 원문은 한국어로 작성된다고 가정하고 en/ja로만
번역하면 될 것 같은데, 혹시 외국어로 작성되는 케이스도 고려해야 하는지는 확인 부탁드려요.

### 필요한 변경
**(1) `FeedPost` 엔티티 — 컬럼 추가**
```java
@Column(name = "description_en", length = 500)
private String descriptionEn;

@Column(name = "description_ja", length = 500)
private String descriptionJa;
```

**(2) `FeedComment` 엔티티 — 컬럼 추가**
```java
@Column(name = "content_en", length = 300)
private String contentEn;

@Column(name = "content_ja", length = 300)
private String contentJa;
```

**(3) `FeedService.createPost()` / `createComment()`에서 번역 호출**
```java
var translation = translationService.translate(request.getDescription(), null);
// 게시글이라 title이 없으니 translate()를 게시글용으로 오버로드하거나
// title 파라미터에 description을 그대로 넣는 형태로 재사용 검토.

FeedPost saved = feedPostRepository.save(FeedPost.builder()
        // ...기존 필드...
        .descriptionEn(translation != null ? translation.titleEn() : null)
        .descriptionJa(translation != null ? translation.titleJa() : null)
        .build());
```
댓글도 동일 패턴.

**(4) `FeedController`에 `locale` 파라미터 추가**
지금 `GET /api/feed`, `GET /api/feed/{id}/comments`에는 `locale` 자체가 없어서 이 부분도
같이 추가돼야 합니다.
```java
@GetMapping
public List<FeedPostResponse> list(@RequestParam(defaultValue = "ko") String locale) {
    return feedService.listFeed(currentUserId(), locale);
}

@GetMapping("/{id}/comments")
public List<FeedCommentResponse> listComments(@PathVariable Long id,
                                               @RequestParam(defaultValue = "ko") String locale) {
    return feedService.listComments(id, locale);
}
```
`FeedService.listFeed()`/`listComments()`/`toResponse()`/`toCommentResponse()`에도 `locale`
파라미터를 받아서 스팟과 동일한 폴백 방식(en/ja 없으면 한국어 원문)으로 내려주면 될 것
같습니다.

### 응답 속도 관련해서 상의하고 싶은 부분
글/댓글 작성할 때마다 OpenAI 호출이 동기로 걸리면 작성 버튼 누르고 1~2초 정도
기다리는 게 생길 수 있어요. MVP는 동기 처리로 가고, 나중에 느리다는 피드백 나오면
번역만 비동기로 빼서(글은 먼저 저장하고 번역은 백그라운드에서 채워넣는 식) 개선하는
방향 어떻게 생각하시는지 의견 주시면 좋겠습니다.

## 3. 공통 설정

`application.yml`에 기존 `tour-api:`/`kakao:` 블록과 같은 패턴으로 추가:
```yaml
openai:
  api-key: ${OPENAI_API_KEY:}
  model: ${OPENAI_MODEL:gpt-4o-mini}
```
API 키는 `.env`/`.env.example`에도 `OPENAI_API_KEY` 항목 추가 필요합니다.

## 4. 실패 시 원칙

번역 API 호출이 실패해도(네트워크 오류, 응답 형식 이상 등) 스팟 저장/피드 글 작성
자체는 절대 막히면 안 됩니다 — `fetchOverview()`가 실패해도 스팟 저장은 계속 진행되는
것과 같은 원칙으로, `TranslationService`도 예외를 삼키고 null을 반환하도록 해주세요.
스팟 쪽은 재작성 실패 시 `description`에 raw 원문을 그대로 폴백(1-(3) 참고), en/ja가
null이면 프론트/응답 단에서 한국어 버전으로 폴백됩니다.

## 5. 변경 파일 체크리스트

| 파일 | 변경 내용 |
|---|---|
| `TranslationService.java` (신규) | OpenAI Chat Completions API 호출 — title 번역 + description 재작성/번역을 한 번에 |
| `Spot.java` | `description_en`/`description_ja` 컬럼 추가 (기존 `description`은 값을 재작성본으로 대체) |
| `FeedPost.java` | `description_en`/`description_ja` 컬럼 추가 |
| `FeedComment.java` | `content_en`/`content_ja` 컬럼 추가 |
| `SpotService.java` | import 시 재작성+번역 호출, `resolveDescription()` 추가 |
| `FeedService.java` | 글/댓글 작성 시 번역 호출, `listFeed`/`listComments`에 locale 파라미터 추가 |
| `FeedController.java` | `list`/`listComments`에 `locale` 쿼리 파라미터 추가 |
| `application.yml`, `.env.example` | `openai.api-key`, `openai.model` 추가 |
| `schema.sql` | 위 신규 컬럼들 반영 (참고 문서 용도) |

우선순위는 스팟(A)이 먼저인 것 같아요 — 수가 적고 import 배치 때 한 번만 돌면 되니까
구현/테스트가 간단하고, 피드(B)는 실시간 호출이라 응답 속도 이슈까지 같이 봐야 해서
좀 더 신경 쓸 부분이 많을 것 같습니다.
