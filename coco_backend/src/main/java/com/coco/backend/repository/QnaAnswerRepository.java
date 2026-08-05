package com.coco.backend.repository;

import com.coco.backend.entity.QnaAnswer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface QnaAnswerRepository extends JpaRepository<QnaAnswer, Long> {
}
