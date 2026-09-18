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

    // 카카오 로컬 API에서 가져온 스팟의 중복 방지용 식별자. TourAPI 소스는 tour_apiid,
    // 카카오 로컬 소스는 이 컬럼으로 각자 구분해서 dedupe한다 (한 스팟이 두 값을 동시에 갖진 않음).
    @Column(name = "kakao_place_id", length = 20)
    private String kakaoPlaceId;

    @Column(name = "title_ko", length = 100)
    private String titleKo;

    @Column(name = "title_en", length = 100)
    private String titleEn;

    @Column(name = "title_ja", length = 100)
    private String titleJa;


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

    // 스팟 상세 화면 본문 소개글. TourAPI 소스는 detailCommon2의 overview로 채워지고,
    // 카카오 로컬 소스는 API 자체에 설명 필드가 없어 null로 남는다(프론트에서 안내 문구로 대체).
    @Column(columnDefinition = "TEXT")
    private String description;

    // 팀이 직접 검증해서 심어둔 "로컬 픽" 여부. 인기도(피드 반응)와 무관하게 항상 true면
    // 지도에서 다른 색으로 표시된다 — 아직 반응이 없는 진짜 로컬 스팟이 인기도 기준
    // 핀 크기 로직에 묻히지 않도록 색과 크기를 서로 다른 신호로 분리한 것.
    // Supabase Table Editor에서 팀이 수동으로 true/false 토글하는 방식으로 운영.
    @Column(name = "is_local_pick", nullable = false, columnDefinition = "boolean default false")
    private Boolean isLocalPick = false;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public Spot(String tourApiid, String kakaoPlaceId, String titleKo, String titleEn, String titleJa, Double lat, Double lng, String address, String category, String imageUrl, String description, Boolean isLocalPick) {
        this.tourApiid = tourApiid;
        this.kakaoPlaceId = kakaoPlaceId;
        this.titleKo = titleKo;
        this.titleEn = titleEn;
        this.titleJa = titleJa;
        this.lat = lat;
        this.lng = lng;
        this.address = address;
        this.category = category;
        this.imageUrl = imageUrl;
        this.description = description;
        this.isLocalPick = isLocalPick != null ? isLocalPick : false;
        // createdAt은 @CreationTimestamp가 알아서 해주므로 Builder 에서 제외.

    }
}
