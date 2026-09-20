import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/route_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/map/kakao_map_view.dart';
import 'map_mock_data.dart';

/// 골목지도(코스) 만들기 화면.
/// 지도 탭에서 북마크한 스팟들을 순서를 정해 하나의 코스로 묶는다.
class RouteBuilderScreen extends StatefulWidget {
  final List<MockSpot> initialStops;
  final String? editingRouteId; // non-null이면 신규 생성이 아니라 기존 코스 수정 모드
  final String initialName;
  const RouteBuilderScreen({
    super.key,
    this.initialStops = const [],
    this.editingRouteId,
    this.initialName = '',
  });

  @override
  State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen> {
  late final List<MockSpot> _stops = List.of(widget.initialStops);
  late final _nameController = TextEditingController(text: widget.initialName);

  // "+ 스팟 추가" 검색 팝업 — 화면 전환 없이 이 화면 위에 오버레이로 뜬다
  // (재생목록에 곡 담듯 검색창을 유지한 채 연속으로 여러 스팟을 담을 수 있게).
  // 코스는 "내가 찜해둔 스팟"들을 묶어 만드는 것이라, 후보 목록은 항상
  // savedSpots(찜한 스팟)로 제한한다 — 전체 DB 스팟 검색이 아니다.
  bool _searchOpen = false;
  String _searchQuery = '';
  String? _toastMessage;
  Timer? _toastTimer;
  // 이번 검색 세션에서 새로 담은 스팟 id들 — "취소"를 누르면 이번 세션에서
  // 추가한 것만 되돌리고(원래 있던 스팟은 그대로 두고), "완료"를 누르면 그대로
  // 확정한다. 예전엔 닫기 버튼이 하나뿐이라 그게 사실상 "완료"처럼 동작했었다.
  final Set<String> _addedDuringSearch = {};
  final _routeRepository = RouteRepository();
  bool _saving = false;
  bool _saveCompleted = false;
  bool _loadingSavedSpots = false;

  @override
  void dispose() {
    _nameController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _openSearch() async {
    if (_loadingSavedSpots) return;
    setState(() => _loadingSavedSpots = true);
    await refreshLikedSpots(
      locale: context.read<LocaleController>().locale.languageCode,
    );
    if (!mounted) return;
    setState(() {
      _loadingSavedSpots = false;
      _searchOpen = true;
      _addedDuringSearch.clear();
    });
  }

  // 취소 — 이번 검색 세션에서 새로 담은 스팟만 되돌리고 닫는다.
  void _cancelSearch() => setState(() {
        _stops.removeWhere((s) => _addedDuringSearch.contains(s.id));
        _addedDuringSearch.clear();
        _searchOpen = false;
        _searchQuery = '';
      });

  // 완료 — 담은 내용을 그대로 확정하고 닫는다.
  void _confirmSearch() => setState(() {
        _addedDuringSearch.clear();
        _searchOpen = false;
        _searchQuery = '';
      });

  void _onSearchQueryChanged(String query) =>
      setState(() => _searchQuery = query);

  void _addStopFromSearch(MockSpot spot) {
    if (_stops.any((s) => s.id == spot.id)) return;
    _toastTimer?.cancel();
    setState(() {
      _stops.add(spot);
      _addedDuringSearch.add(spot.id);
      _toastMessage =
          AppLocalizations.of(context)!.routeBuilderSpotAddedToast(spot.name);
    });
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      final moved = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, moved);
    });
  }

  void _remove(int i) => setState(() => _stops.removeAt(i));

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.routeBuilderNameRequiredWarning)),
      );
      return;
    }
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .routeBuilderStopsRequiredWarning)),
      );
      return;
    }
    if (!requireLogin(context)) return;
    if (_saving || _saveCompleted) return;

    final name = _nameController.text.trim();
    // 스팟 추가 검색이 찜한 스팟(savedSpots, 전부 'db-' id)으로 제한돼 있어(#147) 전부
    // 실제 DB 스팟 id로 변환된다 — whereType은 혹시 모를 데모 스팟 방어용.
    final spotIds =
        _stops.map((s) => dbSpotNumericId(s.id)).whereType<int>().toList();
    final editingId = widget.editingRouteId;

    setState(() => _saving = true);
    try {
      final int backendId;
      if (editingId != null) {
        final numId = dbRouteNumericId(editingId);
        if (numId == null) return;
        final result =
            await _routeRepository.update(numId, name: name, spotIds: spotIds);
        backendId = result.id;
      } else {
        final result =
            await _routeRepository.create(name: name, spotIds: spotIds);
        backendId = result.id;
      }
      await refreshMyRoutes();
      if (!mounted) return;
      _saveCompleted = true;
      // push가 아니라 pushReplacement — 코스 작성 화면을 스택에서 제거해야
      // 미리보기에서 뒤로가기 했을 때 작성 화면(같은 코스로 완료를 또 누르면
      // 중복 생성되던 화면)으로 안 돌아가고 코스 목록으로 바로 돌아간다.
      context.pushReplacement('/map/route/preview', extra: {
        'name': name,
        'stops': _stops,
        'routeId': 'route-$backendId',
        'isOwner': true,
      });
    } catch (e) {
      debugPrint('[RouteBuilderScreen] 코스 저장 실패: $e');
      if (!mounted) return;
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.routeBuilderSaveFailedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          widget.editingRouteId != null
                              ? l10n.routeBuilderEditTitle(widget.initialName)
                              : l10n.routeBuilderCreateTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CocoTheme.secondary),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _RouteMiniMap(stops: _stops),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.routeBuilderNameLabel,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: CocoTheme.secondary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: l10n.routeBuilderNameHint,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.fromLTRB(0, 10, 0, 12),
                                border: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFE3E6E8),
                                  ),
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFE3E6E8),
                                  ),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: CocoTheme.primary,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                        child: Text(
                          l10n.routeBuilderStopsCountLabel(_stops.length),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CocoTheme.secondary),
                        ),
                      ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _stops.length,
                        onReorderItem: _reorderStops,
                        proxyDecorator: (child, index, animation) => Material(
                          color: Colors.white,
                          elevation: 0.5,
                          shadowColor: Colors.black.withValues(alpha: 0.12),
                          child: child,
                        ),
                        itemBuilder: (context, i) => _StopRow(
                          key: ValueKey(_stops[i].id),
                          order: i + 1,
                          spot: _stops[i],
                          dragHandle: ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: Color(0xFF9AA0A6),
                              ),
                            ),
                          ),
                          onRemove: () => _remove(i),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: OutlinedButton(
                          onPressed: _loadingSavedSpots ? null : _openSearch,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor:
                                CocoTheme.primary.withOpacity(0.08),
                            side: BorderSide(
                                color: CocoTheme.primary,
                                style: BorderStyle.solid,
                                width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loadingSavedSpots
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: CocoTheme.primary,
                                  ),
                                )
                              : Text(l10n.routeBuilderAddSpotButton,
                                  style: const TextStyle(
                                      color: CocoTheme.primary,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CocoTheme.primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving || _saveCompleted ? null : _handleSave,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.mapSaveCourseButton,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          if (_searchOpen)
            SavedSpotsCourseMap(
              query: _searchQuery,
              stops: _stops,
              toastMessage: _toastMessage,
              onQueryChanged: _onSearchQueryChanged,
              onCancel: _cancelSearch,
              onConfirm: _confirmSearch,
              onAdd: _addStopFromSearch,
            ),
        ],
      ),
    );
  }
}

