package com.coco.backend.repository;

import com.coco.backend.entity.QnaPost;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface QnaPostRepository extends JpaRepository<QnaPost, Long> {

    // filter=all/unanswered — 최신순 전체 목록 (답변 유무 필터링은 서비스에서 답변 수와 조합)
    List<QnaPost> findAllByOrderByCreatedAtDesc();

    // filter=mine — 로그인한 유저가 쓴 질문만
    List<QnaPost> findByUser_IdOrderByCreatedAtDesc(Long userId);
}
