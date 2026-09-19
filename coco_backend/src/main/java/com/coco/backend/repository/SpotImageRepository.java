package com.coco.backend.repository;

import com.coco.backend.entity.SpotImage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SpotImageRepository extends JpaRepository<SpotImage, Long> {

    // 스팟 상세 화면 갤러리용 — TourAPI 응답 순서(sort_order) 그대로 조회
    List<SpotImage> findBySpot_IdOrderBySortOrderAsc(Long spotId);
}
