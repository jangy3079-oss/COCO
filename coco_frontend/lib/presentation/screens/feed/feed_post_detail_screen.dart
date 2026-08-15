import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'feed_mock_data.dart';

/// 피드 게시물 상세 화면. FeedScreen에서 push할 때 같은 FeedItem 인스턴스를
/// extra로 전달받아 직접 mutate한다 — mockFeedItems가 공유 리스트라 여기서
/// 좋아요/저장/댓글을 바꾸면 피드 목록으로 돌아갔을 때도 그대로 반영된다.
class FeedPostDetailScreen extends StatefulWidget {
  final FeedItem item;
  const FeedPostDetailScreen({super.key, required this.item});

  @override
  State<FeedPostDetailScreen> createState() => _FeedPostDetailScreenState();
}

class _FeedPostDetailScreenState extends State<FeedPostDetailScreen> {
  final _commentController = TextEditingController();

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

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
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
                  const Text('스팟 상세', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODO: feed_posts.image_url 연동 전까지의 사진 플레이스홀더
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        color: color.withOpacity(0.12),
                        alignment: Alignment.center,
                        child: Icon(categoryIcon(item.category), size: 40, color: color.withOpacity(0.4)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF0ECE6), borderRadius: BorderRadius.circular(12)),
                            child: Text(item.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                          ),
                          const SizedBox(height: 8),
                          Text(item.place, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                          const SizedBox(height: 4),
                          Text('${item.neighborhood} · 도보 ${item.distanceMin}분', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          const SizedBox(height: 14),
                          Text(item.desc, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade800)),
                          const SizedBox(height: 16),
                          _MiniMapDecoration(pinColor: color),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => context.go('/map'),
                                  child: const Text('지도에서 보기', style: TextStyle(color: CocoTheme.secondary, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: CocoTheme.primary,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    setState(() => item.saved = true);
                                    _showToast('코스에 담았습니다');
                                  },
                                  child: const Text('코스에 담기', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Row(
                              children: [
                                _ActionIcon(
                                  icon: item.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  iconColor: item.liked ? CocoTheme.primary : Colors.grey.shade600,
                                  label: '${item.likeCount}',
                                  onTap: () => setState(() => item.liked = !item.liked),
                                ),
                                const SizedBox(width: 18),
                                _ActionIcon(
                                  icon: item.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  iconColor: item.saved ? CocoTheme.secondary : Colors.grey.shade600,
                                  label: '${item.saveCount}',
                                  onTap: () => setState(() => item.saved = !item.saved),
                                ),
                              ],
                            ),
                          ),
                          Container(margin: const EdgeInsets.only(top: 4), height: 1, color: Colors.black.withOpacity(0.06)),
                          Padding(
                            padding: const EdgeInsets.only(top: 18, bottom: 4),
                            child: Text('댓글 ${item.comments.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                          ),
                          for (final c in item.comments)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
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
                        ],
                      ),
                    ),
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

/// 게시물 위치를 대략적으로 보여주는 장식용 미니맵.
/// TODO: 실제 지도 SDK 연동 후 진짜 좌표 기반 썸네일로 교체.
class _MiniMapDecoration extends StatelessWidget {
  final Color pinColor;
  const _MiniMapDecoration({required this.pinColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(color: const Color(0xFFEAE8E2), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(left: 20, top: 16, child: _block(60, 28, const Color(0xFFDAD7CC))),
          Positioned(right: 30, top: 20, child: _block(70, 36, const Color(0xFFE1E7DC))),
          Center(child: Icon(Icons.location_on, color: pinColor, size: 26)),
        ],
      ),
    );
  }

  Widget _block(double w, double h, Color color) =>
      Container(width: w, height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)));
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
