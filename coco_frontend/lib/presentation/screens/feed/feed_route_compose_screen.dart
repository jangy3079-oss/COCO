import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../map/map_mock_data.dart';
import 'feed_mock_data.dart';

/// 골목지도(코스)를 피드에 공유하는 전용 작성 화면.
/// 골목지도 미리보기 화면(route_preview_screen.dart)의 "공유" 버튼에서 진입한다.
/// 일반 게시물 작성(feed_composer_screen.dart)과 달리 사진 대신 이미 만든
/// 코스를 첨부하는 흐름이라 별도 화면으로 분리했다.
class FeedRouteComposeScreen extends StatefulWidget {
  final String routeName;
  final List<MockSpot> stops;
  final String? routeId; // mockMyRoutes 안의 id — 코스 상세에서 "골목지도 보기"로 다시 찾아올 때 사용
  const FeedRouteComposeScreen({super.key, required this.routeName, required this.stops, this.routeId});

  @override
  State<FeedRouteComposeScreen> createState() => _FeedRouteComposeScreenState();
}

class _FeedRouteComposeScreenState extends State<FeedRouteComposeScreen> {
  static const _maxLen = 150;

  final _textController = TextEditingController();
  late MockSpot? _coverSpot = widget.stops.isNotEmpty ? widget.stops.first : null;
  bool _public = true;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canPost => _textController.text.trim().isNotEmpty && _coverSpot != null && !_submitting;

  Future<void> _submit() async {
    if (!_canPost) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // "나만 보기"는 피드에 올라가지 않아요 (시나리오 그대로) — 전체 공유일 때만 피드에 반영.
    if (_public) {
      final maxTs = mockFeedItems.isEmpty ? 0 : mockFeedItems.map((e) => e.ts).reduce((a, b) => a > b ? a : b);
      mockFeedItems.insert(
        0,
        FeedItem(
          id: 'u${DateTime.now().millisecondsSinceEpoch}',
          source: FeedSource.user,
          author: '나',
          category: '골목',
          place: _coverSpot!.name,
          title: widget.routeName,
          desc: _textController.text.trim(),
          neighborhood: '내 동네',
          dongId: 'nampo',
          distanceMin: 1,
          likes: 0,
          saves: 0,
          shares: 0,
          imgCount: 1,
          ts: maxTs + 1,
          timeLabel: '방금',
          type: FeedPostType.route,
          stopCount: widget.stops.length,
          routeStops: widget.stops,
          routeId: widget.routeId,
        ),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = (widget.stops.length * 0.3).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text('취소', style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.5))),
                  ),
                  const Text('피드에 공유', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                  GestureDetector(
                    onTap: _submit,
                    child: Text(
                      _submitting ? '게시 중...' : '게시',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _canPost ? CocoTheme.primary : Colors.black.withOpacity(0.25)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF4F8FC), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(color: const Color(0xFFEAE8E2), borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: const Icon(Icons.signpost_rounded, color: CocoTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: CocoTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                  child: const Text('코스 첨부', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                                ),
                                const SizedBox(height: 6),
                                Text(widget.routeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                                const SizedBox(height: 3),
                                Text('스팟 ${widget.stops.length}곳 · ${distanceKm}km · 동선 포함', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.45))),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text('변경', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.35))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('소개 글', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                        Text('${_textController.text.length}/$_maxLen', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      maxLength: _maxLen,
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '이 코스를 왜 만들었는지, 어떤 날 걷기 좋은지 적어보세요',
                        counterText: '',
                        filled: true,
                        contentPadding: const EdgeInsets.all(13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text('대표 스팟', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                        const SizedBox(width: 6),
                        Text('피드 썸네일로 쓰여요', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.4))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.stops.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final spot = widget.stops[i];
                          final selected = _coverSpot?.id == spot.id;
                          return GestureDetector(
                            onTap: () => setState(() => _coverSpot = spot),
                            child: SizedBox(
                              width: 104,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      color: spot.pinColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: selected ? Border.all(color: CocoTheme.primary, width: 2) : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Stack(
                                      children: [
                                        Center(child: Icon(spot.icon, color: spot.pinColor.withOpacity(0.5), size: 26)),
                                        if (selected)
                                          Positioned(
                                            right: 6,
                                            top: 6,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              alignment: Alignment.center,
                                              decoration: const BoxDecoration(color: CocoTheme.primary, shape: BoxShape.circle),
                                              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    spot.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? CocoTheme.primary : Colors.black.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('공개 범위', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _VisibilityCard(
                            title: '나만 보기',
                            subtitle: '피드에 올라가지 않아요',
                            selected: !_public,
                            onTap: () => setState(() => _public = false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _VisibilityCard(
                            title: '전체 공유',
                            subtitle: '인기순 랭킹에 함께 노출돼요',
                            selected: _public,
                            onTap: () => setState(() => _public = true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _canPost ? CocoTheme.primary : Colors.black.withOpacity(0.15),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submit,
                child: Text(_submitting ? '게시 중...' : '게시하기', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _VisibilityCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0xFFF5FAFE) : Colors.white,
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, height: 1.4, color: Colors.black.withOpacity(0.45))),
          ],
        ),
      ),
    );
  }
}
