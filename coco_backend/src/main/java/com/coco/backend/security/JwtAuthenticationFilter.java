package com.coco.backend.security;

import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Authorization: Bearer {token} 헤더가 있으면 파싱해서 로그인한 사용자(userId)를
 * SecurityContext에 심어준다. SecurityConfig가 지금 모든 요청을 permitAll 해두고
 * 있어서 이 필터는 "막는" 역할이 아니라 "누가 요청했는지 알려주는" 역할만 한다 —
 * 토큰이 없거나 잘못돼도 그냥 인증 안 된 상태로 다음 필터로 넘어간다.
 *
 * 컨트롤러에서 로그인한 사용자가 꼭 필요한 엔드포인트(예: 피드 작성)는
 * SecurityContextHolder.getContext().getAuthentication()의 principal(userId)이
 * null인지 직접 확인해서 401을 내려주면 된다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider jwtTokenProvider;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring("Bearer ".length());
            try {
                Long userId = jwtTokenProvider.getUserId(token);
                var authentication = new UsernamePasswordAuthenticationToken(userId, null, List.of());
                SecurityContextHolder.getContext().setAuthentication(authentication);
            } catch (JwtException | IllegalArgumentException e) {
                // 토큰이 만료됐거나 위조됐으면 로그인 안 한 것과 동일하게 취급 — 요청 자체는 계속 진행.
                log.debug("JWT 검증 실패, 비로그인 상태로 진행: {}", e.getMessage());
            }
        }
        filterChain.doFilter(request, response);
    }
}
