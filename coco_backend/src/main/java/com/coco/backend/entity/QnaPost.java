package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "qna_posts")

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QnaPost {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "qna_post_id")
    private Long id;


    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(length = 100, nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    // 질문에 태그된 장소 — 선택사항
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "spot_id")
    private Spot spot;

    @Column(length = 5)
    private String locale;

    // 채택된 답변(QnaAnswer)의 id. 아직 채택 안 했으면 null.
    @Column(name = "adopted_answer_id")
    private Long adoptedAnswerId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public QnaPost(User user, String title, String content, Spot spot, String locale) {
        this.user = user;
        this.title = title;
        this.content = content;
        this.spot = spot;
        this.locale = locale;
    }

    // 답변 채택(QnaService.adopt) 전용 — adopted_answer_id 컬럼을 여기서만 갱신한다.
    public void adopt(Long answerId) {
        this.adoptedAnswerId = answerId;
    }
}
