package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "feed_comments")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FeedComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "feed_comment_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "feed_post_id", nullable = false)
    private FeedPost feedPost;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(length = 300)
    private String content;

    // 원문 언어가 ko가 아니면 번역, ko면 재작성 없이 그대로 원문. 실패 시 null(원문 폴백).
    @Column(name = "content_en", length = 300)
    private String contentEn;

    @Column(name = "content_ja", length = 300)
    private String contentJa;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public FeedComment(FeedPost feedPost, User user, String content, String contentEn, String contentJa) {
        this.feedPost = feedPost;
        this.user = user;
        this.content = content;
        this.contentEn = contentEn;
        this.contentJa = contentJa;
    }
}
