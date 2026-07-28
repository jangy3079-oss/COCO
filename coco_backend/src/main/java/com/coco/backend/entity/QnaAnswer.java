package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "qna_answers")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class QnaAnswer {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "qna_answer_id")
    private Long qnaAnswerId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "qna_post_id")
    private QnaPost qnaPost;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(length = 1000)
    private String content;

    private Boolean adopted;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
