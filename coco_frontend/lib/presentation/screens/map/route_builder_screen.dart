import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'map_mock_data.dart';

/// 골목지도(코스) 만들기 화면.
/// 지도 탭에서 북마크한 스팟들을 순서를 정해 하나의 코스로 묶는다.
class RouteBuilderScreen extends StatefulWidget {
  final List<MockSpot> initialStops;
  const RouteBuilderScreen({super.key, this.initialStops = const []});

  @override
  State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen> {
  late List<MockSpot> _stops = List.of(widget.initialStops);
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _addStop() async {
    final candidates = mockSpots.where((s) => !_stops.any((stop) => stop.id == s.id)).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가할 수 있는 스팟이 더 없어요')),
      );
      return;
    }
    final picked = await showModalBottomSheet<MockSpot>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('스팟 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final spot in candidates)
              ListTile(
                leading: Icon(spot.icon, color: spot.pinColor),
                title: Text(spot.name),
                subtitle: Text(spot.subtitle),
                onTap: () => Navigator.of(context).pop(spot),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _stops.add(picked));
    }
  }

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
    // MY탭 "내가 만든 골목지도"/"저장한 코스"에서 보여줄 수 있도록 공유 리스트에 반영.
    mockMyRoutes.insert(0, MockRoute(id: 'route-${DateTime.now().millisecondsSinceEpoch}', name: name, stops: List.of(_stops)));
    context.push('/map/route/preview', extra: {
      'name': name,
      'stops': _stops,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                  const Expanded(
                    child: Text(
                      '골목지도 만들기',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary),
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
                      onPressed: _addStop,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: Colors.grey.shade400, style: BorderStyle.solid),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('+ 스팟 추가', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
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
