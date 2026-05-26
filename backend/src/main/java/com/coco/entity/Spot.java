package com.coco.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity @Table(name = "spots")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Spot {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String tourApiContentId;   // TourAPI contentId
    private String titleKo;
    private String titleEn;
    private String titleJa;

    private Double lat;
    private Double lng;
    private String address;
    private String category;           // 노포 | 공원 | 카페 | 골목
    private String imageUrl;
}