/// "+ 스팟 추가" 검색 팝업. 화면 전환 없이 이 화면 위에 뜨고, 검색창을 유지한
/// 채로 여러 스팟을 연속으로 담을 수 있다. 담긴 스팟은 체크 표시로 바뀌고
/// 다시 탭해도 무시된다(중복 추가 방지).
class SavedSpotsCourseMap extends StatefulWidget {
  final String query;
  final List<MockSpot> stops;
  final String? toastMessage;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final ValueChanged<MockSpot> onAdd;
  final VoidCallback? onCreateCourse;
  final bool showHeader;

  const SavedSpotsCourseMap({
    super.key,
    required this.query,
    required this.stops,
    this.toastMessage,
    required this.onQueryChanged,
    this.onCancel,
    this.onConfirm,
    required this.onAdd,
    this.onCreateCourse,
    this.showHeader = true,
  });

  @override
  State<SavedSpotsCourseMap> createState() => _SavedSpotsCourseMapState();
}

class _SavedSpotsCourseMapState extends State<SavedSpotsCourseMap> {
  String? _selectedSpotId;
  late final MapBoundsTarget? _initialBounds = savedSpots.isEmpty
      ? null
      : MapBoundsTarget(
          points: [for (final spot in savedSpots) (spot.lat, spot.lng)],
        );

