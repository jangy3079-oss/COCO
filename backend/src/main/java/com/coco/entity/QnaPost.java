package com.coco.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.List;

@Entity @Table(name = "qna_posts")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class QnaPost {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(length = 500)
    private String question;

    private String locale;              // 질문 언어

    @OneToMany(mappedBy = "qnaPost", cascade = CascadeType.ALL)
    private List<QnaAnswer> answers;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() { this.createdAt = LocalDateTime.now(); }
}
