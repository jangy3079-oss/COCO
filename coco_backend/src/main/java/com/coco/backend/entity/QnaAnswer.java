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
        this.adopted = adopted;
    }
}

