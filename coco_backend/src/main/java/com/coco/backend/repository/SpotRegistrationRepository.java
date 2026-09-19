package com.coco.backend.repository;

import com.coco.backend.entity.SpotRegistration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SpotRegistrationRepository extends JpaRepository<SpotRegistration, Long> {

    // "내 신청 목록" 조회용 — 최신순
    List<SpotRegistration> findByUser_IdOrderByCreatedAtDesc(Long userId);
}
