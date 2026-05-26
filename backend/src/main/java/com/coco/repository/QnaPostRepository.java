package com.coco.repository;

import com.coco.entity.QnaPost;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QnaPostRepository extends JpaRepository<QnaPost, Long> {
    Page<QnaPost> findAllByOrderByCreatedAtDesc(Pageable pageable);
}
