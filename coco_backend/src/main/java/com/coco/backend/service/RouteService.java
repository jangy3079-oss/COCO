package com.coco.backend.service;

import com.coco.backend.dto.request.RouteRequest;
import com.coco.backend.dto.response.LikeToggleResponse;
import com.coco.backend.dto.response.RouteResponse;
import com.coco.backend.dto.response.RouteSpotResponse;
import com.coco.backend.dto.response.SaveToggleResponse;
import com.coco.backend.entity.RouteLike;
import com.coco.backend.entity.RouteMap;
import com.coco.backend.entity.RouteMapSpot;
import com.coco.backend.entity.RouteSave;
import com.coco.backend.entity.Spot;
import com.coco.backend.entity.User;
import com.coco.backend.exception.ForbiddenException;
import com.coco.backend.repository.RouteLikeRepository;
import com.coco.backend.repository.RouteMapRepository;
import com.coco.backend.repository.RouteMapSpotRepository;
import com.coco.backend.repository.RouteSaveRepository;
import com.coco.backend.repository.SpotRepository;
import com.coco.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 코스(골목지도) — RouteMap/RouteMapSpot을 "코스" 자체로 재활용한다.
 * Course/CourseSpot은 별도 계층으로 어디서도 쓰이지 않는 죽은 코드라 이번 범위 밖.
 */
@Service
@RequiredArgsConstructor
public class RouteService {

    private final RouteMapRepository routeMapRepository;
    private final RouteMapSpotRepository routeMapSpotRepository;
    private final RouteLikeRepository routeLikeRepository;
    private final RouteSaveRepository routeSaveRepository;
    private final SpotRepository spotRepository;
    private final UserRepository userRepository;

    /** 로그인한 사용자가 스팟들을 순서대로 엮어 코스를 만든다. */
    @Transactional
    public RouteResponse createRoute(Long userId, RouteRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        RouteMap routeMap = routeMapRepository.save(RouteMap.builder()
                .user(user)
                .title(request.getName())
                .visibility(request.getVisibility())
                .isDraft(request.getIsDraft())
                .build());

        List<RouteMapSpot> spots = saveRouteSpots(routeMap, request.getSpotIds());
        return toResponse(routeMap, spots, 0, 0, false, false);
    }

    /** 공개 코스 전체 목록(최신순) — 로그인 없이도 조회 가능. 발행 안 된 초안(isDraft=true)은 제외. */
    public List<RouteResponse> listPublic() {
        List<RouteMap> routeMaps = routeMapRepository.findByVisibilityAndIsDraftFalseOrderByCreatedAtDesc("PUBLIC");
        if (routeMaps.isEmpty()) return List.of();

        List<Long> routeMapIds = routeMaps.stream().map(RouteMap::getId).toList();
        Map<Long, List<RouteMapSpot>> spotsByRouteMapId = groupSpotsByRouteMapId(routeMapIds);
        Map<Long, Integer> likeCountByRouteMapId = toCountMap(routeLikeRepository.countByRouteMapIds(routeMapIds));
        Map<Long, Integer> saveCountByRouteMapId = toCountMap(routeSaveRepository.countByRouteMapIds(routeMapIds));

        // 비로그인 조회라 liked/saved는 항상 false — 로그인 유저 관점이 필요하면 상세(getById)를 쓰면 된다.
        return routeMaps.stream()
                .map(r -> toResponse(
                        r,
                        spotsByRouteMapId.getOrDefault(r.getId(), List.of()),
                        likeCountByRouteMapId.getOrDefault(r.getId(), 0),
                        saveCountByRouteMapId.getOrDefault(r.getId(), 0),
                        false,
                        false))
                .toList();
    }

    /** 코스 공유 — 좋아요/저장과 달리 토글이 아니라 호출될 때마다 shareCount를 1씩 늘린다. */
    @Transactional
    public int increaseShareCount(Long routeId) {
        RouteMap routeMap = routeMapRepository.findById(routeId)
                .orElseThrow(() -> new IllegalArgumentException("코스를 찾을 수 없습니다."));
        routeMap.increaseShareCount();
        return routeMap.getShareCount();
    }

