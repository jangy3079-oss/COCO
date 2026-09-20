import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  late List<MockSpot> _stops = List.of(widget.initialStops);
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

  void _onSearchQueryChanged(String query) => setState(() => _searchQuery = query);

  void _addStopFromSearch(MockSpot spot) {
    if (_stops.any((s) => s.id == spot.id)) return;
    _toastTimer?.cancel();
    setState(() {
      _stops.add(spot);
      _addedDuringSearch.add(spot.id);
      _toastMessage = AppLocalizations.of(context)!.routeBuilderSpotAddedToast(spot.name);
    });
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _moveUp(int i) {
    if (i <= 0) return;
    setState(() {
      final tmp = _stops[i - 1];
      _stops[i - 1] = _stops[i];
      _stops[i] = tmp;
    });
  }

  void _moveDown(int i) {
    if (i >= _stops.length - 1) return;
    setState(() {
      final tmp = _stops[i + 1];
      _stops[i + 1] = _stops[i];
      _stops[i] = tmp;
    });
  }

  void _remove(int i) => setState(() => _stops.removeAt(i));

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.routeBuilderNameRequiredWarning)),
      );
      return;
    }
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.routeBuilderStopsRequiredWarning)),
      );
      return;
    }
    if (!requireLogin(context)) return;
    if (_saving) return;

    final name = _nameController.text.trim();
    // 스팟 추가 검색이 찜한 스팟(savedSpots, 전부 'db-' id)으로 제한돼 있어(#147) 전부
    // 실제 DB 스팟 id로 변환된다 — whereType은 혹시 모를 데모 스팟 방어용.
    final spotIds = _stops.map((s) => dbSpotNumericId(s.id)).whereType<int>().toList();
    final editingId = widget.editingRouteId;

    setState(() => _saving = true);
    try {
      final int backendId;
      if (editingId != null) {
        final numId = dbRouteNumericId(editingId);
        if (numId == null) return;
        final result = await _routeRepository.update(numId, name: name, spotIds: spotIds);
        backendId = result.id;
      } else {
        final result = await _routeRepository.create(name: name, spotIds: spotIds);
        backendId = result.id;
      }
      await refreshMyRoutes();
      if (!mounted) return;
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
          SnackBar(content: Text(AppLocalizations.of(context)!.routeBuilderSaveFailedMessage)),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.editingRouteId != null ? l10n.routeBuilderEditTitle(widget.initialName) : l10n.routeBuilderCreateTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary),
                    ),
                  ),
                  TextButton(
                    onPressed: _handleSave,
                    child: Text(l10n.routeBuilderDoneButton, style: const TextStyle(color: CocoTheme.primary, fontWeight: FontWeight.w700)),
                  ),
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
                        Text(l10n.routeBuilderNameLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: l10n.routeBuilderNameHint,
                            filled: true,
                            fillColor: const Color(0xFFF8F8F8),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary),
                    ),
                  ),
                  for (int i = 0; i < _stops.length; i++)
                    _StopRow(
                      order: i + 1,
                      spot: _stops[i],
                      canMoveUp: i > 0,
                      canMoveDown: i < _stops.length - 1,
                      onMoveUp: () => _moveUp(i),
                      onMoveDown: () => _moveDown(i),
                      onRemove: () => _remove(i),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: OutlinedButton(
                      onPressed: _loadingSavedSpots ? null : _openSearch,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: CocoTheme.primary.withOpacity(0.08),
                        side: BorderSide(color: CocoTheme.primary, style: BorderStyle.solid, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _handleSave,
                child: Text(l10n.mapSaveCourseButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
          ),
          if (_searchOpen)
            _StopSearchOverlay(
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
class _StopSearchOverlay extends StatelessWidget {
  final String query;
  final List<MockSpot> stops;
  final String? toastMessage;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final ValueChanged<MockSpot> onAdd;

  const _StopSearchOverlay({
    required this.query,
    required this.stops,
    required this.toastMessage,
    required this.onQueryChanged,
    required this.onCancel,
    required this.onConfirm,
    required this.onAdd,
  });

  // 후보는 항상 내가 찜한(저장한) 스팟(savedSpots)으로 제한한다 — 코스는 찜한
  // 스팟들을 묶어 만드는 것이라 전체 DB 스팟을 검색해 보여주면 안 된다.
  // "남포 카페"처럼 여러 단어를 띄어써도 찾을 수 있게 — 공백으로 쪼갠 키워드가
  // 이름/동네/부제/주소 중 어디든 전부 포함돼 있으면 후보로 인정한다(순서 무관).
  List<MockSpot> get _candidates {
    final keywords = query.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    if (keywords.isEmpty) return savedSpots;
    return savedSpots.where((s) {
      final haystack = '${s.name} ${s.dong} ${s.subtitle} ${s.address}'.toLowerCase();
      return keywords.every((k) => haystack.contains(k.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final candidates = _candidates;
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF6F6F4), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 18, color: Colors.black.withOpacity(0.4)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                autofocus: true,
                                onChanged: onQueryChanged,
                                decoration: InputDecoration(
                                  hintText: l10n.feedComposerLocationSearchHint,
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 14, color: CocoTheme.secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onCancel,
                      child: Text(l10n.feedRouteComposeCancel, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.5))),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onConfirm,
                      child: Text(l10n.routeBuilderDoneButton, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.routeBuilderStopsAddedCount(stops.length), style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4))),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    candidates.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                            child: Center(
                              child: Text(l10n.mapSearchNoResults, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.4))),
                            ),
                          )
                        : ListView.separated(
                            itemCount: candidates.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                            itemBuilder: (context, i) {
                              final spot = candidates[i];
                              final added = stops.any((s) => s.id == spot.id);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(color: spot.pinColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                      alignment: Alignment.center,
                                      child: Icon(spot.icon, size: 18, color: spot.pinColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(spot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                                          const SizedBox(height: 2),
                                          Text(spot.subtitle, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
                                        ],
                                      ),
                                    ),
                                    Material(
                                      color: added ? const Color(0xFFE6F1FB) : CocoTheme.primary,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap: added ? null : () => onAdd(spot),
                                        customBorder: const CircleBorder(),
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: Icon(
                                            added ? Icons.check_rounded : Icons.add_rounded,
                                            size: 17,
                                            color: added ? CocoTheme.primary : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    if (toastMessage != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.88), borderRadius: BorderRadius.circular(20)),
                            child: Text(toastMessage!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final int order;
  final MockSpot spot;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  const _StopRow({
    required this.order,
    required this.spot,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: CocoTheme.primary, shape: BoxShape.circle),
            child: Text('$order', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(spot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
          ),
          IconButton(
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            visualDensity: VisualDensity.compact,
          ),
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
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE3),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: stops.isEmpty
          ? Center(
              child: Text(AppLocalizations.of(context)!.routeBuilderEmptyMiniMap, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                  // 미리보기일 뿐 조작할 필요가 없어 드래그·카카오 로고 클릭 등
                  // 실제 지도 DOM 조작을 막는 투명 오버레이(_CoverHeader와 동일).
                  const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
                ],
              );
            }),
    );
  }
}
