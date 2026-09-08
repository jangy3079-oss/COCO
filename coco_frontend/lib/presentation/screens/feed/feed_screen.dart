import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'feed_mock_data.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  FeedPostType? _typeFilter; // null = 전체
  String _dongId = 'nampo'; // feedDongOptions 참고. 'all' = 전체 동네
  String _sortBy = 'latest'; // latest | likes | saves
  int _visibleCount = 5;
  bool _loadingMore = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isRankingView => _typeFilter == FeedPostType.route;

  List<FeedItem> get _filteredSorted {
    var list = mockFeedItems
        .where((it) => (_dongId == 'all' || it.dongId == _dongId) && (_typeFilter == null || it.type == _typeFilter))
        .toList();

    switch (_sortBy) {
      case 'likes':
        list.sort((a, b) => b.likeCount - a.likeCount);
        break;
      case 'saves':
        list.sort((a, b) => b.saveCount - a.saveCount);
        break;
      default:
        list.sort((a, b) => b.ts - a.ts);
    }
    return list;
  }

  bool get _hasMore => _visibleCount < _filteredSorted.length;

  void _onScroll() {
    final position = _scrollController.position;
    if (_loadingMore || !_hasMore || _isRankingView) return;
    if (position.pixels >= position.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() => _loadingMore = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _visibleCount = min(_visibleCount + 3, _filteredSorted.length);
      });
    });
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => _FilterSheet(
          dongId: _dongId,
          sortBy: _sortBy,
          resultCount: _filteredSorted.length,
          onDongSelected: (id) => setSheetState(() => _dongId = id),
          onSortSelected: (v) => setSheetState(() => _sortBy = v),
          onReset: () => setSheetState(() {
            _dongId = 'nampo';
            _sortBy = 'latest';
          }),
          onApply: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (mounted) setState(() => _visibleCount = 5);
  }

  Future<void> _openDetail(FeedItem item) async {
    await context.push('/feed/post', extra: item);
    if (mounted) setState(() {});
  }

  Future<void> _openComposer() async {
    await context.push('/feed/compose');
    if (mounted) setState(() {});
  }

  Future<void> _share(FeedItem item) async {
    // 공유 시트에서 카카오톡/인스타/메시지 중 하나를 실제로 골랐을 때만 카운트를
    // 올린다 — 시트만 열었다가 아무것도 안 누르고 닫으면 안 올라가야 한다.
    final shared = await showShareSheet(context);
    if (shared && mounted) setState(() => item.shares += 1);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filteredSorted.take(_visibleCount).toList();
    final isDefaultFilter = _dongId == 'nampo' && _sortBy == 'latest';

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: CocoTheme.primary,
        shape: const CircleBorder(),
        onPressed: _openComposer,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FeedHeaderBar(dongLabel: feedDongLabel(_dongId)),
            // 필터 영역 — 스크롤 여부와 상관없이 항상 고정으로 보여준다.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _FilterRow(
                isDefaultFilter: isDefaultFilter,
                onOpenSheet: _openFilterSheet,
                typeFilter: _typeFilter,
                onTypeSelected: (v) => setState(() {
                  _typeFilter = v;
                  _visibleCount = 5;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${feedDongLabel(_dongId)} · ${feedSortLabels[_sortBy]}',
                  style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4)),
                ),
              ),
            ),
            Expanded(
              child: visibleItems.isEmpty
                  ? const _EmptyState()
                  : _isRankingView
                      ? _RouteRankingList(
                          items: visibleItems,
                          onToggleSave: (item) => setState(() => item.saved = !item.saved),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: visibleItems.length + 1,
                          itemBuilder: (context, i) {
                            if (i == visibleItems.length) {
                              return _ListFooter(
                                loadingMore: _loadingMore,
                                showEndMessage: !_loadingMore && !_hasMore,
                              );
                            }
                            final item = visibleItems[i];
                            return _FeedCard(
                              item: item,
                              onToggleLike: () => setState(() => item.liked = !item.liked),
                              onToggleSave: () => setState(() => item.saved = !item.saved),
                              onShare: () => _share(item),
                              onPrevImg: () =>
                                  setState(() => item.imgIndex = (item.imgIndex - 1 + item.imgCount) % item.imgCount),
                              onNextImg: () => setState(() => item.imgIndex = (item.imgIndex + 1) % item.imgCount),
                              onOpenDetail: () => _openDetail(item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 인스타그램 등 외부 SNS 공유를 흉내낸 목업 시트.
/// 카카오톡/인스타그램/메시지 중 하나를 실제로 고르면 true, 아무것도 안 고르고
/// 시트를 닫으면(바깥 탭/뒤로가기) false 또는 null을 반환한다 — 호출부가 이 값을
/// 보고 공유수를 올릴지 말지 정한다.
/// TODO: 실제 OS 공유 시트 연동 시 share_plus 등으로 교체.
Future<bool> showShareSheet(BuildContext context) async {
  final shared = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('공유하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
            const SizedBox(height: 18),
            Row(
              children: [
                _ShareTile(icon: Icons.chat_bubble_rounded, color: const Color(0xFFFEE500), label: '카카오톡', onTap: () => Navigator.of(context).pop(true)),
                const SizedBox(width: 16),
                _ShareTile(icon: Icons.camera_alt_rounded, color: const Color(0xFFE1306C), label: '인스타그램', onTap: () => Navigator.of(context).pop(true)),
                const SizedBox(width: 16),
                _ShareTile(icon: Icons.sms_rounded, color: Colors.grey.shade600, label: '메시지', onTap: () => Navigator.of(context).pop(true)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return shared ?? false;
}

class _ShareTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ShareTile({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 26, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: CocoTheme.secondary)),
        ],
      ),
    );
  }
}

class _FeedHeaderBar extends StatelessWidget {
  final String dongLabel;
  const _FeedHeaderBar({required this.dongLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('피드', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: CocoTheme.primary),
                  const SizedBox(width: 4),
                  Text(dongLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.primary)),
                  const SizedBox(width: 4),
                  Text('기준', style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.35))),
                ],
              ),
            ],
          ),
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFF0ECE6),
            child: Text('나', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final bool isDefaultFilter;
  final VoidCallback onOpenSheet;
  final FeedPostType? typeFilter;
  final ValueChanged<FeedPostType?> onTypeSelected;

  const _FilterRow({
    required this.isDefaultFilter,
    required this.onOpenSheet,
    required this.typeFilter,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onOpenSheet,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDefaultFilter ? Colors.white : CocoTheme.primary.withOpacity(0.12),
              border: Border.all(color: isDefaultFilter ? Colors.grey.shade300 : CocoTheme.primary),
            ),
            child: Icon(Icons.tune_rounded, size: 18, color: isDefaultFilter ? Colors.black.withOpacity(0.45) : CocoTheme.primary),
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 22, color: Colors.black.withOpacity(0.1)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TypeChip(label: '전체', selected: typeFilter == null, onTap: () => onTypeSelected(null)),
                const SizedBox(width: 8),
                _TypeChip(label: '일상', selected: typeFilter == FeedPostType.spot, onTap: () => onTypeSelected(FeedPostType.spot)),
                const SizedBox(width: 8),
                _TypeChip(label: '코스', selected: typeFilter == FeedPostType.route, onTap: () => onTypeSelected(FeedPostType.route)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : CocoTheme.secondary,
          ),
        ),
      ),
    );
  }
}

