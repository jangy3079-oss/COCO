package com.coco.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/**
 * OpenAI Chat Completions API를 사용해 스팟 정보(title, description)를
 * 한국어 → 영어·일본어로 번역하는 서비스.
 *
 * - 모델: gpt-4o-mini (비용 효율 우선)
 * - title과 description을 하나의 요청으로 묶어 번역 → API 호출 최소화
 * - 번역 실패(API 오류, 파싱 오류 등) 시 TranslationResult의 모든 필드가 null인 채로 반환.
 *   호출부에서 null 체크 없이 updateTranslations()에 그대로 전달해도 되며,
 *   런타임 조회 시 resolveTitle/resolveDescription 이 titleKo/description으로 폴백한다.
 */
@Slf4j
@Service
public class OpenAiTranslationService {

    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

    @Value("${openai.api-key:}")
    private String apiKey;

    @Value("${openai.model:gpt-4o-mini}")
    private String model;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 번역 결과를 담는 record.
     * 번역에 실패하거나 API 키가 없으면 모든 필드가 null.
     */
    public record TranslationResult(
            String titleEn,
            String titleJa,
            String descriptionEn,
            String descriptionJa
    ) {
        /** 번역 실패 시 반환할 빈 결과 */
        public static TranslationResult empty() {
            return new TranslationResult(null, null, null, null);
        }
    }

    /**
     * 스팟의 titleKo와 description(한국어 소개글, null 허용)을 받아
     * 영어·일본어로 번역한 결과를 반환한다.
     *
     * @param titleKo    번역할 한국어 스팟명
     * @param description 번역할 한국어 소개글 (null이면 descriptionEn/Ja도 null)
     * @return 번역 결과. 실패 시 TranslationResult.empty()
     */
    public TranslationResult translateSpot(String titleKo, String description) {
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("OpenAI API 키가 설정되지 않아 번역을 건너뜁니다. (OPENAI_API_KEY 환경변수 확인)");
            return TranslationResult.empty();
        }

        try {
            String prompt = buildPrompt(titleKo, description);
            String responseBody = callOpenAi(prompt);
            return parseResponse(responseBody, description);
        } catch (Exception e) {
            log.warn("OpenAI 번역 실패 [titleKo={}]: {}", titleKo, e.getMessage());
            return TranslationResult.empty();
        }
    }

    // ── 내부 구현 ─────────────────────────────────────────────────────────

    private String buildPrompt(String titleKo, String description) {
        String descPart = (description != null && !description.isBlank())
                ? "- description: " + description
                : "- description: (없음)";

        return """
                당신은 한국 관광지 정보를 번역하는 전문가입니다.
                아래 정보를 영어(en)와 일본어(ja)로 번역해 주세요.
                
                번역 대상:
                - title: %s
                %s
                
                반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트는 절대 포함하지 마세요.
                {
                  "titleEn": "영어 제목",
                  "titleJa": "일본어 제목",
                  "descriptionEn": "영어 소개글 (description이 없으면 null)",
                  "descriptionJa": "일본어 소개글 (description이 없으면 null)"
                }
                """.formatted(titleKo, descPart);
    }

    private String callOpenAi(String userPrompt) throws Exception {
        String requestBody = objectMapper.writeValueAsString(java.util.Map.of(
                "model", model,
                "messages", java.util.List.of(
                        java.util.Map.of("role", "user", "content", userPrompt)
                ),
                "temperature", 0.2,   // 번역은 결정론적일수록 좋음
                "max_tokens", 500
        ));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(OPENAI_API_URL))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                .timeout(Duration.ofSeconds(30))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new RuntimeException("OpenAI API 오류: status=" + response.statusCode()
                    + ", body=" + response.body());
        }
        return response.body();
    }

    private TranslationResult parseResponse(String responseBody, String originalDescription) throws Exception {
        JsonNode root = objectMapper.readTree(responseBody);
        // OpenAI 응답: choices[0].message.content
        String content = root
                .path("choices").get(0)
                .path("message")
                .path("content")
                .asText();

        // content 안의 JSON을 파싱
        // LLM이 가끔 ```json ... ``` 마크다운 블록으로 감쌀 수 있어서 방어적으로 벗겨냄
        content = content.trim();
        if (content.startsWith("```")) {
            content = content.replaceAll("^```[a-z]*\\n?", "").replaceAll("```$", "").trim();
        }

        JsonNode json = objectMapper.readTree(content);

        String titleEn = json.path("titleEn").asText(null);
        String titleJa = json.path("titleJa").asText(null);

        // description 원본이 없으면 번역 결과도 null 처리
        boolean hasDescription = originalDescription != null && !originalDescription.isBlank();
        String descriptionEn = hasDescription ? json.path("descriptionEn").asText(null) : null;
        String descriptionJa = hasDescription ? json.path("descriptionJa").asText(null) : null;

        return new TranslationResult(titleEn, titleJa, descriptionEn, descriptionJa);
    }
}
