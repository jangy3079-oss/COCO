package com.coco.backend.repository;

import com.coco.backend.entity.Spot;
import org.springframework.data.domain.Pageable;
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
    // "s.category IN (...)" 조건은 카테고리 칩 선택 여부와 무관하게 항상 적용되는 안전장치 —
    // 수집(TourAPI/카카오 로컬) 범위가 넓어지거나 예상 밖 카테고리 값이 들어와도, 코코가 다루는
    // 6종(음식점/카페/공원/골목/명소/문화시설) 밖의 스팟은 지도에 절대 안 뜨게 한다.
    // ('노포'는 '음식점'으로 통합되어 더 이상 쓰지 않음 — 기존 DB의 '노포' row는 별도 migration으로 전환.)
    // Pageable로 LIMIT을 걸어서 확 줌아웃했을 때 결과가 무제한으로 오는 것도 막는다.
    @Query("""
        SELECT s FROM Spot s
        WHERE s.lat BETWEEN :swLat AND :neLat
          AND s.lng BETWEEN :swLng AND :neLng
          AND s.category IN ('음식점', '카페', '공원', '골목', '명소', '문화시설')
          AND (:category IS NULL OR s.category = :category)
        """)
    List<Spot> findInBounds(@Param("swLat") double swLat,
                            @Param("neLat") double neLat,
                            @Param("swLng") double swLng,
                            @Param("neLng") double neLng,
                            @Param("category") String category,
                            Pageable pageable);

    // 번역 배치용: titleEn이 아직 null인 스팟만 조회 (번역 미완료 스팟 보완)
    List<Spot> findByTitleEnIsNull();
}