/// 필터 아이콘 탭 시 뜨는 바텀시트 — 동네 칩 + 정렬 칩 + 적용 버튼.
class _FilterSheet extends StatelessWidget {
  final String dongId;
  final String sortBy;
  final int resultCount;
  final ValueChanged<String> onDongSelected;
  final ValueChanged<String> onSortSelected;
  final VoidCallback onReset;
  final VoidCallback onApply;

  const _FilterSheet({
    required this.dongId,
    required this.sortBy,
    required this.resultCount,
    required this.onDongSelected,
    required this.onSortSelected,
    required this.onReset,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('피드 필터', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                  TextButton(
                    onPressed: onReset,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text('초기화', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.4))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('동네', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.45))),
                  const SizedBox(width: 8),
                  Text('현재 위치 중구 남포동', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.32))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in feedDongOptions)
                    _SheetChip(
                      label: d.label,
                      selected: dongId == d.id,
                      icon: d.near ? Icons.location_on_rounded : null,
                      onTap: () => onDongSelected(d.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('정렬', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.45))),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in feedSortLabels.entries)
                    _SheetChip(
                      label: entry.value,
                      selected: sortBy == entry.key,
                      onTap: () => onSortSelected(entry.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CocoTheme.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onApply,
                child: Text('$resultCount개 게시물 보기', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _SheetChip({required this.label, required this.selected, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary)),
            if (icon != null) ...[
              const SizedBox(width: 5),
              Icon(icon, size: 12, color: selected ? Colors.white : CocoTheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('조건에 맞는 게시물이 없어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text('필터를 바꿔서 다시 찾아보세요', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  final bool loadingMore;
  final bool showEndMessage;
  const _ListFooter({required this.loadingMore, required this.showEndMessage});

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: CocoTheme.primary),
            ),
            const SizedBox(width: 8),
            Text('불러오는 중...', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    if (showEndMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text('모두 확인했어요', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400))),
      );
    }
    return const SizedBox(height: 12);
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;
  final VoidCallback onPrevImg;
  final VoidCallback onNextImg;
  final VoidCallback onOpenDetail;

  const _FeedCard({
    required this.item,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onShare,
    required this.onPrevImg,
    required this.onNextImg,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 10),
          _FeedCardPhoto(item: item, onTap: onOpenDetail, onPrevImg: onPrevImg, onNextImg: onNextImg),
          const SizedBox(height: 12),
          InkWell(
            onTap: onOpenDetail,
            child: Text(item.displayTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
          ),
          const SizedBox(height: 4),
          Text(
            item.desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionIcon(
                icon: item.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: item.liked ? CocoTheme.primary : Colors.grey.shade600,
                label: '${item.likeCount}',
                onTap: onToggleLike,
              ),
              const SizedBox(width: 18),
              _ActionIcon(
                icon: Icons.mode_comment_outlined,
                iconColor: Colors.grey.shade600,
                label: '${item.comments.length}',
                onTap: onOpenDetail,
              ),
              const SizedBox(width: 18),
              _ActionIcon(
                icon: Icons.share_outlined,
                iconColor: Colors.grey.shade600,
                label: '${item.shares}',
                onTap: onShare,
              ),
              const Spacer(),
              _ActionIcon(
                icon: item.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                iconColor: item.saved ? CocoTheme.secondary : Colors.grey.shade600,
                label: '${item.saveCount}',
                onTap: onToggleSave,
              ),
            ],
          ),
        ],
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

class _FeedCardPhoto extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;
  final VoidCallback onPrevImg;
  final VoidCallback onNextImg;

  const _FeedCardPhoto({required this.item, required this.onTap, required this.onPrevImg, required this.onNextImg});

  @override
  Widget build(BuildContext context) {
    final isRoute = item.type == FeedPostType.route;
    final color = isRoute ? CocoTheme.primary : categoryColor(item.category);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              // TODO: feed_posts.image_url 연동 전까지의 사진 플레이스홀더
              Positioned.fill(
                child: Container(
                  color: color.withOpacity(0.12),
                  alignment: Alignment.center,
                  child: Icon(
                    isRoute ? Icons.signpost_rounded : categoryIcon(item.category),
                    size: 36,
                    color: color.withOpacity(0.4),
                  ),
                ),
              ),
              if (isRoute)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '코스 · 스팟 ${item.stopCount ?? 0}곳',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CocoTheme.primary),
                    ),
                  ),
                )
              else
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.dong, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                        const SizedBox(width: 6),
                        Text(item.place, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                      ],
                    ),
                  ),
                ),
              if (item.imgCount > 1) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _CarouselArrow(icon: Icons.chevron_left_rounded, onTap: onPrevImg)),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _CarouselArrow(icon: Icons.chevron_right_rounded, onTap: onNextImg)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < item.imgCount; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == item.imgIndex ? Colors.white : Colors.white.withOpacity(0.5),
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
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 18, color: CocoTheme.secondary)),
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

