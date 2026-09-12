package com.coco.backend.repository;

import com.coco.backend.entity.RouteMapSpot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RouteMapSpotRepository extends JpaRepository<RouteMapSpot, Long> {

    List<RouteMapSpot> findByRouteMapId(Long routeMapId);
}
