package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "course_spots")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CourseSpot {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "course_spot_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "spot_id", nullable = false)
    private Spot spot;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    @Builder
    public CourseSpot(Course course, Spot spot, Integer sortOrder) {
        this.course = course;
        this.spot = spot;
        this.sortOrder = sortOrder;
    }
}
