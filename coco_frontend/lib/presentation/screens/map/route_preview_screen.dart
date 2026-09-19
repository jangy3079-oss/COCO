import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/route_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/map/kakao_map_view.dart';
import 'map_mock_data.dart';

/// 코스 상세 화면. "내가 만든 코스"·피드의 "코스 보기"·"저장한 코스"
/// 등 여러 진입점에서 공통으로 쓴다.
/// isOwner가 true일 때만(=내가 만든 코스일 때만) 편집·공유가 가능하다 —
/// 다른 사람이 만든 코스를 저장만 해둔 경우(저장한 코스)는 볼 수만 있다.
/// "지도에서 보기"를 누르면 지도 탭으로 돌아간다.
/// TODO: 백엔드 연동 시 실제로는 이 시점에 코스가 서버에 저장되고,
/// 피드 탭에서도 좋아요/저장 랭킹으로 노출된다 (기획 문서 참고).
class RoutePreviewScreen extends StatefulWidget {
  final String routeName;
  final List<MockSpot> stops;
  final String? routeId; // mockMyRoutes 안의 id — 편집 화면 진입 시 필요
  final bool isOwner; // 내가 만든 코스인지 — 편집/공유 노출 여부를 가른다
  const RoutePreviewScreen({
    super.key,
    required this.routeName,
    required this.stops,
    this.routeId,
    this.isOwner = true,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final _routeRepository = RouteRepository();
  bool _liked = false;
  bool _saved = false;
  int _likeCount = 0;
  int _saveCount = 0;

  int? get _numericRouteId {
    final id = widget.routeId;
    return id == null ? null : dbRouteNumericId(id);
  }

  @override
  void initState() {
    super.initState();
    final numId = _numericRouteId;
    if (numId != null) _loadDetail(numId);
  }

  Future<void> _loadDetail(int numId) async {
    try {
      final route = await _routeRepository.getById(numId);
      if (route.saved) {
        savedRouteCache[numId] = route;
      } else {
        savedRouteCache.remove(numId);
      }
      if (!mounted) return;
      setState(() {
        _liked = route.liked;
        _saved = route.saved;
        _likeCount = route.likeCount;
        _saveCount = route.saveCount;
      });
    } catch (e) {
      debugPrint('[RoutePreviewScreen] 코스 상세 조회 실패: $e');
    }
  }

  Future<void> _toggleLike() async {
    final numId = _numericRouteId;
    if (numId == null) return;
    if (!requireLogin(context)) return;
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      final result = await _routeRepository.toggleLike(numId);
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        debugPrint('[RoutePreviewScreen] 좋아요 토글 실패: $e');
      }
    }
  }

