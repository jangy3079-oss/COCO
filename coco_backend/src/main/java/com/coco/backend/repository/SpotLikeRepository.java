package com.coco.backend.repository;

import com.coco.backend.entity.Spot;
import com.coco.backend.entity.SpotLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SpotLikeRepository extends JpaRepository<SpotLike, Long> {

    // 찜 토글 시 이미 찜했는지 확인용
    Optional<SpotLike> findByUser_IdAndSpot_Id(Long userId, Long spotId);

    // 찜 개수 집계용 — Spot에 캐시 컬럼이 없어 매번 카운트
    long countBySpot_Id(Long spotId);

    // 마이페이지 등 "찜한 스팟 목록" 조회용 — 최근 찜한 순
    @Query("SELECT sl.spot FROM SpotLike sl WHERE sl.user.id = :userId ORDER BY sl.createdAt DESC")
    List<Spot> findSpotsByUserId(@Param("userId") Long userId);
}
