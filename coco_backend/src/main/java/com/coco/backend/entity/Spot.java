package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "spots")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Spot {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "spot_id")
    private Long id;

    @Column(name = "tour_apiid", length = 20)
    private String tourApiid;

    @Column(length = 100)
    private String title;

    @Column(nullable = false)
    private Double lat;

    @Column(nullable = false)
    private Double lng;

    @Column(length = 200)
    private String address;

    @Column(length = 20)
    private String category;

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public Spot(String tourApiid, String title, Double lat, Double lng, String address, String category, String imageUrl) {
        this.tourApiid = tourApiid;
        this.title = title;
        this.lat = lat;
        this.lng = lng;
        this.address = address;
        this.category = category;
        this.imageUrl = imageUrl;
        // createdAt은 @CreationTimestamp가 알아서 해주므로 Builder 에서 제외.
    }
}
