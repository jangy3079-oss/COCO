package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "spots")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Spot {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "spot_id")
    private Long spotId;

    @Column(name = "tour_apiid", length = 20)
    private String tourApiId;

    @Column(name = "title_ko", length = 100)
    private String titleKo;

    @Column(name = "title_en", length = 100)
    private String titleEn;

    @Column(name = "title_ja", length = 100)
    private String titleJa;

    private Double lat;

    private Double lng;

    @Column(length = 200)
    private String address;

    @Column(length = 20)
    private String category;    // 노포 | 공원 | 카페 | 골목

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
