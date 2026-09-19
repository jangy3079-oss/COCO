package com.coco.backend.repository;

import com.coco.backend.entity.RouteLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RouteLikeRepository extends JpaRepository<RouteLike, Long> {

    // 찜 토글 시 이미 좋아요했는지 확인용
    Optional<RouteLike> findByUser_IdAndRouteMap_Id(Long userId, Long routeMapId);

    // 코스 단건 조회 시 좋아요 개수 집계용
    long countByRouteMap_Id(Long routeMapId);

    // 코스 삭제(RouteService.delete) 시 FK 제약 때문에 코스보다 먼저 지워야 함
    void deleteByRouteMap_Id(Long routeMapId);

    // "내가 만든 코스" 목록 등 여러 코스를 한 번에 조회할 때 좋아요 개수를 한 쿼리로 집계(N+1 방지)
    @Query("SELECT rl.routeMap.id, COUNT(rl) FROM RouteLike rl WHERE rl.routeMap.id IN :routeMapIds GROUP BY rl.routeMap.id")
    List<Object[]> countByRouteMapIds(@Param("routeMapIds") List<Long> routeMapIds);

    // 위와 동일한 목적으로, 로그인한 유저가 그중 어떤 코스에 좋아요를 눌렀는지 한 번에 조회
    @Query("SELECT rl.routeMap.id FROM RouteLike rl WHERE rl.user.id = :userId AND rl.routeMap.id IN :routeMapIds")
    List<Long> findLikedRouteMapIds(@Param("userId") Long userId, @Param("routeMapIds") List<Long> routeMapIds);
}
