import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../map/map_mock_data.dart';
import '../map/map_screen.dart' show MockMapBackground;

/// "내가 만든 골목지도" 화면 — MY탭 메뉴에서 진입.
/// mockMyRoutes(내가 만든 코스)를 리스트로 보여주고, 카드를 펼치면
/// 스팟 순서(미리보기) 또는 미니맵(지도에서 보기)을 바로 확인할 수 있다.
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
    final totalSpots = routes.fold<int>(0, (sum, r) => sum + r.stops.length);

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
                    child: Text('내가 만든 골목지도', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
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
                  Text('${routes.length}개 · 스팟 ${totalSpots}곳', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Expanded(
              child: _tab == 'map'
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MockMapBackground(
                          spots: [for (final r in routes) ...r.stops],
                          onSpotTap: (_) {},
                        ),
                      ),
                    )
                  : routes.isEmpty
                      ? Center(
                          child: Text('아직 만든 골목지도가 없어요\n지도 탭에서 스팟을 담아 코스를 만들어보세요',
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
                                onViewOnMap: () => context.push('/map/route/preview', extra: {'name': r.name, 'stops': r.stops}),
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
                        child: IgnorePointer(child: MockMapBackground(spots: route.stops, onSpotTap: (_) {})),
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
                      onTap: () => onViewModeChanged(_RouteViewMode.map),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentButton(
                      label: '미리보기',
                      selected: viewMode == _RouteViewMode.list,
                      onTap: () => onViewModeChanged(_RouteViewMode.list),
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
        child: Text('+ 새 골목지도 만들기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
      ),
    );
  }
}
