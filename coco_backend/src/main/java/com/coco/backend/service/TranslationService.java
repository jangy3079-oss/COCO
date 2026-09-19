package com.coco.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * OpenAI Chat Completions API 래퍼 — 스팟/피드 콘텐츠 다국어 처리 전용.
 * TourApiService/KakaoLocalService와 마찬가지로 RestClient.Builder 빈이 자동 등록되지
 * 않아 직접 생성해서 쓴다.
 *
 * 두 메서드(rewriteAndTranslate, translate) 모두 실패해도 예외를 절대 밖으로 던지지 않고
 * null만 반환한다 — 번역 실패가 스팟 저장/피드 글 작성 자체를 막으면 안 되기 때문이다
 * (TourApiService.fetchOverview()와 동일한 원칙). 둘 다 콘텐츠가 "생성되는 시점"(스팟
 * import, 피드 글/댓글 작성)에 딱 1회만 호출되고, 읽을 때마다 다시 호출하지 않는다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TranslationService {

    private final RestClient restClient = RestClient.create();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${openai.api-key}")
    private String apiKey;

    @Value("${openai.model:gpt-4o-mini}")
    private String model;

    private static final String CHAT_COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions";

    /**
     * 스팟 title/description 전용. 원문은 항상 한국어(TourAPI/팀이 등록)라고 가정하고
     * title은 번역만, description은 재작성 후 번역까지 한 번의 호출로 처리한다.
     * SpotService.importFromTourApi()/importFromKakaoLocal()에서 신규 스팟에만 호출된다.
     */
    public LocalizedContent rewriteAndTranslate(String titleKo, String rawDescriptionKo) {
        String systemPrompt = """
                너는 관광 콘텐츠 다국어 에디터다. 아래 지시를 따라 JSON 하나만 응답해라.
                - title은 주어진 한국어 제목을 영어(titleEn)와 일본어(titleJa)로 번역만 해라(재작성 금지).
                - descriptionKo가 비어 있으면 descriptionKo/descriptionEn/descriptionJa는 전부 null로 응답해라.
                - descriptionKo가 있으면: 먼저 한국어 원문을 자연스러운 에디토리얼 문체로 재작성해라
                  (앞 2~3문장은 3줄 미리보기로도 매력적인 도입부, 이후 역사·유래 등 배경 설명은 자연스러운
                  문단으로 이어지게 — 사실관계는 원문 그대로 유지하고 새로운 사실을 지어내지 마라).
                - 재작성된 한국어 버전을 기준으로 영어(descriptionEn), 일본어(descriptionJa) 번역본도 함께 만들어라.
                - 응답은 반드시 다음 키를 가진 JSON 객체 하나만: titleEn, titleJa, descriptionKo, descriptionEn, descriptionJa
                """;
        String userPrompt = """
                titleKo: %s
                descriptionKo: %s
                """.formatted(titleKo, rawDescriptionKo == null ? "" : rawDescriptionKo);

        JsonNode json = callChatCompletions(systemPrompt, userPrompt);
        if (json == null) return null;

        try {
            return new LocalizedContent(
                    textOrNull(json, "titleEn"),
                    textOrNull(json, "titleJa"),
                    textOrNull(json, "descriptionKo"),
                    textOrNull(json, "descriptionEn"),
                    textOrNull(json, "descriptionJa")
            );
        } catch (Exception e) {
            log.warn("스팟 다국어 응답 파싱 실패: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 피드 글/댓글 전용. 원문 언어를 판별해서 그 언어의 텍스트는 그대로 두고 나머지 두 언어로
     * 번역한 3개 버전(ko/en/ja)을 모두 반환한다. 재작성 없음(사용자 글을 임의로 고치면 안 됨).
     * FeedService.createPost()/createComment()에서 글/댓글 작성 시점에만 호출된다.
     */
    public LocalizedText translate(String rawText) {
        String systemPrompt = """
                아래 텍스트의 언어를 한국어/영어/일본어 중 하나로 판별해라. 판별된 언어의
                텍스트는 절대 고치지 말고 원문 그대로 두고, 나머지 두 언어로 자연스럽게 번역해라.
                문체나 의미를 임의로 바꾸거나 재작성하지 마라(순수 번역만).
                응답은 반드시 다음 키를 가진 JSON 객체 하나만: ko, en, ja
                """;

        JsonNode json = callChatCompletions(systemPrompt, rawText);
        if (json == null) return null;

        try {
            return new LocalizedText(textOrNull(json, "ko"), textOrNull(json, "en"), textOrNull(json, "ja"));
        } catch (Exception e) {
            log.warn("피드 번역 응답 파싱 실패: {}", e.getMessage());
            return null;
        }
    }

    /** Chat Completions 호출 공통 로직 — message.content(JSON 문자열)를 파싱해서 반환. 실패 시 null. */
    private JsonNode callChatCompletions(String systemPrompt, String userPrompt) {
        try {
            Map<String, Object> body = Map.of(
                    "model", model,
                    "response_format", Map.of("type", "json_object"),
                    "messages", List.of(
                            Map.of("role", "system", "content", systemPrompt),
                            Map.of("role", "user", "content", userPrompt)
                    )
            );
            String responseBody = restClient.post()
                    .uri(CHAT_COMPLETIONS_URL)
                    .header("Authorization", "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(String.class);

            JsonNode root = objectMapper.readTree(responseBody);
            String content = root.path("choices").path(0).path("message").path("content").asText(null);
            if (content == null) return null;
            return objectMapper.readTree(content);
        } catch (Exception e) {
            log.warn("OpenAI 호출 실패: {}", e.getMessage());
            return null;
        }
    }

    private String textOrNull(JsonNode node, String field) {
        JsonNode value = node.path(field);
        if (value.isMissingNode() || value.isNull()) return null;
        String text = value.asText();
        return text.isBlank() ? null : text;
    }

    public record LocalizedContent(
            String titleEn, String titleJa,
            String descriptionKo, String descriptionEn, String descriptionJa
    ) {}

    public record LocalizedText(String ko, String en, String ja) {}
}