    /** 내가 만든 코스 목록(최신순). */
    public List<RouteResponse> listMine(Long userId) {
        List<RouteMap> routeMaps = routeMapRepository.findByUser_IdOrderByCreatedAtDesc(userId);
        if (routeMaps.isEmpty()) return List.of();

        List<Long> routeMapIds = routeMaps.stream().map(RouteMap::getId).toList();
        Map<Long, List<RouteMapSpot>> spotsByRouteMapId = groupSpotsByRouteMapId(routeMapIds);
        Map<Long, Integer> likeCountByRouteMapId = toCountMap(routeLikeRepository.countByRouteMapIds(routeMapIds));
        Map<Long, Integer> saveCountByRouteMapId = toCountMap(routeSaveRepository.countByRouteMapIds(routeMapIds));
        Set<Long> likedRouteMapIds = new HashSet<>(routeLikeRepository.findLikedRouteMapIds(userId, routeMapIds));
        Set<Long> savedRouteMapIds = new HashSet<>(routeSaveRepository.findSavedRouteMapIds(userId, routeMapIds));

        return routeMaps.stream()
                .map(r -> toResponse(
                        r,
                        spotsByRouteMapId.getOrDefault(r.getId(), List.of()),
                        likeCountByRouteMapId.getOrDefault(r.getId(), 0),
                        saveCountByRouteMapId.getOrDefault(r.getId(), 0),
                        likedRouteMapIds.contains(r.getId()),
                        savedRouteMapIds.contains(r.getId())))
                .toList();
    }

    /**
     * 코스 상세. visibility가 PRIVATE인 코스는 작성자 본인만 볼 수 있고, 그 외에는
     * 존재 자체를 감추기 위해 "찾을 수 없습니다" 취급한다(정보 노출 방지).
     * viewerUserId가 null(비로그인)이어도 PUBLIC 코스는 조회 가능.
     */
    public RouteResponse getById(Long routeId, Long viewerUserId) {
        RouteMap routeMap = routeMapRepository.findById(routeId)
                .orElseThrow(() -> new IllegalArgumentException("코스를 찾을 수 없습니다."));

        boolean isOwner = viewerUserId != null && routeMap.getUser().getId().equals(viewerUserId);
        if ("PRIVATE".equals(routeMap.getVisibility()) && !isOwner) {
            throw new IllegalArgumentException("코스를 찾을 수 없습니다.");
        }

        List<RouteMapSpot> spots = routeMapSpotRepository.findByRouteMap_IdOrderBySortOrderAsc(routeId);
        int likeCount = (int) routeLikeRepository.countByRouteMap_Id(routeId);
        int saveCount = (int) routeSaveRepository.countByRouteMap_Id(routeId);
        boolean liked = viewerUserId != null
                && routeLikeRepository.findByUser_IdAndRouteMap_Id(viewerUserId, routeId).isPresent();
        boolean saved = viewerUserId != null
                && routeSaveRepository.findByUser_IdAndRouteMap_Id(viewerUserId, routeId).isPresent();

        return toResponse(routeMap, spots, likeCount, saveCount, liked, saved);
    }

    /** 이름/스팟 목록/공개범위 수정 — 작성자 본인만 가능. 스팟 목록은 통째로 교체한다. */
    @Transactional
    public RouteResponse update(Long userId, Long routeId, RouteRequest request) {
        RouteMap routeMap = routeMapRepository.findById(routeId)
                .orElseThrow(() -> new IllegalArgumentException("코스를 찾을 수 없습니다."));
        if (!routeMap.getUser().getId().equals(userId)) {
            throw new ForbiddenException("본인이 만든 코스만 수정할 수 있습니다.");
        }

        routeMap.update(request.getName(), request.getVisibility(), request.getIsDraft());
        routeMapSpotRepository.deleteByRouteMap_Id(routeId);
        List<RouteMapSpot> spots = saveRouteSpots(routeMap, request.getSpotIds());

        int likeCount = (int) routeLikeRepository.countByRouteMap_Id(routeId);
        int saveCount = (int) routeSaveRepository.countByRouteMap_Id(routeId);
        boolean liked = routeLikeRepository.findByUser_IdAndRouteMap_Id(userId, routeId).isPresent();
        boolean saved = routeSaveRepository.findByUser_IdAndRouteMap_Id(userId, routeId).isPresent();
        return toResponse(routeMap, spots, likeCount, saveCount, liked, saved);
    }

    /** 코스 삭제 — 작성자 본인만 가능. FK 제약 때문에 스팟/좋아요/저장을 먼저 지운다. */
    @Transactional
    public void delete(Long userId, Long routeId) {
        RouteMap routeMap = routeMapRepository.findById(routeId)
                .orElseThrow(() -> new IllegalArgumentException("코스를 찾을 수 없습니다."));
        if (!routeMap.getUser().getId().equals(userId)) {
            throw new ForbiddenException("본인이 만든 코스만 삭제할 수 있습니다.");
        }

        routeMapSpotRepository.deleteByRouteMap_Id(routeId);
        routeLikeRepository.deleteByRouteMap_Id(routeId);
        routeSaveRepository.deleteByRouteMap_Id(routeId);
        routeMapRepository.delete(routeMap);
    }

