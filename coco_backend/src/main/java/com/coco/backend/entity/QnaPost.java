package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "qna_posts")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class QnaPost {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "qna_post_id")
    private Long qnaPostId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(length = 500)
    private String question;

    @Column(length = 5)
    private String locale;              // ko | en | ja

    @OneToMany(mappedBy = "qnaPost", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<QnaAnswer> answers;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
