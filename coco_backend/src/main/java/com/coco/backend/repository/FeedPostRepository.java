package com.coco.backend.repository;

import com.coco.entity.FeedPost;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FeedPostRepository extends JpaRepository<FeedPost, Long> {
    Page<FeedPost> findAllByOrderByCreatedAtDesc(Pageable pageable);
    Page<FeedPost> findBySpotId(Long spotId, Pageable pageable);
}
