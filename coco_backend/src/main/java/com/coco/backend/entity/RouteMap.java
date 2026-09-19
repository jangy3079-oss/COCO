package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "route_maps")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RouteMap {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "route_map_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(length = 100)
    private String title;

    @Column(nullable = false, length = 20)
    private String visibility;

    // 저장은 해뒀지만 아직 공개 발행 전인 임시 상태. 기본값 false(발행됨).
    @Column(name = "is_draft", nullable = false, columnDefinition = "boolean default false")
    private Boolean isDraft;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public RouteMap(User user, String title, String visibility, Boolean isDraft) {
        this.user = user;
        this.title = title;
        this.visibility = visibility != null ? visibility : "PRIVATE";
        this.isDraft = isDraft != null ? isDraft : false;
    }

    // 코스 수정(RouteService.update) 전용 — title/visibility/isDraft를 여기서만 갱신한다.
    public void update(String title, String visibility, Boolean isDraft) {
        this.title = title;
        if (visibility != null) this.visibility = visibility;
        if (isDraft != null) this.isDraft = isDraft;
    }
}
