import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'feed_mock_data.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _categories = ['노포', '골목', '공원', '카페'];

  String? _sourceFilter; // null = 전체
  String? _categoryFilter; // null = 전체
  String _sortBy = 'latest'; // latest | popular | distance
  bool _locationGranted = false;
  bool _showLocationPrompt = false;
  bool _refreshing = false;
  int _visibleCount = 5;
  bool _loadingMore = false;
  bool _filtersVisible = true;

  final _scrollController = ScrollController();
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  List<FeedItem> get _filteredSorted {
    var list = mockFeedItems.where((it) {
      final sourceOk = _sourceFilter == null ||
          (_sourceFilter == 'coco' ? it.source == FeedSource.coco : it.source == FeedSource.user);
      final categoryOk = _categoryFilter == null || it.category == _categoryFilter;
      return sourceOk && categoryOk;
    }).toList();

    switch (_sortBy) {
      case 'popular':
        list.sort((a, b) => (b.likes + b.saves) - (a.likes + a.saves));
        break;
      case 'distance':
        list.sort((a, b) => a.distanceMin - b.distanceMin);
        break;
      default:
        list.sort((a, b) => b.ts - a.ts);
    }
    return list;
  }

  bool get _hasMore => _visibleCount < _filteredSorted.length;

  void _onScroll() {
    final position = _scrollController.position;

    // 스크롤 방향에 따라 상단 필터 영역(검색바/소스버튼/카테고리칩/정렬행)을
    // 접었다 펼친다. 맨 위 근처에서는 항상 펼쳐진 상태로 고정.
    if (position.pixels <= 0) {
      if (!_filtersVisible) setState(() => _filtersVisible = true);
    } else if (position.userScrollDirection == ScrollDirection.reverse && _filtersVisible) {
      setState(() => _filtersVisible = false);
    } else if (position.userScrollDirection == ScrollDirection.forward && !_filtersVisible) {
      setState(() => _filtersVisible = true);
    }

    if (_loadingMore || !_hasMore) return;
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

  void _handleRefresh() {
    setState(() => _refreshing = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _visibleCount = 5;
      });
      _showToast('최신 피드로 업데이트했어요');
    });
  }

  void _handleSortDistanceTap() {
    if (_locationGranted) {
      setState(() {
        _sortBy = 'distance';
        _visibleCount = 5;
      });
    } else {
      setState(() => _showLocationPrompt = true);
    }
  }

  void _allowLocation() {
    setState(() {
      _locationGranted = true;
      _sortBy = 'distance';
      _showLocationPrompt = false;
      _visibleCount = 5;
    });
  }

  void _denyLocation() => setState(() => _showLocationPrompt = false);

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = msg);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  Future<void> _openDetail(FeedItem item) async {
    await context.push('/feed/post', extra: item);
    if (mounted) setState(() {});
  }

  Future<void> _openComposer() async {
    await context.push('/feed/compose');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filteredSorted.take(_visibleCount).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: CocoTheme.primary,
        onPressed: _openComposer,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _FeedHeaderBar(),
                // 검색바/소스버튼/카테고리칩/정렬행 — 아래로 스크롤하면 접히고
                // 위로 스크롤하면 다시 펼쳐진다 (_onScroll에서 _filtersVisible 토글).
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    heightFactor: _filtersVisible ? 1 : 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _filtersVisible ? 1 : 0,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _DecorativeSearchBar(),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _SourceSegmentedRow(
                              selected: _sourceFilter,
                              onSelected: (v) => setState(() {
                                _sourceFilter = v;
                                _visibleCount = 5;
                              }),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: _CategoryChipsRow(
                              categories: _categories,
                              selected: _categoryFilter,
                              onSelected: (v) => setState(() {
                                _categoryFilter = v;
                                _visibleCount = 5;
                              }),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: _SortRow(
                              sortBy: _sortBy,
                              refreshing: _refreshing,
                              onSortLatest: () => setState(() {
                                _sortBy = 'latest';
                                _visibleCount = 5;
                              }),
                              onSortPopular: () => setState(() {
                                _sortBy = 'popular';
                                _visibleCount = 5;
                              }),
                              onSortDistance: _handleSortDistanceTap,
                              onRefresh: _handleRefresh,
                            ),
                          ),
                          if (_showLocationPrompt)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _LocationPrompt(onAllow: _allowLocation, onDeny: _denyLocation),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: visibleItems.isEmpty
                      ? const _EmptyState()
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
                              onPrevImg: () => setState(
                                  () => item.imgIndex = (item.imgIndex - 1 + item.imgCount) % item.imgCount),
                              onNextImg: () =>
                                  setState(() => item.imgIndex = (item.imgIndex + 1) % item.imgCount),
                              onOpenDetail: () => _openDetail(item),
                              onReport: () => _showToast('신고가 접수되었습니다'),
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_toastMessage != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(child: _Toast(message: _toastMessage!)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedHeaderBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'COCO',
            style: TextStyle(color: CocoTheme.primary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFF0ECE6), shape: BoxShape.circle),
                child: Icon(Icons.notifications_none_rounded, size: 18, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFF0ECE6),
                child: Text('나', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecorativeSearchBar extends StatelessWidget {
  const _DecorativeSearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text('골목, 노포, 공원 검색...', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _SourceSegmentedRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _SourceSegmentedRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SegmentButton(label: '전체', active: selected == null, onTap: () => onSelected(null))),
        const SizedBox(width: 6),
        Expanded(child: _SegmentButton(label: 'COCO 추천', active: selected == 'coco', onTap: () => onSelected('coco'))),
        const SizedBox(width: 6),
        Expanded(child: _SegmentButton(label: '이웃 게시물', active: selected == 'user', onTap: () => onSelected('user'))),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegmentButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? CocoTheme.primary : const Color(0xFFF6F5F2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _CategoryChipsRow({required this.categories, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CategoryChip(label: '전체', selected: selected == null, onTap: () => onSelected(null)),
          const SizedBox(width: 8),
          for (final c in categories) ...[
            _CategoryChip(label: c, selected: c == selected, onTap: () => onSelected(c)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

class _SortRow extends StatelessWidget {
  final String sortBy;
  final bool refreshing;
  final VoidCallback onSortLatest;
  final VoidCallback onSortPopular;
  final VoidCallback onSortDistance;
  final VoidCallback onRefresh;

  const _SortRow({
    required this.sortBy,
    required this.refreshing,
    required this.onSortLatest,
    required this.onSortPopular,
    required this.onSortDistance,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _SortLabel(label: '최신순', active: sortBy == 'latest', onTap: onSortLatest),
            const SizedBox(width: 14),
            _SortLabel(label: '인기순', active: sortBy == 'popular', onTap: onSortPopular),
            const SizedBox(width: 14),
            _SortLabel(label: '거리순', active: sortBy == 'distance', onTap: onSortDistance),
          ],
        ),
        InkWell(
          onTap: refreshing ? null : onRefresh,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFF6F5F2), shape: BoxShape.circle),
            child: refreshing
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: CocoTheme.primary),
                  )
                : Icon(Icons.refresh_rounded, size: 15, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

class _SortLabel extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SortLabel({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? CocoTheme.secondary : Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _LocationPrompt extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onDeny;
  const _LocationPrompt({required this.onAllow, required this.onDeny});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFEAF3FC), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 주변 스팟을 보려면 위치 권한이 필요해요.', style: TextStyle(fontSize: 13, color: CocoTheme.secondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CocoTheme.primary,
                    minimumSize: const Size.fromHeight(34),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onAllow,
                  child: const Text('허용', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(34), padding: EdgeInsets.zero),
                  onPressed: onDeny,
                  child: const Text('취소', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                ),
              ),
            ],
          ),
        ],
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
            Text('조건에 맞는 스팟이 없어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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

class _Toast extends StatelessWidget {
  final String message;
  const _Toast({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
      child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onPrevImg;
  final VoidCallback onNextImg;
  final VoidCallback onOpenDetail;
  final VoidCallback onReport;

  const _FeedCard({
    required this.item,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onPrevImg,
    required this.onNextImg,
    required this.onOpenDetail,
    required this.onReport,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (item.source == FeedSource.coco)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: CocoTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: CocoTheme.primary),
                      SizedBox(width: 3),
                      Text('COCO 추천', style: TextStyle(color: CocoTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: const Color(0xFFF0ECE6),
                      child: Text(item.authorInitial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                    ),
                    const SizedBox(width: 8),
                    Text(item.author ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                  ],
                ),
              // COCO 추천 게시물은 신고 대상이 아니라 메뉴 버튼 자체를 숨김
              // (PopupMenuButton은 항목이 1개 이상 있어야 해서 빈 메뉴를 띄울 수 없음)
              if (item.source == FeedSource.user)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey.shade500),
                  onSelected: (v) {
                    if (v == 'report') onReport();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'report', child: Text('신고', style: TextStyle(color: Color(0xFFB4433A)))),
                  ],
                )
              else
                const SizedBox(width: 28, height: 28),
            ],
          ),
          _FeedCardPhoto(item: item, onTap: onOpenDetail, onPrevImg: onPrevImg, onNextImg: onNextImg),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFF0ECE6), borderRadius: BorderRadius.circular(12)),
            child: Text(item.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onOpenDetail,
            child: Text(item.place, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
          ),
          const SizedBox(height: 4),
          Text(
            item.desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Text('${item.neighborhood} · 도보 ${item.distanceMin}분', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
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
                icon: item.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                iconColor: item.saved ? CocoTheme.secondary : Colors.grey.shade600,
                label: '${item.saveCount}',
                onTap: onToggleSave,
              ),
              const SizedBox(width: 18),
              _ActionIcon(icon: Icons.ios_share_rounded, iconColor: Colors.grey.shade600, label: '공유', onTap: () {}),
              const Spacer(),
              _ActionIcon(
                icon: Icons.mode_comment_outlined,
                iconColor: Colors.grey.shade600,
                label: '${item.comments.length}',
                onTap: onOpenDetail,
              ),
            ],
          ),
        ],
      ),
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
    final color = categoryColor(item.category);
    return AspectRatio(
      aspectRatio: 4 / 3,
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
                  child: Icon(categoryIcon(item.category), size: 36, color: color.withOpacity(0.4)),
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
