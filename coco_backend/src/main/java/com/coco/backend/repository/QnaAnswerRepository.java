package com.coco.backend.repository;

import com.coco.backend.entity.QnaAnswer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface QnaAnswerRepository extends JpaRepository<QnaAnswer, Long> {

    // 질문 상세 화면용 답변 목록(오래된 순)
    List<QnaAnswer> findByQnaPost_IdOrderByCreatedAtAsc(Long qnaPostId);

    // 목록 화면에서 질문별 답변 개수를 한 번에 집계 — filter=unanswered / sort=unanswered_first에 사용
    @Query("SELECT a.qnaPost.id, COUNT(a) FROM QnaAnswer a WHERE a.qnaPost.id IN :postIds GROUP BY a.qnaPost.id")
    List<Object[]> countByQnaPostIds(@Param("postIds") List<Long> postIds);
}
