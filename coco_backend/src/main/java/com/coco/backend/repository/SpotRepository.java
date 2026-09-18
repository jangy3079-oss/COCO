package com.coco.backend.repository;

import com.coco.backend.entity.Spot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SpotRepository extends JpaRepository<Spot, Long> {

    // TourAPI 수집 시 이미 가져온 콘텐츠인지 중복 체크용
    Optional<Spot> findByTourApiid(String tourApiid);

    // 카카오 로컬 수집 시 이미 가져온 장소인지 중복 체크용
    Optional<Spot> findByKakaoPlaceId(String kakaoPlaceId);

    // 코스 만들기 "+ 스팟 추가" 등에서 쓰는 텍스트 검색 — 한/영/일 제목 또는 주소 중
    // 하나라도 키워드를 포함하면 매치(title이 titleKo/titleEn/titleJa로 나뉘면서
    // 파생 쿼리 메서드로는 표현이 안 돼 @Query로 직접 작성).
    @Query("""
        SELECT s FROM Spot s
        WHERE LOWER(s.titleKo) LIKE LOWER(CONCAT('%', :q, '%'))
           OR LOWER(s.titleEn) LIKE LOWER(CONCAT('%', :q, '%'))
           OR LOWER(s.titleJa) LIKE LOWER(CONCAT('%', :q, '%'))
           OR LOWER(s.address) LIKE LOWER(CONCAT('%', :q, '%'))
        """)
    List<Spot> searchByKeyword(@Param("q") String q);

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
