package com.coco.backend.service;

import com.coco.backend.entity.FeedPost;
import com.coco.backend.entity.Spot;
import com.coco.backend.entity.User;
import com.coco.backend.repository.FeedCommentRepository;
import com.coco.backend.repository.FeedPostLikeRepository;
import com.coco.backend.repository.FeedPostRepository;
import com.coco.backend.repository.FeedPostSaveRepository;
import com.coco.backend.repository.RouteMapRepository;
import com.coco.backend.repository.SpotRepository;
import com.coco.backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FeedServiceTest {

    @Mock private FeedPostRepository feedPostRepository;
    @Mock private FeedPostLikeRepository feedPostLikeRepository;
    @Mock private FeedPostSaveRepository feedPostSaveRepository;
    @Mock private FeedCommentRepository feedCommentRepository;
    @Mock private SpotRepository spotRepository;
    @Mock private UserRepository userRepository;
    @Mock private RouteMapRepository routeMapRepository;
    @Mock private TranslationService translationService;
    @InjectMocks private FeedService feedService;

    @Test
    void listFeedUsesLocalizedSpotNameAndFallsBackToKorean() {
        Spot spot = org.mockito.Mockito.mock(Spot.class);
        when(spot.getId()).thenReturn(10L);
        when(spot.getTitleKo()).thenReturn("감천문화마을");
        when(spot.getTitleEn()).thenReturn("Gamcheon Culture Village");
        when(spot.getTitleJa()).thenReturn("  ");
        User user = org.mockito.Mockito.mock(User.class);
        FeedPost post = org.mockito.Mockito.mock(FeedPost.class);
        when(post.getId()).thenReturn(1L);
        when(post.getSpot()).thenReturn(spot);
        when(post.getUser()).thenReturn(user);
        when(post.getLikeCount()).thenReturn(0);
        when(post.getSaveCount()).thenReturn(0);
        when(post.getCreatedAt()).thenReturn(LocalDateTime.of(2026, 9, 21, 2, 0));
        when(feedPostRepository.findTop50ByOrderByCreatedAtDesc()).thenReturn(List.of(post));
        when(feedPostRepository.aggregateEngagementBySpotIds(List.of(spot.getId()))).thenReturn(List.of());

        assertThat(feedService.listFeed(null, "en").get(0).getSpotName())
                .isEqualTo("Gamcheon Culture Village");
        assertThat(feedService.listFeed(null, "ja").get(0).getSpotName())
                .isEqualTo("감천문화마을");
    }
}
