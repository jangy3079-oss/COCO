package com.coco.backend.repository;

import com.coco.backend.entity.RouteMap;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RouteMapRepository extends JpaRepository<RouteMap, Long> {

    List<RouteMap> findByUserId(Long userId);
}
