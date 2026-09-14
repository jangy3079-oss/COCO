import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/map/kakao_map_view.dart';
import '../map/map_mock_data.dart';

/// "나의 골목지도"(찜한 스팟 전체를 보여주는 지도) / "코스"(내가 만든 코스) 통합 화면.
/// MY탭 상단 모듈·메뉴에서 진입하며, initialTab으로 기본 탭을 정한다(상단 모듈은 골목지도,
/// "내가 만든 코스" 메뉴는 코스가 기본).
/// 지도 탭(map_screen.dart)과 동일하게 전체화면 지도 위에 블러 헤더가 뜨는 스타일로 통일했다
/// — 예전엔 작은 패딩 박스 안에 지도가 들어있는 형태였다.
class MyRoutesScreen extends StatefulWidget {
  final String initialTab; // 'alley'(나의 골목지도) | 'course'(코스)
  const MyRoutesScreen({super.key, this.initialTab = 'alley'});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

enum _RouteViewMode { list, map }

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  late String _tab = widget.initialTab;
  String? _expandedRouteId;
  final Map<String, _RouteViewMode> _viewModes = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _switchTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _query = '';
      _searchController.clear();
    });
  }

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
    final isAlley = _tab == 'alley';
    final query = _query.trim();

    final likedSpots = mockSpots.where((s) => savedSpotIds.contains(s.id)).toList();
    final filteredSpots = query.isEmpty ? likedSpots : likedSpots.where((s) => s.name.contains(query)).toList();

    final routes = mockMyRoutes;
    final filteredRoutes = query.isEmpty ? routes : routes.where((r) => r.name.contains(query)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 본문 — 골목지도 탭은 전체화면 지도, 코스 탭은 리스트. 둘 다 위에 블러 헤더가 뜬다.
          Positioned.fill(
            child: isAlley
                ? (filteredSpots.isEmpty
                    ? _EmptyLikedMap(onGoToMap: () => context.go('/map'))
                    : Builder(builder: (context) {
                        final center = spotsCenter(filteredSpots);
                        return KakaoMapView(
                          centerLat: center.$1,
                          centerLng: center.$2,
                          level: 6,
                          markers: [
                            for (final s in filteredSpots) KakaoMapMarker(id: s.id, lat: s.lat, lng: s.lng, name: s.name),
                          ],
                          onMarkerTap: (spotId) => context.push('/map/spot/$spotId'),
                        );
                      }))
                : (filteredRoutes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 200),
                        child: Center(
                          child: Text(
                            routes.isEmpty ? '아직 만든 코스가 없어요\n지도 탭에서 스팟을 담아 코스를 만들어보세요' : '검색 결과가 없어요',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade500),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 200, 20, 20),
                        children: [
                          for (final r in filteredRoutes) ...[
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
                      )),
          ),
          // 타이틀 자리에 탭 전환(나의 골목지도/코스) + 부제목 + 검색창 — 지도탭과 동일한
          // 블러 그라데이션 헤더. 카카오맵(HtmlElementView) 바로 위에 뜨는 인터랙티브
          // 위젯이라 PointerInterceptor로 감싸야 탭/검색 입력이 지도로 새지 않는다
          // (map_screen.dart의 검색 드롭다운·하단 시트와 동일한 이유).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: PointerInterceptor(
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.68, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.6, 1.0],
                          colors: [
                            Colors.white.withOpacity(0.96),
                            Colors.white.withOpacity(0.78),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                                  const SizedBox(width: 2),
                                  _HeaderTabLabel(label: '나의 골목지도', selected: isAlley, onTap: () => _switchTab('alley')),
                                  const SizedBox(width: 14),
                                  _HeaderTabLabel(label: '코스', selected: !isAlley, onTap: () => _switchTab('course')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  isAlley ? '찜한 스팟 ${likedSpots.length}곳을 지도에서 확인하세요' : '내가 만든 코스 ${routes.length}개',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: _RoutesSearchBar(
                                  controller: _searchController,
                                  hintText: isAlley ? '찜한 스팟 검색...' : '코스 검색...',
                                  onChanged: (v) => setState(() => _query = v),
                                  onClear: () => setState(() {
                                    _query = '';
                                    _searchController.clear();
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 헤더의 "나의 골목지도"/"코스" 탭 라벨. 레퍼런스(인연/통화)처럼 선택된 쪽은 진하게 검정,
/// 선택 안 된 쪽은 회색 — 배경/테두리 없이 텍스트 색·굵기로만 구분한다.
class _HeaderTabLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _HeaderTabLabel({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 22,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? CocoTheme.secondary : Colors.grey.shade400,
        ),
      ),
    );
  }
}

/// map_screen.dart의 _MapSearchBar와 동일한 스타일 — hint 문구만 탭에 따라 달라진다
/// (라이브러리 프라이빗이라 그대로 재사용이 안 돼서 동일한 모양으로 새로 둠).
class _RoutesSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _RoutesSearchBar({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                  onPressed: onClear,
                ),
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
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

/// 골목지도 탭에서 찜한 스팟이 하나도 없을 때 보여주는 빈 상태.
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
