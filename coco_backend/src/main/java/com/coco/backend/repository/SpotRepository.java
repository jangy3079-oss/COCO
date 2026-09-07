package com.coco.backend.repository;

import com.coco.backend.entity.Spot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface SpotRepository extends JpaRepository<Spot, Long> {
    List<Spot> findByCategory(String category);

    // TourAPI 수집 시 이미 가져온 콘텐츠인지 중복 체크용
    Optional<Spot> findByTourApiId(String tourApiId);

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

    // 지도 화면에 실제 보이는 영역(뷰포트)만큼만 조회 — 줌/이동할 때마다 이 범위로 다시 호출해서
    // 전체 스팟을 한번에 안 뿌리고 화면에 보이는 것만 마커로 그리기 위함(핀 밀집 방지).
    @Query("""
        SELECT s FROM Spot s
        WHERE s.lat BETWEEN :swLat AND :neLat
          AND s.lng BETWEEN :swLng AND :neLng
          AND (:category IS NULL OR s.category = :category)
        """)
    List<Spot> findInBounds(@Param("swLat") double swLat,
                            @Param("neLat") double neLat,
                            @Param("swLng") double swLng,
                            @Param("neLng") double neLng,
                            @Param("category") String category);
}
