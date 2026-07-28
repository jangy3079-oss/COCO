package com.coco.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class User {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long userId;

    @Column(nullable = false, unique = true, length = 100)
    private String email;

    @Column(nullable = false, length = 255)
    private String password;

    @Column(nullable = false, length = 50)
    private String nickname;

    @Column(length = 5)
    private String locale;          // ko | en | ja

    @Column(length = 10)
    private String role;            // USER | LOCAL

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(length = 10)
    private String nationality;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
