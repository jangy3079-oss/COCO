package com.coco.backend.repository;

import com.coco.backend.entity.FeedPost;
import com.coco.backend.entity.FeedPostSave;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FeedPostSaveRepository extends JpaRepository<FeedPostSave, Long> {

    Optional<FeedPostSave> findByUser_IdAndFeedPost_Id(Long userId, Long feedPostId);

    // 피드 목록을 한 번에 조회할 때, 로그인한 유저가 그중 어떤 게시물을 저장했는지
    // 한 쿼리로 가져오기 위한 배치 조회(N+1 방지).
    @Query("SELECT s.feedPost.id FROM FeedPostSave s WHERE s.user.id = :userId AND s.feedPost.id IN :postIds")
    List<Long> findSavedPostIds(@Param("userId") Long userId, @Param("postIds") List<Long> postIds);

    // "저장한 피드" 탭용 — 캡 없이 전체를 최신 저장 순으로 조회.
    @Query("SELECT s.feedPost FROM FeedPostSave s WHERE s.user.id = :userId ORDER BY s.createdAt DESC")
    List<FeedPost> findPostsByUserId(@Param("userId") Long userId);
}
