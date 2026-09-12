package com.coco.backend.repository;

import com.coco.backend.entity.FeedComment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FeedCommentRepository extends JpaRepository<FeedComment, Long> {
    List<FeedComment> findByFeedPost_IdOrderByCreatedAtAsc(Long feedPostId);
}
