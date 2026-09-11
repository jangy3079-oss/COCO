package com.coco.backend.repository;

import com.coco.backend.entity.CourseSpot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CourseSpotRepository extends JpaRepository<CourseSpot, Long> {

    List<CourseSpot> findByCourseIdOrderBySortOrderAsc(Long courseId);
}
