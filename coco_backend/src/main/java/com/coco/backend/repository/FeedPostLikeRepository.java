package com.coco.backend.repository;

import com.coco.backend.entity.FeedPostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FeedPostLikeRepository extends JpaRepository<FeedPostLike, Long> {

    Optional<FeedPostLike> findByUser_IdAndFeedPost_Id(Long userId, Long feedPostId);

    // 피드 목록을 한 번에 조회할 때, 로그인한 유저가 그중 어떤 게시물에 좋아요를 눌렀는지
    // 한 쿼리로 가져오기 위한 배치 조회(N+1 방지).
    @Query("SELECT l.feedPost.id FROM FeedPostLike l WHERE l.user.id = :userId AND l.feedPost.id IN :postIds")
    List<Long> findLikedPostIds(@Param("userId") Long userId, @Param("postIds") List<Long> postIds);
}
