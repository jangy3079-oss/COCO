package com.coco.backend.repository;

import com.coco.backend.entity.FeedPost;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FeedPostRepository extends JpaRepository<FeedPost, Long> {
    Page<FeedPost> findAllByOrderByCreatedAtDesc(Pageable pageable);
    // Spot 엔티티의 PK 필드명이 spotId라서, "spot.id"가 아니라 "spot.spotId"로
    // 경로를 명시해야 한다(언더스코어 표기로 중첩 프로퍼티 경로를 지정).
    Page<FeedPost> findBySpot_SpotId(Long spotId, Pageable pageable);
}
