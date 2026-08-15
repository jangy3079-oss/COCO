package com.coco.backend.repository;

import com.coco.backend.entity.FeedPostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FeedPostLikeRepository extends JpaRepository<FeedPostLike, Long> {
}
