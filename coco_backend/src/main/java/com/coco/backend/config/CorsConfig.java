package com.coco.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH");
        // Flutter Web(CanvasKit)의 Image.network가 업로드 이미지를 fetch로 가져올 수 있게 허용.
        registry.addMapping("/uploads/**")
                .allowedOrigins("*")
                .allowedMethods("GET");
    }

}