  // 후보는 항상 내가 찜한(저장한) 스팟(savedSpots)으로 제한한다 — 코스는 찜한
  // 스팟들을 묶어 만드는 것이라 전체 DB 스팟을 검색해 보여주면 안 된다.
  // "남포 카페"처럼 여러 단어를 띄어써도 찾을 수 있게 — 공백으로 쪼갠 키워드가
  // 이름/동네/부제/주소 중 어디든 전부 포함돼 있으면 후보로 인정한다(순서 무관).
  List<MockSpot> get _candidates {
    final keywords = widget.query
        .trim()
        .split(RegExp(r'\s+'))
        .where((k) => k.isNotEmpty)
        .toList();
    final filtered = keywords.isEmpty
        ? List<MockSpot>.of(savedSpots)
        : savedSpots.where((s) {
            final haystack =
                '${s.name} ${s.dong} ${s.subtitle} ${s.address}'.toLowerCase();
            return keywords.every((k) => haystack.contains(k.toLowerCase()));
          }).toList();
    final selectedIndex =
        filtered.indexWhere((spot) => spot.id == _selectedSpotId);
    if (selectedIndex > 0) {
      final selected = filtered.removeAt(selectedIndex);
      filtered.insert(0, selected);
    }
    return filtered;
  }

  void _addById(String spotId) {
    for (final spot in savedSpots) {
      if (spot.id == spotId) {
        widget.onAdd(spot);
        return;
      }
    }
  }

