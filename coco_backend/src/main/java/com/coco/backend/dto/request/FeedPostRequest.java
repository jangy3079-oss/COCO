package com.coco.backend.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;

@Getter
public class FeedPostRequest {
    // 실제 이미지 업로드(스토리지) 연동 전까지는 사진 없이 텍스트+스팟 태그만으로도
    // 게시물을 쓸 수 있어야 해서 필수(@NotBlank)에서 뺐다 — DB 컬럼도 nullable.
    private String imageUrl;
    private String description;
    @NotNull
    private Long spotId;        // 위치태그 — FeedPost.spot이 not-null FK라 필수.
}
