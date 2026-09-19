package com.coco.backend.repository;

import com.coco.backend.entity.RouteMap;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RouteMapRepository extends JpaRepository<RouteMap, Long> {

    // "내가 만든 코스" 목록 — 최신순
    List<RouteMap> findByUser_IdOrderByCreatedAtDesc(Long userId);
}
