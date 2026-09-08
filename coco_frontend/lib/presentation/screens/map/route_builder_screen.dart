import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _searchOpen = false;
  String _searchQuery = '';
  String? _toastMessage;
  Timer? _toastTimer;
  // 이번 검색 세션에서 새로 담은 스팟 id들 — "취소"를 누르면 이번 세션에서
  // 추가한 것만 되돌리고(원래 있던 스팟은 그대로 두고), "완료"를 누르면 그대로
  // 확정한다. 예전엔 닫기 버튼이 하나뿐이라 그게 사실상 "완료"처럼 동작했었다.
  final Set<String> _addedDuringSearch = {};

  @override
  void dispose() {
    _nameController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _openSearch() => setState(() {
        _searchOpen = true;
        _addedDuringSearch.clear();
      });

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

  void _addStopFromSearch(MockSpot spot) {
    if (_stops.any((s) => s.id == spot.id)) return;
    _toastTimer?.cancel();
    setState(() {
      _stops.add(spot);
      _addedDuringSearch.add(spot.id);
      _toastMessage = '${spot.name} 스팟이 추가되었습니다';
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

  void _handleSave() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스 이름을 입력해주세요')),
      );
      return;
    }
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스팟을 1개 이상 담아주세요')),
      );
      return;
    }
    final name = _nameController.text.trim();
    // MY탭 "내가 만든 코스"에서 보여줄 수 있도록 공유 리스트에 반영.
    // 편집 모드면 기존 코스를 같은 자리에서 갱신하고, 아니면 새 코스로 맨 앞에 추가한다.
    final editingId = widget.editingRouteId;
    String routeId;
    if (editingId != null) {
      routeId = editingId;
      final i = mockMyRoutes.indexWhere((r) => r.id == editingId);
      if (i != -1) {
        final old = mockMyRoutes[i];
        mockMyRoutes[i] = MockRoute(
          id: old.id,
          name: name,
          stops: List.of(_stops),
          isPublic: old.isPublic,
          likes: old.likes,
          saves: old.saves,
          shares: old.shares,
        );
      }
    } else {
      routeId = 'route-${DateTime.now().millisecondsSinceEpoch}';
      mockMyRoutes.insert(0, MockRoute(id: routeId, name: name, stops: List.of(_stops)));
    }
    context.push('/map/route/preview', extra: {
      'name': name,
      'stops': _stops,
      'routeId': routeId,
      'isOwner': true,
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      widget.editingRouteId != null ? '${widget.initialName} 편집' : '코스 만들기',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary),
                    ),
                  ),
                  TextButton(
                    onPressed: _handleSave,
                    child: const Text('완료', style: TextStyle(color: CocoTheme.primary, fontWeight: FontWeight.w700)),
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
                        const Text('코스 이름', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: '예: 겨울밤 노포 투어',
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
                      '담은 스팟 (${_stops.length})',
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
                      onPressed: _openSearch,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: CocoTheme.primary.withOpacity(0.08),
                        side: BorderSide(color: CocoTheme.primary, style: BorderStyle.solid, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('+ 스팟 추가', style: TextStyle(color: CocoTheme.primary, fontWeight: FontWeight.w600)),
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
                child: const Text('코스 저장하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
              onQueryChanged: (v) => setState(() => _searchQuery = v),
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

  // "남포 카페"처럼 여러 단어를 띄어써도 찾을 수 있게 — 공백으로 쪼갠 키워드가
  // 이름/동네/부제/주소 중 어디든 전부 포함돼 있으면 후보로 인정한다(순서 무관).
  List<MockSpot> get _candidates {
    final keywords = query.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    if (keywords.isEmpty) return mockSpots;
    return mockSpots.where((s) {
      final haystack = '${s.name} ${s.dong} ${s.subtitle} ${s.address}'.toLowerCase();
      return keywords.every((k) => haystack.contains(k.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                                decoration: const InputDecoration(
                                  hintText: '장소명 또는 주소 검색',
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
                      child: Text('취소', style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.5))),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onConfirm,
                      child: const Text('완료', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${stops.length}개 담김', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4))),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    candidates.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                            child: Center(
                              child: Text('검색 결과가 없어요', style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.4))),
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

/// 담은 스팟들을 순서대로 잇는 작은 경로 미리보기.
/// TODO: 실제 지도 SDK 연동 후 진짜 경로 폴리라인으로 교체.
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
              child: Text('스팟을 추가하면 경로가 표시돼요', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final points = stops
                    .map((s) => Offset(s.left * constraints.maxWidth, s.top * constraints.maxHeight))
                    .toList();
                return Stack(
                  children: [
                    CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _DashedPathPainter(points),
                    ),
                    for (int i = 0; i < points.length; i++)
                      Positioned(
                        left: points[i].dx - 10,
                        top: points[i].dy - 10,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: CocoTheme.primary, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _DashedPathPainter extends CustomPainter {
  final List<Offset> points;
  _DashedPathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      _drawDashedLine(canvas, points[i], points[i + 1], paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashWidth = 6.0;
    const gapWidth = 5.0;
    final total = (b - a).distance;
    final direction = (b - a) / total;
    double covered = 0;
    while (covered < total) {
      final start = a + direction * covered;
      final end = a + direction * (covered + dashWidth).clamp(0.0, total).toDouble();
      canvas.drawLine(start, end, paint);
      covered += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) => oldDelegate.points != points;
}
