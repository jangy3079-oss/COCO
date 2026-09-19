package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "route_saves", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "route_map_id"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RouteSave {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "route_save_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "route_map_id", nullable = false)
    private RouteMap routeMap;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public RouteSave(User user, RouteMap routeMap) {
        this.user = user;
        this.routeMap = routeMap;
    }
}
