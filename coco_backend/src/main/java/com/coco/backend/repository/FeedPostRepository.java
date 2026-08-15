package com.coco.backend.repository;

import com.coco.backend.entity.FeedPost;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FeedPostRepository extends JpaRepository<FeedPost, Long> {
}
