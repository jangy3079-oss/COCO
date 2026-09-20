package com.coco.backend.service;

import com.coco.backend.dto.request.SpotRegistrationRequest;
import com.coco.backend.dto.response.SpotRegistrationResponse;
import com.coco.backend.entity.Spot;
import com.coco.backend.entity.SpotRegistration;
import com.coco.backend.entity.User;
import com.coco.backend.repository.SpotRegistrationRepository;
import com.coco.backend.repository.SpotRepository;
import com.coco.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 스팟 등록 신청 — 제출과 내 신청 상태 조회만 다룬다.
 * 심사(승인/반려) 관리자 기능은 이번 범위 밖이라 신청 상태는 항상 PENDING으로 생성된다.
 *
 * demo-mode(app.demo-mode, 기본 true)일 때는 신청과 동시에 spots 테이블에도 바로 반영해서
 * 지도/검색에 즉시 노출한다 — 실제 관리자 승인 플로우가 생기기 전까지의 임시 데모용 동작이며,
 * 나중에 createSpotFromRegistration 호출만 지우면 원래 "승인 대기" 흐름으로 돌아간다.
 */
@Service
@RequiredArgsConstructor
public class SpotRegistrationService {

    private final SpotRegistrationRepository spotRegistrationRepository;
    private final SpotRepository spotRepository;
    private final UserRepository userRepository;
    private final TranslationService translationService;

    @Value("${app.demo-mode:true}")
    private boolean demoMode;

    /** 로그인한 사용자가 새 스팟 등록을 신청한다. */
    public SpotRegistrationResponse register(Long userId, SpotRegistrationRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        SpotRegistration saved = spotRegistrationRepository.save(SpotRegistration.builder()
                .user(user)
                .name(request.getName())
                .category(request.getCategory())
                .address(request.getAddress())
                .lat(request.getLat())
                .lng(request.getLng())
                .description(request.getDescription())
                .build());

        Long createdSpotId = demoMode ? createSpotFromRegistration(request) : null;

        return toResponse(saved, createdSpotId);
    }

    /**
     * demo-mode 전용 — 등록 신청 내용을 그대로 실제 spots 행으로 만든다. 제목/설명은
     * TranslationService로 번역해서 title_en/ja, description_en/ja까지 채운다(실패하면
     * null로 남고 한국어로 폴백됨 — SpotService의 기존 패턴과 동일).
     */
    private Long createSpotFromRegistration(SpotRegistrationRequest request) {
        String description = request.getDescription();
        var localized = translationService.rewriteAndTranslate(request.getName(), description);

        Spot spot = Spot.builder()
                .titleKo(request.getName())
                .titleEn(localized != null ? localized.titleEn() : null)
                .titleJa(localized != null ? localized.titleJa() : null)
                .lat(request.getLat())
                .lng(request.getLng())
                .address(request.getAddress())
                .category(request.getCategory())
                .description(localized != null && localized.descriptionKo() != null
                        ? localized.descriptionKo() : description)
                .descriptionEn(localized != null ? localized.descriptionEn() : null)
                .descriptionJa(localized != null ? localized.descriptionJa() : null)
                .build();
        return spotRepository.save(spot).getId();
    }

    /** 내가 신청한 목록(최신순) — 각각의 심사 상태(status) 포함. */
    public List<SpotRegistrationResponse> listMine(Long userId) {
        return spotRegistrationRepository.findByUser_IdOrderByCreatedAtDesc(userId).stream()
                .map(r -> toResponse(r, null))
                .toList();
    }

    private SpotRegistrationResponse toResponse(SpotRegistration r, Long spotId) {
        return SpotRegistrationResponse.builder()
                .id(r.getId())
                .name(r.getName())
                .category(r.getCategory())
                .address(r.getAddress())
                .lat(r.getLat())
                .lng(r.getLng())
                .description(r.getDescription())
                .status(r.getStatus())
                .createdAt(r.getCreatedAt())
                .spotId(spotId)
                .build();
    }
}
