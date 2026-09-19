package com.coco.backend.repository;

import com.coco.backend.entity.RouteMapSpot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RouteMapSpotRepository extends JpaRepository<RouteMapSpot, Long> {

    // 코스 상세용 — 방문 순서대로
    List<RouteMapSpot> findByRouteMap_IdOrderBySortOrderAsc(Long routeMapId);

    // "내가 만든 코스" 목록에서 여러 코스의 스팟을 한 번에 조회(N+1 방지) — routeMapId, 그 안에서는 순서대로 정렬
    List<RouteMapSpot> findByRouteMap_IdInOrderByRouteMap_IdAscSortOrderAsc(List<Long> routeMapIds);

    // 코스 수정(RouteService.update) 시 기존 스팟 목록을 통째로 교체하기 위한 삭제
    void deleteByRouteMap_Id(Long routeMapId);
}
