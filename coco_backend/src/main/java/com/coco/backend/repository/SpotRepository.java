package com.coco.backend.repository;

import com.coco.entity.Spot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface SpotRepository extends JpaRepository<Spot, Long> {
    List<Spot> findByCategory(String category);

    // 반경 내 스팟 조회 (Haversine)
    @Query(value = """
        SELECT * FROM spots
        WHERE (6371 * acos(cos(radians(:lat)) * cos(radians(lat))
              * cos(radians(lng) - radians(:lng))
              + sin(radians(:lat)) * sin(radians(lat)))) < :radiusKm
        """, nativeQuery = true)
    List<Spot> findNearby(@Param("lat") double lat,
                          @Param("lng") double lng,
                          @Param("radiusKm") double radiusKm);
}
