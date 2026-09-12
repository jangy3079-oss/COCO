package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "feed_posts")

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FeedPost {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "feed_post_id")
    private Long id;


    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "spot_id")
    private Spot spot;

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @Column(length = 500)
    private String description;


    @Column(name = "like_count", nullable = false)
    private Integer likeCount;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public FeedPost(User user, Spot spot, String imageUrl, String description, Integer likeCount) {
        this.user = user;
        this.spot = spot;
        this.imageUrl = imageUrl;
        this.description = description;
        // 게시글이 처음 생성될 때 좋아요 수는 무조건 0이어야 하므로
        this.likeCount = likeCount != null ? likeCount : 0;
    }

    // 좋아요 토글(FeedService.toggleLike) 전용 — like_count 컬럼을 여기서만 증감시킨다.
    public void increaseLike() {
        this.likeCount++;
    }

    public void decreaseLike() {
        if (this.likeCount > 0) {
            this.likeCount--;
        }
    }
}
