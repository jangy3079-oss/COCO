package com.coco.backend.repository;

import com.coco.backend.entity.SpotLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SpotLikeRepository extends JpaRepository<SpotLike, Long> {
}
