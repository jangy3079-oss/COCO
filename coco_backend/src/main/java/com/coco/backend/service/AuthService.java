package com.coco.backend.service;

import com.coco.backend.dto.request.LoginRequest;
import com.coco.backend.dto.request.SignupRequest;
import com.coco.backend.dto.response.AuthResponse;
import com.coco.backend.entity.Role;
import com.coco.backend.entity.User;
import com.coco.backend.exception.DuplicateEmailException;
import com.coco.backend.exception.InvalidCredentialsException;
import com.coco.backend.repository.UserRepository;
import com.coco.backend.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    @Transactional
    public AuthResponse signup(SignupRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new DuplicateEmailException("이미 가입된 이메일입니다.");
        }

        User user = User.builder()
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .nickname(request.getNickname())
                .locale(request.getLocale())
                .role(parseRole(request.getRole()))
                .build();

        User saved = userRepository.save(user);
        return toAuthResponse(saved);
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new InvalidCredentialsException("이메일 또는 비밀번호가 일치하지 않습니다."));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new InvalidCredentialsException("이메일 또는 비밀번호가 일치하지 않습니다.");
        }

        return toAuthResponse(user);
    }

    private Role parseRole(String role) {
        try {
            return Role.valueOf(role.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("유효하지 않은 role 값입니다. (LOCAL 또는 TOURIST)");
        }
    }

    private AuthResponse toAuthResponse(User user) {
        String token = jwtTokenProvider.createToken(user.getId(), user.getEmail(), user.getRole().name());
        return AuthResponse.builder()
                .accessToken(token)
                .userId(user.getId())
                .email(user.getEmail())
                .nickname(user.getNickname())
                .role(user.getRole().name())
                .locale(user.getLocale())
                .build();
    }
}