/// 골목지도 탭 전용 랭킹 리스트 — 카드 피드 대신 순위·통계 중심으로 보여준다.
class _RouteRankingList extends StatelessWidget {
  final List<FeedItem> items;
  final ValueChanged<FeedItem> onToggleSave;
  const _RouteRankingList({required this.items, required this.onToggleSave});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (int i = 0; i < items.length; i++) _RouteRankRow(rank: i + 1, item: items[i], onToggleSave: () => onToggleSave(items[i])),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Text(
            '저장한 코스는 MY 탭 › 저장 · 좋아요에서 다시 볼 수 있어요',
            style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black.withOpacity(0.35)),
          ),
        ),
      ],
    );
  }
}

class _RouteRankRow extends StatelessWidget {
  final int rank;
  final FeedItem item;
  final VoidCallback onToggleSave;
  const _RouteRankRow({required this.rank, required this.item, required this.onToggleSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: rank == 1 ? CocoTheme.primary : Colors.black.withOpacity(0.3)),
            ),
          ),
          const SizedBox(width: 12),
          const _RouteThumb(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                const SizedBox(height: 3),
                Text('@${item.author} · ${item.dong} · 스팟 ${item.stopCount ?? 0}곳', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
                const SizedBox(height: 5),
                Text('저장 ${item.saveCount} · 좋아요 ${item.likeCount} · 공유 ${item.shares}', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.4))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggleSave,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: item.saved ? const Color(0xFFFF5A36) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.saved ? const Color(0xFFFF5A36) : Colors.grey.shade300),
              ),
              child: Text(
                item.saved ? '저장됨' : '저장',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.saved ? Colors.white : Colors.black.withOpacity(0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 골목지도 랭킹 항목의 64x64 장식용 썸네일 — 실제 좌표 없이 골목지도 느낌만 낸다.
class _RouteThumb extends StatelessWidget {
  const _RouteThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: const Color(0xFFEAE8E2), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(left: 0, top: 28, right: 0, height: 4, child: Container(color: Colors.white)),
          Positioned(left: 23, top: 0, bottom: 0, width: 3, child: Container(color: Colors.white)),
          Positioned(left: 9, top: 14, child: _pin()),
          Positioned(left: 37, top: 37, child: _pin()),
        ],
      ),
    );
  }

  Widget _pin() => Transform.rotate(
        angle: -0.78,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: CocoTheme.primary, borderRadius: BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5), bottomRight: Radius.circular(5))),
        ),
      );
}
