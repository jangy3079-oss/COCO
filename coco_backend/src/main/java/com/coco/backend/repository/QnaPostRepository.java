package com.coco.backend.repository;

import com.coco.backend.entity.QnaPost;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface QnaPostRepository extends JpaRepository<QnaPost, Long> {
}