  Future<void> _toggleSave() async {
    final numId = _numericRouteId;
    if (numId == null) return;
    if (!requireLogin(context)) return;
    final wasSaved = _saved;
    setState(() {
      _saved = !wasSaved;
      _saveCount += _saved ? 1 : -1;
    });
    try {
      final result = await toggleRouteSave(numId);
      if (!mounted) return;
      setState(() {
        _saved = result.saved;
        _saveCount = result.saveCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saved = wasSaved;
        _saveCount += wasSaved ? 1 : -1;
      });
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        debugPrint('[RoutePreviewScreen] 저장 토글 실패: $e');
      }
    }
  }

  Future<void> _share() async {
    final numId = _numericRouteId;
    if (numId != null) {
      try {
        await _routeRepository.share(numId);
      } catch (e) {
        debugPrint('[RoutePreviewScreen] 공유 카운트 반영 실패: $e');
      }
    }
    if (!mounted) return;
    context.push('/feed/compose-route', extra: {
      'name': widget.routeName,
      'stops': widget.stops,
      'routeId': widget.routeId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stops = widget.stops;
    final distanceKm = (stops.length * 0.3).toStringAsFixed(1);
    final durationMin = stops.length * 10;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverHeader(
              stops: stops,
              onBack: () => context.pop(),
              onEdit: widget.isOwner && widget.routeId != null
                  ? () => context.push('/map/route/new', extra: {
                        'editingRouteId': widget.routeId,
                        'initialName': widget.routeName,
                        'initialStops': widget.stops,
                      })
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.routeName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFF0ECE6),
                        child: Text(l10n.feedMeAvatarLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.feedRouteSummaryAuthorLine(l10n.feedMeAvatarLabel), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.routePreviewStats(stops.length, distanceKm, durationMin),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CountPillButton(
                          label: l10n.routePreviewLikeLabel,
                          count: _likeCount,
                          active: _liked,
                          activeColor: CocoTheme.primary,
                          onTap: _toggleLike,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CountPillButton(
                          label: l10n.feedSaveButtonUnsaved,
                          count: _saveCount,
                          active: _saved,
                          activeColor: CocoTheme.secondary,
                          onTap: _toggleSave,
                        ),
                      ),
                      if (widget.isOwner) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CountPillButton(
                            label: l10n.routePreviewShareLabel,
                            count: null,
                            active: false,
                            activeColor: CocoTheme.secondary,
                            onTap: _share,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  for (int i = 0; i < stops.length; i++)
                    _TimelineStop(
                      order: i + 1,
                      spot: stops[i],
                      isLast: i == stops.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CocoTheme.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              // 지도 탭에 이 코스의 스팟만 보여달라고 알려준 뒤 이동한다.
              courseMapFilter.value = CourseMapFilter(
                routeName: widget.routeName,
                spots: widget.stops,
              );
              context.go('/map');
            },
            child: Text(l10n.myRoutesViewOnMapButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  final List<MockSpot> stops;
  final VoidCallback onBack;
  final VoidCallback? onEdit; // null이면(=작성자가 아니면) 편집 버튼 자체를 숨긴다
  const _CoverHeader({required this.stops, required this.onBack, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // 코스 대표 "사진" 대신, 이 코스의 스팟들을 순서 번호 핀으로 보여주는
          // 실제 지도로 채운다(map_screen.dart 코스 필터 화면과 동일한 스타일).
          // 캐러셀이 아니라 그냥 배경이라 조작할 필요가 없어서, 투명 위젯을 한 겹
          // 덮어 실제 지도 DOM 클릭(드래그·카카오 로고 링크 등)을 막는다.
          Positioned.fill(
            child: stops.isEmpty
                ? Container(
                    color: CocoTheme.primary.withOpacity(0.10),
                    alignment: Alignment.center,
                    child: Icon(Icons.photo_camera_outlined, size: 40, color: CocoTheme.primary.withOpacity(0.4)),
                  )
                : Builder(builder: (context) {
                    final center = spotsCenter(stops);
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: KakaoMapView(
                            centerLat: center.$1,
                            centerLng: center.$2,
                            level: 6,
                            clusteringEnabled: false,
                            markers: [
                              for (final (i, spot) in stops.indexed)
                                KakaoMapMarker(id: spot.id, lat: spot.lat, lng: spot.lng, name: spot.name, order: i + 1),
                            ],
                          ),
                        ),
                        const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
                      ],
                    );
                  }),
          ),
          Positioned(
            left: 16,
            top: 44,
            child: Material(
              color: Colors.white.withOpacity(0.9),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.arrow_back_rounded, size: 18, color: CocoTheme.secondary),
                ),
              ),
            ),
          ),
          if (onEdit != null)
            Positioned(
              right: 16,
              top: 44,
              child: Material(
                color: Colors.white.withOpacity(0.9),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onEdit,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.edit_outlined, size: 18, color: CocoTheme.secondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountPillButton extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _CountPillButton({
    required this.label,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? activeColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Text(
          count == null ? label : '$label · $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : CocoTheme.secondary,
          ),
        ),
      ),
    );
  }
}

class _TimelineStop extends StatelessWidget {
  final int order;
  final MockSpot spot;
  final bool isLast;

  const _TimelineStop({required this.order, required this.spot, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: CocoTheme.primary, shape: BoxShape.circle),
                child: Text('$order', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade200),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: spot.pinColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(spot.icon, color: spot.pinColor.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                        const SizedBox(height: 2),
                        Text(spot.subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
