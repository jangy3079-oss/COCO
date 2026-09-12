package com.coco.backend.repository;

import com.coco.backend.entity.FeedPost;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FeedPostRepository extends JpaRepository<FeedPost, Long> {

    // 뷰포트 안 스팟들의 "인기 핀" 판정을 스팟마다 따로 쿼리하면 N+1이라, 스팟id 목록을 한번에
    // 넘겨서 스팟별 게시물 수·좋아요 합을 한 쿼리로 묶어 가져온다. (spotId, postCount, likeSum) 순서.
    @Query("""
        SELECT f.spot.id, COUNT(f), COALESCE(SUM(f.likeCount), 0)
        FROM FeedPost f
        WHERE f.spot.id IN :spotIds
        GROUP BY f.spot.id
        """)
    List<Object[]> aggregateEngagementBySpotIds(@Param("spotIds") List<Long> spotIds);

    // 피드 탭 목록용 — 페이지네이션 UI가 아직 없어서 우선 최신 N개만 가져온다.
    List<FeedPost> findTop50ByOrderByCreatedAtDesc();
}