  int? _orderFor(MockSpot spot) {
    final index = widget.stops.indexWhere((saved) => saved.id == spot.id);
    return index < 0 ? null : index + 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final candidates = _candidates;
    final allSaved = savedSpots;
    final center = spotsCenter(allSaved);
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: allSaved.isEmpty
                  ? Center(
                      child: Text(l10n.mapSearchNoResults,
                          style: TextStyle(color: Colors.grey.shade500)),
                    )
                  : KakaoMapView(
                      centerLat: center.$1,
                      centerLng: center.$2,
                      level: 7,
                      boundsTarget: _initialBounds,
                      clusteringEnabled: false,
                      markers: [
                        for (final spot in candidates)
                          KakaoMapMarker(
                            id: spot.id,
                            lat: spot.lat,
                            lng: spot.lng,
                            name: spot.name,
                            subtitle: spot.subtitle,
                            alwaysShowLabel: true,
                            order: _orderFor(spot),
                            compactOrder: true,
                            actionLabel:
                                widget.stops.any((s) => s.id == spot.id)
                                    ? l10n.routeBuilderAddedAction
                                    : l10n.routeBuilderAddAction,
                          ),
                      ],
                      onMarkerSelected: (spotId) =>
                          setState(() => _selectedSpotId = spotId),
                      onMarkerTap: _addById,
                    ),
            ),
            if (widget.showHeader)
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 16, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.96),
                        Colors.white.withValues(alpha: 0.82),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.72, 1],
                    ),
                  ),
                  child: PointerInterceptor(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(l10n.routeBuilderSavedMapTitle,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: CocoTheme.secondary)),
                            ),
                            TextButton(
                              onPressed: widget.onConfirm,
                              child: Text(l10n.routeBuilderDoneButton,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        Text(l10n.routeBuilderTapPinHint,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF737980))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.white,
                                elevation: 2,
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox(
                                  height: 48,
                                  child: TextField(
                                    autofocus: false,
                                    onChanged: widget.onQueryChanged,
                                    decoration: InputDecoration(
                                      hintText:
                                          l10n.feedComposerLocationSearchHint,
                                      border: InputBorder.none,
                                      prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          color: Color(0xFF9AA0A6)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: IconButton(
                                onPressed: widget.onCancel,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _RouteSpotPickerSheet(
              candidates: candidates,
              stops: widget.stops,
              onAdd: widget.onAdd,
              onCreateCourse: widget.onCreateCourse,
            ),
            if (widget.toastMessage != null)
              Positioned(
                left: 20,
                right: 20,
                top: MediaQuery.paddingOf(context).top + 154,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      child: Text(widget.toastMessage!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteSpotPickerSheet extends StatefulWidget {
  final List<MockSpot> candidates;
  final List<MockSpot> stops;
  final ValueChanged<MockSpot> onAdd;
  final VoidCallback? onCreateCourse;

  const _RouteSpotPickerSheet({
    required this.candidates,
    required this.stops,
    required this.onAdd,
    this.onCreateCourse,
  });

  @override
  State<_RouteSpotPickerSheet> createState() => _RouteSpotPickerSheetState();
}

class _RouteSpotPickerSheetState extends State<_RouteSpotPickerSheet> {
  static const double _midExtent = 0.34;
  double _extent = _midExtent;
  bool _dragging = false;

  double _collapsedExtent(double maxHeight) =>
      (58 / maxHeight).clamp(0.055, 0.10);

  double _expandedExtent(double maxHeight) =>
      ((maxHeight - 170) / maxHeight).clamp(0.65, 0.84);

  void _snap(double maxHeight) {
    final points = [
      _collapsedExtent(maxHeight),
      _midExtent,
      _expandedExtent(maxHeight),
    ];
    var nearest = points.first;
    var distance = (_extent - nearest).abs();
    for (final point in points.skip(1)) {
      final nextDistance = (_extent - point).abs();
      if (nextDistance < distance) {
        nearest = point;
        distance = nextDistance;
      }
    }
    setState(() {
      _extent = nearest;
      _dragging = false;
    });
  }

  void _cycleExtent(double maxHeight) {
    final collapsed = _collapsedExtent(maxHeight);
    final expanded = _expandedExtent(maxHeight);
    setState(() {
      if ((_extent - collapsed).abs() < 0.04) {
        _extent = _midExtent;
      } else if ((_extent - _midExtent).abs() < 0.08) {
        _extent = expanded;
      } else {
        _extent = collapsed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final collapsed = _collapsedExtent(maxHeight);
        final expanded = _expandedExtent(maxHeight);
        final sheetHeight = maxHeight * _extent;
        final showContent = sheetHeight > 105;
        return Align(
          alignment: Alignment.bottomCenter,
          child: PointerInterceptor(
            child: AnimatedContainer(
              duration:
                  _dragging ? Duration.zero : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: sheetHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _cycleExtent(maxHeight),
                    onVerticalDragStart: (_) =>
                        setState(() => _dragging = true),
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _extent = (_extent - details.delta.dy / maxHeight)
                            .clamp(collapsed, expanded);
                      });
                    },
                    onVerticalDragEnd: (_) => _snap(maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8DADD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          if (showContent) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(l10n.routeBuilderLikedSpotsTitle,
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        l10n.routeBuilderStopsAddedCount(
                                            widget.stops.length),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8A9097)),
                                      ),
                                      if (widget.onCreateCourse != null &&
                                          widget.stops.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        TweenAnimationBuilder<double>(
                                          key: const ValueKey(
                                              'create-course-action'),
                                          tween: Tween(begin: 0.72, end: 1),
                                          duration:
                                              const Duration(milliseconds: 420),
                                          curve: Curves.easeOutBack,
                                          builder: (context, scale, child) =>
                                              Transform.scale(
                                            scale: scale,
                                            child: child,
                                          ),
                                          child: FilledButton(
                                            onPressed: widget.onCreateCourse,
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  CocoTheme.primary,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              minimumSize: Size.zero,
                                            ),
                                            child: Text(
                                              l10n.myRoutesCreateCourseButton,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (showContent)
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: widget.candidates.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: Color(0xFFF0F1F2)),
                        itemBuilder: (context, index) {
                          final spot = widget.candidates[index];
                          final added =
                              widget.stops.any((s) => s.id == spot.id);
                          return InkWell(
                            onTap: added ? null : () => widget.onAdd(spot),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 11),
                              child: Row(
                                children: [
                                  Icon(spot.icon,
                                      size: 20, color: spot.pinColor),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(spot.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                        Text(spot.subtitle,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF8A9097))),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    added
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_rounded,
                                    color: added
                                        ? const Color(0xFFB7D8F5)
                                        : CocoTheme.primary,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StopRow extends StatelessWidget {
  final int order;
  final MockSpot spot;
  final Widget dragHandle;
  final VoidCallback onRemove;

  const _StopRow({
    super.key,
    required this.order,
    required this.spot,
    required this.dragHandle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F2F3), width: 0.6),
          bottom: BorderSide(color: Color(0xFFE8EAEC), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CocoTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text('$order',
                style: const TextStyle(
                    color: CocoTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CocoTheme.secondary)),
                const SizedBox(height: 2),
                Text(spot.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8A9097))),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 19),
            color: const Color(0xFF8A9097),
            visualDensity: VisualDensity.compact,
          ),
          dragHandle,
        ],
      ),
    );
  }
}

/// 담은 스팟들을 순서대로 잇는 경로 미리보기.
/// 코스상세(route_preview_screen.dart의 _CoverHeader)와 동일하게 실제
/// 카카오 지도 위에 순서 번호 핀을 올린다 — 핀 사이 점선과 핀 탭 시 말풍선은
/// KakaoMapView(JS 브리지)가 order 값이 있는 마커에 대해 알아서 그려준다.
class _RouteMiniMap extends StatelessWidget {
  final List<MockSpot> stops;
  const _RouteMiniMap({required this.stops});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE3),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: stops.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined,
                      size: 28, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.routeBuilderEmptyMiniMap,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
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
                          KakaoMapMarker(
                              id: spot.id,
                              lat: spot.lat,
                              lng: spot.lng,
                              name: spot.name,
                              order: i + 1),
                      ],
                    ),
                  ),
                  // 미리보기일 뿐 조작할 필요가 없어 드래그·카카오 로고 클릭 등
                  // 실제 지도 DOM 조작을 막는 투명 오버레이(_CoverHeader와 동일).
                  const Positioned.fill(
                      child: ColoredBox(color: Colors.transparent)),
                ],
              );
            }),
    );
  }
}
