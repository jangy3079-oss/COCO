package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "spot_images")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SpotImage {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "spot_image_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "spot_id", nullable = false)
    private Spot spot;

    @Column(name = "image_url", columnDefinition = "TEXT", nullable = false)
    private String imageUrl;

    // TourAPI 응답 순서를 그대로 보존해서 갤러리 표시 순서로 쓴다.
    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    @Builder
    public SpotImage(Spot spot, String imageUrl, Integer sortOrder) {
        this.spot = spot;
        this.imageUrl = imageUrl;
        this.sortOrder = sortOrder;
    }
}
