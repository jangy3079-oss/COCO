package com.coco.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
    // TODO: JWT 필터, CORS 설정 예정 — 아직 로그인/인증 필터가 없어서 우선 전체 permitAll로 열어둠.
    // JWT 필터를 붙일 때 /api/spot/import 같은 관리자 전용 엔드포인트는 별도 인가 규칙으로 좁혀야 함.
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        return http.build();
    }
}
