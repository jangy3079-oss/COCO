import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'feed_mock_data.dart';
import 'feed_screen.dart' show showShareSheet;

/// 피드 게시물 상세 화면 (당근마켓 스타일). FeedScreen에서 push할 때 같은
/// FeedItem 인스턴스를 extra로 전달받아 직접 mutate한다 — mockFeedItems가
/// 공유 리스트라 여기서 좋아요/저장/댓글을 바꾸면 피드 목록으로 돌아갔을 때도
/// 그대로 반영된다.
///
/// 골목지도(type == route) 게시물은 사진 슬라이드 마지막에 정적 골목지도
/// 슬라이드가 하나 더 붙고, 그 슬라이드를 보고 있을 때만 아래에 골목지도
/// 요약 카드(보기/저장 버튼)가 나타난다 — 레퍼런스의 슬라이드-연동 동작.
class FeedPostDetailScreen extends StatefulWidget {
  final FeedItem item;
  const FeedPostDetailScreen({super.key, required this.item});

  @override
  State<FeedPostDetailScreen> createState() => _FeedPostDetailScreenState();
}

class _FeedPostDetailScreenState extends State<FeedPostDetailScreen> {
  final _commentController = TextEditingController();
  int _slide = 0;

  bool get _isRoute => widget.item.type == FeedPostType.route;
  int get _totalSlides => (_isRoute ? widget.item.imgCount + 1 : widget.item.imgCount).clamp(1, 99);
  bool get _onMapSlide => _isRoute && _slide == _totalSlides - 1;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.item.comments.add(FeedComment(id: 'c${DateTime.now().millisecondsSinceEpoch}', author: '나', text: text));
    });
    _commentController.clear();
  }

  void _prevSlide() => setState(() => _slide = (_slide - 1 + _totalSlides) % _totalSlides);
  void _nextSlide() => setState(() => _slide = (_slide + 1) % _totalSlides);

  Future<void> _share() async {
    final shared = await showShareSheet(context);
    if (shared && mounted) setState(() => widget.item.shares += 1);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = categoryColor(item.category);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const Text('게시물', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFFF0ECE6),
                            child: Text(item.authorInitial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                          ),
                          const SizedBox(width: 8),
                          Text(item.author ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                          const SizedBox(width: 6),
                          const _LocalBadge(),
                          const Spacer(),
                          Text(item.timeLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: AspectRatio(
                        aspectRatio: 340 / 280,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _onMapSlide
                                    ? const _RouteMapSlide()
                                    : Container(
                                        color: color.withOpacity(0.12),
                                        alignment: Alignment.center,
                                        child: Icon(categoryIcon(item.category), size: 40, color: color.withOpacity(0.4)),
                                      ),
                              ),
                              if (_totalSlides > 1) ...[
                                Positioned(
                                  left: 10,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(child: _CarouselArrow(icon: Icons.chevron_left_rounded, onTap: _prevSlide)),
                                ),
                                Positioned(
                                  right: 10,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(child: _CarouselArrow(icon: Icons.chevron_right_rounded, onTap: _nextSlide)),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 12,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (int i = 0; i < _totalSlides; i++)
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          width: i == _slide ? 18 : 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(3),
                                            color: i == _slide ? CocoTheme.primary : Colors.white.withOpacity(0.85),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Text(item.desc, style: TextStyle(fontSize: 14, height: 1.7, color: Colors.black.withOpacity(0.7))),
                    ),
                    if (!_isRoute)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: InkWell(
                          onTap: () => context.go('/map'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 15, color: CocoTheme.accent),
                                const SizedBox(width: 6),
                                Text(item.dong, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                                const SizedBox(width: 4),
                                Text(item.place, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_onMapSlide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _RouteSummaryCard(item: item),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(margin: const EdgeInsets.only(bottom: 14), height: 1, color: Colors.black.withOpacity(0.07)),
                          Row(
                            children: [
                              _ActionIcon(
                                icon: item.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                iconColor: item.liked ? CocoTheme.primary : Colors.grey.shade600,
                                label: '${item.likeCount}',
                                onTap: () => setState(() => item.liked = !item.liked),
                              ),
                              const SizedBox(width: 18),
                              _ActionIcon(
                                icon: Icons.mode_comment_outlined,
                                iconColor: Colors.grey.shade600,
                                label: '${item.comments.length}',
                                onTap: () {},
                              ),
                              const SizedBox(width: 18),
                              _ActionIcon(
                                icon: Icons.share_outlined,
                                iconColor: Colors.grey.shade600,
                                label: '${item.shares}',
                                onTap: _share,
                              ),
                              if (!_isRoute) ...[
                                const Spacer(),
                                _ActionIcon(
                                  icon: item.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  iconColor: item.saved ? CocoTheme.secondary : Colors.grey.shade600,
                                  label: '${item.saveCount}',
                                  onTap: () => setState(() => item.saved = !item.saved),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                      child: Text('댓글 ${item.comments.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                    ),
                    for (final c in item.comments)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFF0ECE6),
                              child: Text(c.authorInitial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.author, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                                  const SizedBox(height: 2),
                                  Text(c.text, style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: '댓글을 남겨보세요',
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CocoTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _submitComment,
                    child: const Text('등록'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalBadge extends StatelessWidget {
  const _LocalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: CocoTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: const Text('로컬', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 30, height: 30, child: Icon(icon, size: 18, color: CocoTheme.secondary)),
      ),
    );
  }
}

/// 골목지도 게시물의 마지막 캐러셀 슬라이드 — 정적 경로+번호 핀 그래픽.
/// TODO: 실제 코스 데이터(MockRoute) 연동 시 진짜 좌표 기반 스냅샷으로 교체.
class _RouteMapSlide extends StatelessWidget {
  const _RouteMapSlide();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAE8E2),
      child: Stack(
        children: [
          Positioned(left: 0, top: 44, right: 0, height: 3, child: Container(color: Colors.white)),
          Positioned(left: 40, top: 0, bottom: 0, width: 3, child: Container(color: Colors.white)),
          CustomPaint(size: Size.infinite, painter: _DashedPathPainter()),
          _numberPin(left: 0.14, top: 0.24, n: 1),
          _numberPin(left: 0.47, top: 0.17, n: 2),
          _numberPin(left: 0.71, top: 0.50, n: 3),
          _numberPin(left: 0.32, top: 0.68, n: 4),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.94), borderRadius: BorderRadius.circular(14)),
              child: const Text('공유된 골목지도', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberPin({required double left, required double top, required int n}) {
    return FractionallySizedBox(
      widthFactor: 1,
      heightFactor: 1,
      child: Align(
        alignment: Alignment(left * 2 - 1, top * 2 - 1),
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CocoTheme.primary, shape: BoxShape.circle),
          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _DashedPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.17, size.height * 0.29),
      Offset(size.width * 0.50, size.height * 0.22),
      Offset(size.width * 0.73, size.height * 0.54),
      Offset(size.width * 0.35, size.height * 0.72),
    ];
    final paint = Paint()
      ..color = CocoTheme.primary.withOpacity(0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      _drawDashedLine(canvas, points[i], points[i + 1], paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashWidth = 5.0;
    const gapWidth = 5.0;
    final total = (b - a).distance;
    if (total == 0) return;
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
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) => false;
}

/// 골목지도 마지막 슬라이드 아래에 붙는 요약 카드 — 골목지도 보기/저장.
class _RouteSummaryCard extends StatefulWidget {
  final FeedItem item;
  const _RouteSummaryCard({required this.item});

  @override
  State<_RouteSummaryCard> createState() => _RouteSummaryCardState();
}

class _RouteSummaryCardState extends State<_RouteSummaryCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: CocoTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Text('코스', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
              ),
              const SizedBox(width: 6),
              Text('by ${item.author} · 부산 로컬', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35))),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.displayTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
          const SizedBox(height: 4),
          Text(
            '스팟 ${item.stopCount ?? 0}곳 · ${item.distanceKm.toStringAsFixed(1)}km · 약 ${item.durationMin}분',
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  // 코스 상세(route_preview_screen)로 이동 — 내가 올린 코스면(routeId 있음)
                  // 편집도 가능하고, 다른 로컬이 올린 코스면 보기 전용으로 뜬다.
                  onPressed: item.routeStops == null || item.routeStops!.isEmpty
                      ? null
                      : () => context.push('/map/route/preview', extra: {
                            'name': item.displayTitle,
                            'stops': item.routeStops,
                            'routeId': item.routeId,
                            'isOwner': item.source == FeedSource.user,
                          }),
                  child: const Text('코스 보기', style: TextStyle(color: CocoTheme.secondary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: item.routeSaved ? const Color(0xFFFF5A36) : Colors.white,
                    foregroundColor: item.routeSaved ? Colors.white : const Color(0xFFFF5A36),
                    minimumSize: const Size.fromHeight(44),
                    side: item.routeSaved ? null : const BorderSide(color: Color(0xFFFF5A36)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => item.routeSaved = !item.routeSaved),
                  child: Text(item.routeSaved ? '저장됨' : '저장', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (item.routeSaved)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                'MY 탭 › 저장한 코스에 담겼어요 (내가 만든 코스와 따로 보여요)',
                style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.4)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
