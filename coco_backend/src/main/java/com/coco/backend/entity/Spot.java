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

    // TourAPI 원본 분류값 — COCO 카테고리로 매핑하기 전 원본을 그대로 보존해둔다
    // (나중에 매핑 규칙을 바꾸거나 재분류할 때 원본 없이는 되돌릴 수 없어서).
    // 카카오 로컬 소스는 이 값들이 없어 전부 null.
    @Column(name = "tour_content_type_id", length = 10)
    private String tourContentTypeId;

    @Column(length = 10)
    private String cat1;

    @Column(length = 10)
    private String cat2;

    @Column(length = 10)
    private String cat3;


    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    // 스팟 상세 화면 본문 소개글. TourAPI 소스는 detailCommon2의 overview로 채워지고,
    // 카카오 로컬 소스는 API 자체에 설명 필드가 없어 null로 남는다(프론트에서 안내 문구로 대체).
    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "description_en", columnDefinition = "TEXT")
    private String descriptionEn;

    @Column(name = "description_ja", columnDefinition = "TEXT")
    private String descriptionJa;

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
    public Spot(String tourApiid, String kakaoPlaceId, String titleKo, String titleEn, String titleJa, Double lat, Double lng, String address, String category, String tourContentTypeId, String cat1, String cat2, String cat3, String imageUrl, String description, String descriptionEn, String descriptionJa, Boolean isLocalPick) {
        this.tourApiid = tourApiid;
        this.kakaoPlaceId = kakaoPlaceId;
        this.titleKo = titleKo;
        this.titleEn = titleEn;
        this.titleJa = titleJa;
        this.lat = lat;
        this.lng = lng;
        this.address = address;
        this.category = category;
        this.tourContentTypeId = tourContentTypeId;
        this.cat1 = cat1;
        this.cat2 = cat2;
        this.cat3 = cat3;
        this.imageUrl = imageUrl;
        this.description = description;
        this.descriptionEn = descriptionEn;
        this.descriptionJa = descriptionJa;
        this.isLocalPick = isLocalPick != null ? isLocalPick : false;
        // createdAt은 @CreationTimestamp가 알아서 해주므로 Builder 에서 제외.

    }

    // TourAPI 재import 시 이미 있는 스팟(contentid 동일)을 갱신(SpotService.importFromTourApi)하는
    // 전용 메서드 — 번역(title/description en·ja)은 최초 1회 값을 그대로 유지하고 여기서 건드리지 않는다.
    public void updateFromTourApi(String titleKo, String address, Double lat, Double lng, String imageUrl,
                                   String category, String tourContentTypeId, String cat1, String cat2, String cat3,
                                   String description) {
        this.titleKo = titleKo;
        this.address = address;
        this.lat = lat;
        this.lng = lng;
        this.imageUrl = imageUrl;
        this.category = category;
        this.tourContentTypeId = tourContentTypeId;
        this.cat1 = cat1;
        this.cat2 = cat2;
        this.cat3 = cat3;
        this.description = description;
    }
}