    /** 코스 좋아요 토글 — 이미 눌렀으면 취소, 아니면 새로 누른다. */
    @Transactional
    public LikeToggleResponse toggleLike(Long userId, Long routeId) {
        RouteMap routeMap = routeMapRepository.findById(routeId)
                .orElseThrow(() -> new IllegalArgumentException("코스를 찾을 수 없습니다."));

        var existing = routeLikeRepository.findByUser_IdAndRouteMap_Id(userId, routeId);
        boolean liked;
        if (existing.isPresent()) {
            routeLikeRepository.delete(existing.get());
            liked = false;
        } else {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
            routeLikeRepository.save(RouteLike.builder().user(user).routeMap(routeMap).build());
            liked = true;
        }
        int likeCount = (int) routeLikeRepository.countByRouteMap_Id(routeId);
        return LikeToggleResponse.builder().liked(liked).likeCount(likeCount).build();
    }

    /** 코스 저장(북마크) 토글 — 이미 저장했으면 취소, 아니면 새로 저장한다. */
    @Transactional
    public SaveToggleResponse toggleSave(Long userId, Long routeId) {
        RouteMap routeMap = routeMapRepository.findById(routeId)
                .orElseThrow(() -> new IllegalArgumentException("코스를 찾을 수 없습니다."));

        var existing = routeSaveRepository.findByUser_IdAndRouteMap_Id(userId, routeId);
        boolean saved;
        if (existing.isPresent()) {
            routeSaveRepository.delete(existing.get());
            saved = false;
        } else {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
            routeSaveRepository.save(RouteSave.builder().user(user).routeMap(routeMap).build());
            saved = true;
        }
        int saveCount = (int) routeSaveRepository.countByRouteMap_Id(routeId);
        return SaveToggleResponse.builder().saved(saved).saveCount(saveCount).build();
    }

    /** spotIds 순서 그대로 RouteMapSpot을 만들어 저장한다(sortOrder = 배열 인덱스). */
    private List<RouteMapSpot> saveRouteSpots(RouteMap routeMap, List<Long> spotIds) {
        if (spotIds == null || spotIds.isEmpty()) return List.of();

        List<RouteMapSpot> spots = new ArrayList<>();
        for (int i = 0; i < spotIds.size(); i++) {
            Long spotId = spotIds.get(i);
            Spot spot = spotRepository.findById(spotId)
                    .orElseThrow(() -> new IllegalArgumentException("스팟을 찾을 수 없습니다: " + spotId));
            spots.add(routeMapSpotRepository.save(RouteMapSpot.builder()
                    .routeMap(routeMap)
                    .spot(spot)
                    .sortOrder(i)
                    .build()));
        }
        return spots;
    }

    /** 여러 코스의 스팟을 한 번에 조회해 routeMapId 기준으로 묶는다(N+1 방지). */
    private Map<Long, List<RouteMapSpot>> groupSpotsByRouteMapId(List<Long> routeMapIds) {
        return routeMapSpotRepository.findByRouteMap_IdInOrderByRouteMap_IdAscSortOrderAsc(routeMapIds)
                .stream()
                .collect(Collectors.groupingBy(s -> s.getRouteMap().getId(), LinkedHashMap::new, Collectors.toList()));
    }

    private Map<Long, Integer> toCountMap(List<Object[]> rows) {
        Map<Long, Integer> result = new HashMap<>();
        for (Object[] row : rows) {
            Long id = (Long) row[0];
            int count = ((Number) row[1]).intValue();
            result.put(id, count);
        }
        return result;
    }

    private RouteResponse toResponse(RouteMap routeMap, List<RouteMapSpot> spots,
                                      int likeCount, int saveCount, boolean liked, boolean saved) {
        List<RouteSpotResponse> spotResponses = spots.stream()
                .map(rms -> {
                    Spot spot = rms.getSpot();
                    return RouteSpotResponse.builder()
                            .spotId(spot.getId())
                            .title(spot.getTitleKo())
                            .lat(spot.getLat())
                            .lng(spot.getLng())
                            .imageUrl(spot.getImageUrl())
                            .order(rms.getSortOrder())
                            .build();
                })
                .toList();

        return RouteResponse.builder()
                .id(routeMap.getId())
                .userNickname(routeMap.getUser().getNickname())
                .name(routeMap.getTitle())
                .visibility(routeMap.getVisibility())
                .isDraft(Boolean.TRUE.equals(routeMap.getIsDraft()))
                .spots(spotResponses)
                .likeCount(likeCount)
                .saveCount(saveCount)
                .shareCount(routeMap.getShareCount())
                .liked(liked)
                .saved(saved)
                .createdAt(routeMap.getCreatedAt())
                .build();
    }
}
