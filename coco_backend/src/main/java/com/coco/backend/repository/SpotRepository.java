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

    // 카카오 로컬 수집 시 TourAPI로 이미 저장된 장소와 중복인지(같은 실제 장소) 체크할 때
    // 비교 기준으로 삼을 TourAPI 출처 스팟 전체 조회용
    List<Spot> findByTourApiidIsNotNull();

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

    // 지도 전용 조회(GET /api/spot/map) — category가 항상 6개 지도 카테고리 중 하나로
    // 확정된 뒤에만 호출되므로(SpotService.findMapSpots), 위 findInBounds와 달리
    // category IS NULL 분기 없이 단순 일치 조건만 쓴다.
    @Query("""
        SELECT s FROM Spot s
        WHERE s.lat BETWEEN :swLat AND :neLat
          AND s.lng BETWEEN :swLng AND :neLng
          AND s.category = :category
        """)
    List<Spot> findInBoundsByCategory(@Param("swLat") double swLat,
                                       @Param("neLat") double neLat,
                                       @Param("swLng") double swLng,
                                       @Param("neLng") double neLng,
                                       @Param("category") String category);

    // tourApiid가 있는(TourAPI 출처) 스팟 중 설명이 비어있거나 사진이 하나도 없는 것만.
    // 카카오 로컬 출처(tourApiid=null)는 애초에 overview/이미지 API 자체가 없어서 대상 아님.
    @Query("""
        SELECT s FROM Spot s
        WHERE s.tourApiid IS NOT NULL
          AND ((s.description IS NULL OR s.description = '')
               OR s.id NOT IN (SELECT DISTINCT si.spot.id FROM SpotImage si))
        """)
    List<Spot> findNeedingTourApiBackfill();
}
