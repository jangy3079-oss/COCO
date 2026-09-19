package com.coco.backend.service;

import com.coco.backend.dto.request.SpotRegistrationRequest;
import com.coco.backend.dto.response.SpotRegistrationResponse;
import com.coco.backend.entity.SpotRegistration;
import com.coco.backend.entity.User;
import com.coco.backend.repository.SpotRegistrationRepository;
import com.coco.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 스팟 등록 신청 — 제출과 내 신청 상태 조회만 다룬다.
 * 심사(승인/반려) 관리자 기능은 이번 범위 밖이라 신청 상태는 항상 PENDING으로 생성된다.
 */
@Service
@RequiredArgsConstructor
public class SpotRegistrationService {

    private final SpotRegistrationRepository spotRegistrationRepository;
    private final UserRepository userRepository;

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
        return toResponse(saved);
    }

    /** 내가 신청한 목록(최신순) — 각각의 심사 상태(status) 포함. */
    public List<SpotRegistrationResponse> listMine(Long userId) {
        return spotRegistrationRepository.findByUser_IdOrderByCreatedAtDesc(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    private SpotRegistrationResponse toResponse(SpotRegistration r) {
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
                .build();
    }
}
