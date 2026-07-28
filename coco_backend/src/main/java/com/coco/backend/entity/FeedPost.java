package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "feed_posts")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class FeedPost {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "feed_post_id")
    private Long feedPostId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "spot_id")
    private Spot spot;

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @Column(length = 500)
    private String description;

    @Column(name = "like_count", columnDefinition = "INT DEFAULT 0")
    private int likeCount;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
