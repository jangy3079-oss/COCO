package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "qna_answers")

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QnaAnswer {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "qna_answer_id")
    private Long id;


    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "qna_post_id", nullable = false)
    private QnaPost qnaPost;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(length = 1000)
    private String content;

    private Boolean adopted;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public QnaAnswer(QnaPost qnaPost, User user, String content, Boolean adopted) {
        this.qnaPost = qnaPost;
        this.user = user;
        this.content = content;
        // 답변이 처음 생성될 때 채택 여부는 무조건 false여야 하므로
        this.adopted = adopted != null ? adopted : false;
    }

    // 답변 채택(QnaService.adopt) 전용 — adopted 컬럼을 여기서만 갱신한다.
    public void markAdopted() {
        this.adopted = true;
    }
}

