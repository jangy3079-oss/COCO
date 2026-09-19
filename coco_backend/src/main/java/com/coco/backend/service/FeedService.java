package com.coco.backend.service;

import com.coco.backend.dto.request.FeedCommentRequest;
import com.coco.backend.dto.request.FeedPostRequest;
import com.coco.backend.dto.response.FeedCommentResponse;
import com.coco.backend.dto.response.FeedPostResponse;
import com.coco.backend.dto.response.LikeToggleResponse;
import com.coco.backend.dto.response.SaveToggleResponse;
import com.coco.backend.entity.FeedComment;
import com.coco.backend.entity.FeedPost;
import com.coco.backend.entity.FeedPostLike;
import com.coco.backend.entity.FeedPostSave;
import com.coco.backend.entity.RouteMap;
import com.coco.backend.entity.Spot;
import com.coco.backend.entity.User;
import com.coco.backend.repository.FeedCommentRepository;
import com.coco.backend.repository.FeedPostLikeRepository;
import com.coco.backend.repository.FeedPostRepository;
import com.coco.backend.repository.FeedPostSaveRepository;
import com.coco.backend.repository.RouteMapRepository;
import com.coco.backend.repository.SpotRepository;
import com.coco.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 피드 게시물 CRUD + 좋아요/댓글 — 지금은 "사진(선택) + 텍스트 + 스팟 태그" 게시물만 다룬다.
 * 코스(경로) 첨부 게시물은 아직 이 범위 밖이며 프론트는 그 부분을 여전히 목업으로 보여준다.
 */
@Service
@RequiredArgsConstructor
public class FeedService {

    private final FeedPostRepository feedPostRepository;
    private final FeedPostLikeRepository feedPostLikeRepository;
    private final FeedPostSaveRepository feedPostSaveRepository;
    private final FeedCommentRepository feedCommentRepository;
    private final SpotRepository spotRepository;
    private final UserRepository userRepository;
    private final RouteMapRepository routeMapRepository;

    /** 로그인한 사용자(userId)가 특정 스팟을 태그해서(또는 코스를 공유해서) 글을 쓴다. */
    public FeedPostResponse createPost(Long userId, FeedPostRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
        Spot spot = request.getSpotId() != null
                ? spotRepository.findById(request.getSpotId())
                        .orElseThrow(() -> new IllegalArgumentException("스팟을 찾을 수 없습니다."))
                : null;
        RouteMap route = request.getRouteId() != null
                ? routeMapRepository.findById(request.getRouteId())
                        .orElseThrow(() -> new IllegalArgumentException("코스를 찾을 수 없습니다."))
                : null;

        FeedPost saved = feedPostRepository.save(FeedPost.builder()
                .user(user)
                .spot(spot)
                .route(route)
                .imageUrl(request.getImageUrl())
                .description(request.getDescription())
                .build());

        // 방금 쓴 글은 당연히 아직 인기(trending)일 수 없고 내가 좋아요/저장을 누른 상태도
        // 아니므로 별도 조회 없이 false로 바로 응답.
        return toResponse(saved, false, false, false);
    }

    /**
     * 최신순 목록. 스팟별 인기 판정과, 로그인한 유저(userId, 비로그인이면 null)가 좋아요/저장을
     * 누른 게시물 집합을 각각 한 번에 묶어서 조회해 N+1을 피한다.
     */
    public List<FeedPostResponse> listFeed(Long userId) {
        List<FeedPost> posts = feedPostRepository.findTop50ByOrderByCreatedAtDesc();
        if (posts.isEmpty()) return List.of();

        List<Long> postIds = posts.stream().map(FeedPost::getId).toList();
        Map<Long, Boolean> trendingBySpotId = trendingBySpotId(posts);

        Set<Long> likedPostIds = userId == null
                ? Set.of()
                : new HashSet<>(feedPostLikeRepository.findLikedPostIds(userId, postIds));
        Set<Long> savedPostIds = userId == null
                ? Set.of()
                : new HashSet<>(feedPostSaveRepository.findSavedPostIds(userId, postIds));

        return posts.stream()
                .map(p -> toResponse(
                        p,
                        p.getSpot() != null && Boolean.TRUE.equals(trendingBySpotId.get(p.getSpot().getId())),
                        likedPostIds.contains(p.getId()),
                        savedPostIds.contains(p.getId())))
                .toList();
    }

    /**
     * 마이페이지 "좋아요한 피드" 탭용 — 최신 50개 캡이 있는 listFeed()와 달리 캡 없이 전체를
     * 가져온다(SpotService.getLikedSpots와 동일한 패턴). 여기 있다는 것 자체가 좋아요를
     * 눌렀다는 뜻이므로 liked는 항상 true로 채운다.
     */
    public List<FeedPostResponse> getLikedFeed(Long userId) {
        List<FeedPost> posts = feedPostLikeRepository.findPostsByUserId(userId);
        if (posts.isEmpty()) return List.of();

        List<Long> postIds = posts.stream().map(FeedPost::getId).toList();
        Map<Long, Boolean> trendingBySpotId = trendingBySpotId(posts);
        Set<Long> savedPostIds = new HashSet<>(feedPostSaveRepository.findSavedPostIds(userId, postIds));

        return posts.stream()
                .map(p -> toResponse(
                        p,
                        p.getSpot() != null && Boolean.TRUE.equals(trendingBySpotId.get(p.getSpot().getId())),
                        true,
                        savedPostIds.contains(p.getId())))
                .toList();
    }

