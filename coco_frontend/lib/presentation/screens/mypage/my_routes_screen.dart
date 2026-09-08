import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/map/kakao_map_view.dart';
import '../map/map_mock_data.dart';

/// "내가 만든 코스" 화면 — MY탭 메뉴 및 상단 지도 모듈에서 진입.
/// (구 "나의 지도" 화면과 "내가 만든 골목지도" 화면을 하나로 통합함)
/// 리스트 탭에서는 mockMyRoutes(내가 만든 코스)를 보여주고, 카드를 펼치면
/// 스팟 순서 또는 미니맵(지도에서 보기)을 바로 확인할 수 있다. 지도 탭에서는
/// 내가 찜한 스팟 전체를 지도 위에서 한눈에 볼 수 있다(구 "나의 지도" 기능).
/// "저장 · 좋아요"의 "저장한 코스" 탭(다른 사람이 만든 코스를 저장한 목록)과는
/// 별개로, 여기는 내가 직접 만든 코스만 다룬다.
class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

enum _RouteViewMode { list, map }

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  String _tab = 'list'; // list | map (상단 리스트/지도 탭)
  String? _expandedRouteId;
  final Map<String, _RouteViewMode> _viewModes = {};

  Future<void> _createNew() async {
    await context.push('/map/route/new');
    if (mounted) setState(() {});
  }

  Future<void> _editRoute(MockRoute route) async {
    await context.push(
      '/map/route/new',
      extra: {'editingRouteId': route.id, 'initialName': route.name, 'initialStops': route.stops},
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final routes = mockMyRoutes;
    final likedSpots = mockSpots.where((s) => savedSpotIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('내가 만든 코스', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _TabChip(label: '리스트', selected: _tab == 'list', onTap: () => setState(() => _tab = 'list')),
                  const SizedBox(width: 8),
                  _TabChip(label: '지도', selected: _tab == 'map', onTap: () => setState(() => _tab = 'map')),
                  const Spacer(),
                  Text(
                    _tab == 'map' ? '찜한 스팟 ${likedSpots.length}곳' : '코스 ${routes.length}개',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == 'map'
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: likedSpots.isEmpty
                            ? _EmptyLikedMap(onGoToMap: () => context.go('/map'))
                            : Builder(builder: (context) {
                                final center = spotsCenter(likedSpots);
                                return KakaoMapView(
                                  centerLat: center.$1,
                                  centerLng: center.$2,
                                  level: 6,
                                  markers: [
                                    for (final s in likedSpots) KakaoMapMarker(id: s.id, lat: s.lat, lng: s.lng, name: s.name),
                                  ],
                                  onMarkerTap: (spotId) => context.push('/map/spot/$spotId'),
                                );
                              }),
                      ),
                    )
                  : routes.isEmpty
                      ? Center(
                          child: Text('아직 만든 코스가 없어요\n지도 탭에서 스팟을 담아 코스를 만들어보세요',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade500)),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          children: [
                            for (final r in routes) ...[
                              _RouteCard(
                                route: r,
                                expanded: _expandedRouteId == r.id,
                                viewMode: _viewModes[r.id] ?? _RouteViewMode.list,
                                onToggleExpanded: () => setState(() {
                                  _expandedRouteId = _expandedRouteId == r.id ? null : r.id;
                                }),
                                onViewModeChanged: (m) => setState(() => _viewModes[r.id] = m),
                                onEdit: () => _editRoute(r),
                                onViewOnMap: () => context.push('/map/route/preview', extra: {
                                  'name': r.name,
                                  'stops': r.stops,
                                  'routeId': r.id,
                                  'isOwner': true,
                                }),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _NewRouteButton(onTap: _createNew),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.secondary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? CocoTheme.secondary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary)),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final MockRoute route;
  final bool expanded;
  final _RouteViewMode viewMode;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_RouteViewMode> onViewModeChanged;
  final VoidCallback onEdit;
  final VoidCallback onViewOnMap;

  const _RouteCard({
    required this.route,
    required this.expanded,
    required this.viewMode,
    required this.onToggleExpanded,
    required this.onViewModeChanged,
    required this.onEdit,
    required this.onViewOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _RouteThumb(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(route.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                            ),
                            const SizedBox(width: 6),
                            _VisibilityBadge(isPublic: route.isPublic),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '스팟 ${route.stops.length}곳 · ${route.distanceKm.toStringAsFixed(1)}km',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          route.isPublic
                              ? '좋아요 ${route.likes} · 저장 ${route.saves} · 공유 ${route.shares}'
                              : route.isDraft
                                  ? '나만 보기 · 작성 중'
                                  : '나만 보기',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: viewMode == _RouteViewMode.map
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 140,
                        child: IgnorePointer(
                          child: Builder(builder: (context) {
                            final center = spotsCenter(route.stops);
                            return KakaoMapView(
                              centerLat: center.$1,
                              centerLng: center.$2,
                              level: 6,
                              markers: [
                                for (final s in route.stops) KakaoMapMarker(id: s.id, lat: s.lat, lng: s.lng, name: s.name),
                              ],
                            );
                          }),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < route.stops.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                                ),
                                Expanded(
                                  child: Text(route.stops[i].name, style: const TextStyle(fontSize: 13, color: CocoTheme.secondary)),
                                ),
                                Text(route.stops[i].dong, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(child: _SegmentButton(label: '편집', selected: false, onTap: onEdit)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentButton(
                      label: '지도에서 보기',
                      selected: viewMode == _RouteViewMode.map,
                      onTap: () => onViewModeChanged(
                        viewMode == _RouteViewMode.map ? _RouteViewMode.list : _RouteViewMode.map,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentButton(
                      label: '코스 상세',
                      selected: false,
                      onTap: onViewOnMap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 왼쪽의 장식용 미니 썸네일 — 실제 지도 대신 코스를 상징하는 작은 핀 2개만 표시.
class _RouteThumb extends StatelessWidget {
  const _RouteThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: const Color(0xFFEAE8E2), borderRadius: BorderRadius.circular(10)),
      child: Stack(
        children: [
          Positioned(left: 10, top: 8, child: Icon(Icons.location_on_rounded, size: 16, color: CocoTheme.primary)),
          Positioned(right: 10, bottom: 8, child: Icon(Icons.location_on_rounded, size: 16, color: CocoTheme.primary)),
        ],
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  final bool isPublic;
  const _VisibilityBadge({required this.isPublic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPublic ? const Color(0xFFE6F1FB) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isPublic ? '전체 공유' : '나만 보기',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isPublic ? CocoTheme.primary : Colors.grey.shade600),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary)),
      ),
    );
  }
}

/// 지도 탭에서 찜한 스팟이 하나도 없을 때 보여주는 빈 상태 (구 my_map_screen.dart의 _EmptyMap).
class _EmptyLikedMap extends StatelessWidget {
  final VoidCallback onGoToMap;
  const _EmptyLikedMap({required this.onGoToMap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAE8E2),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('아직 찜한 스팟이 없어요', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text('지도 탭에서 스팟을 찜해보세요', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CocoTheme.primary),
              onPressed: onGoToMap,
              child: const Text('지도로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewRouteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewRouteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Text('+ 새 코스 만들기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
      ),
    );
  }
}