    /**
     * 마이페이지 "저장한 피드" 탭용 — getLikedFeed()와 완전히 동일한 패턴이다. 여기 있다는 것
     * 자체가 저장했다는 뜻이므로 saved는 항상 true로 채운다.
     */
    public List<FeedPostResponse> getSavedFeed(Long userId) {
        List<FeedPost> posts = feedPostSaveRepository.findPostsByUserId(userId);
        if (posts.isEmpty()) return List.of();

        List<Long> postIds = posts.stream().map(FeedPost::getId).toList();
        Map<Long, Boolean> trendingBySpotId = trendingBySpotId(posts);
        Set<Long> likedPostIds = new HashSet<>(feedPostLikeRepository.findLikedPostIds(userId, postIds));

        return posts.stream()
                .map(p -> toResponse(
                        p,
                        p.getSpot() != null && Boolean.TRUE.equals(trendingBySpotId.get(p.getSpot().getId())),
                        likedPostIds.contains(p.getId()),
                        true))
                .toList();
    }

    /** 게시물들이 태그된 스팟들의 인기(trending) 여부를 한 번에 집계. 반환값: spotId -> trending. */
    private Map<Long, Boolean> trendingBySpotId(List<FeedPost> posts) {
        List<Long> spotIds = posts.stream()
                .filter(p -> p.getSpot() != null)
                .map(p -> p.getSpot().getId())
                .distinct()
                .toList();

        Map<Long, Boolean> trendingBySpotId = new HashMap<>();
        if (!spotIds.isEmpty()) {
            for (Object[] row : feedPostRepository.aggregateEngagementBySpotIds(spotIds)) {
                Long spotId = (Long) row[0];
                long postCount = ((Number) row[1]).longValue();
                long likeSum = ((Number) row[2]).longValue();
                trendingBySpotId.put(spotId, SpotService.isTrending(postCount, likeSum));
            }
        }
        return trendingBySpotId;
    }

    /** 좋아요 토글 — 이미 눌렀으면 취소, 아니면 새로 누른다. */
    @Transactional
    public LikeToggleResponse toggleLike(Long userId, Long postId) {
        FeedPost post = feedPostRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("게시물을 찾을 수 없습니다."));

        var existing = feedPostLikeRepository.findByUser_IdAndFeedPost_Id(userId, postId);
        boolean liked;
        if (existing.isPresent()) {
            feedPostLikeRepository.delete(existing.get());
            post.decreaseLike();
            liked = false;
        } else {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
            feedPostLikeRepository.save(FeedPostLike.builder().user(user).feedPost(post).build());
            post.increaseLike();
            liked = true;
        }
        return LikeToggleResponse.builder().liked(liked).likeCount(post.getLikeCount()).build();
    }

    /** 저장(북마크) 토글 — 이미 저장했으면 취소, 아니면 새로 저장한다. */
    @Transactional
    public SaveToggleResponse toggleSave(Long userId, Long postId) {
        FeedPost post = feedPostRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("게시물을 찾을 수 없습니다."));

        var existing = feedPostSaveRepository.findByUser_IdAndFeedPost_Id(userId, postId);
        boolean saved;
        if (existing.isPresent()) {
            feedPostSaveRepository.delete(existing.get());
            post.decreaseSave();
            saved = false;
        } else {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
            feedPostSaveRepository.save(FeedPostSave.builder().user(user).feedPost(post).build());
            post.increaseSave();
            saved = true;
        }
        return SaveToggleResponse.builder().saved(saved).saveCount(post.getSaveCount()).build();
    }

    /** 특정 게시물의 댓글 목록(오래된 순). */
    public List<FeedCommentResponse> listComments(Long postId) {
        return feedCommentRepository.findByFeedPost_IdOrderByCreatedAtAsc(postId).stream()
                .map(this::toCommentResponse)
                .toList();
    }

    /** 로그인한 사용자가 댓글을 단다. */
    public FeedCommentResponse createComment(Long userId, Long postId, FeedCommentRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
        FeedPost post = feedPostRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("게시물을 찾을 수 없습니다."));

        FeedComment saved = feedCommentRepository.save(FeedComment.builder()
                .feedPost(post)
                .user(user)
                .content(request.getContent())
                .build());
        return toCommentResponse(saved);
    }

    private FeedPostResponse toResponse(FeedPost p, boolean trending, boolean liked, boolean saved) {
        Spot spot = p.getSpot();
        return FeedPostResponse.builder()
                .id(p.getId())
                .userNickname(p.getUser().getNickname())
                .imageUrl(p.getImageUrl())
                .description(p.getDescription())
                .spotId(spot != null ? spot.getId() : null)
                .spotName(spot != null ? spot.getTitleKo() : null)
                .lat(spot != null ? spot.getLat() : null)
                .lng(spot != null ? spot.getLng() : null)
                .routeId(p.getRoute() != null ? p.getRoute().getId() : null)
                .likeCount(p.getLikeCount())
                .saveCount(p.getSaveCount())
                .createdAt(p.getCreatedAt())
                .trending(trending)
                .liked(liked)
                .saved(saved)
                .build();
    }

    private FeedCommentResponse toCommentResponse(FeedComment c) {
        return FeedCommentResponse.builder()
                .id(c.getId())
                .userNickname(c.getUser().getNickname())
                .content(c.getContent())
                .createdAt(c.getCreatedAt())
                .build();
    }
}
