import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/qna_post.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/qna_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../feed/feed_mock_data.dart';
import 'mypage_mock_data.dart';

/// "내가 쓴 글" 화면. 실제 피드 게시물(작성자==나) + 실제 QnA 질문(filter=mine)을
/// 합쳐서 보여준다. 두 모델이 하나로 통합되어 있지 않아, 화면 표시에 필요한 값만
/// 뽑아 화면 로컬 클래스(_PostEntry)로 매핑한다 — 별도 공유 모델을 새로 만들 필요는 없음.
class MyPostsScreen extends StatefulWidget {
  final String initialFilter; // all | feed | qna
  const MyPostsScreen({super.key, this.initialFilter = 'all'});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  late String _filter = widget.initialFilter;

  final _feedRepository = FeedRepository();
  final _qnaRepository = QnaRepository();
  List<FeedItem> _feedItems = [];
  List<QnaPost> _qnaPosts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 두 요청을 동시에 시작해두고(await는 따로) 순서와 무관하게 병렬로 기다린다.
    final feedFuture = _feedRepository.fetchFeed();
    final qnaFuture = _qnaRepository.listPosts(filter: 'mine');
    try {
      final posts = await feedFuture;
      if (!mounted) return;
      setState(() => _feedItems = posts.map(feedItemFromPost).toList());
    } catch (e) {
      debugPrint('[MyPostsScreen] 내가 쓴 피드 조회 실패: $e');
    }
    try {
      final posts = await qnaFuture;
      if (!mounted) return;
      setState(() => _qnaPosts = posts);
    } catch (e) {
      debugPrint('[MyPostsScreen] 내가 쓴 질문 조회 실패: $e');
    }
  }

  List<_PostEntry> get _entries {
    final l10n = AppLocalizations.of(context)!;
    final feedEntries = _feedItems.where((f) => f.author == myNickname).map((f) => _PostEntry(
          kind: 'feed',
          title: f.place,
          meta: l10n.myPostsFeedMeta(f.likeCount, f.comments.length),
          timeLabel: f.timeLabel,
          solved: false,
          sortTs: f.ts,
          thumbnailColor: categoryColor(f.category),
          onTap: () async {
            await context.push('/feed/post', extra: f);
            if (mounted) setState(() {});
          },
        ));
    final qnaEntries = _qnaPosts.map((p) => _PostEntry(
          kind: 'qna',
          title: p.title,
          meta: l10n.qnaAnswerCount(p.answerCount),
          timeLabel: _relativeTimeLabel(p.createdAt),
          solved: p.solved,
          sortTs: p.createdAt.millisecondsSinceEpoch,
          thumbnailColor: null,
          onTap: () async {
            await context.push('/qna/post', extra: p.id);
            if (mounted) setState(() {});
          },
        ));

    var combined = [...feedEntries, ...qnaEntries];
    if (_filter == 'feed') combined = combined.where((e) => e.kind == 'feed').toList();
    if (_filter == 'qna') combined = combined.where((e) => e.kind == 'qna').toList();
    combined.sort((a, b) => b.sortTs.compareTo(a.sortTs));
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 6),
                  Text(l10n.myPageMenuMyPosts, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterChip(label: l10n.feedFilterAll, selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(label: l10n.myPostsFilterFeed, selected: _filter == 'feed', onTap: () => setState(() => _filter = 'feed')),
                  const SizedBox(width: 8),
                  _FilterChip(label: l10n.myPostsFilterQna, selected: _filter == 'qna', onTap: () => setState(() => _filter = 'qna')),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? _EmptyPosts(onGoToFeed: () => context.go('/feed'))
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                      itemBuilder: (context, i) => _PostRow(entry: entries[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostEntry {
  final String kind; // feed | qna
  final String title;
  final String meta;
  final String timeLabel;
  final bool solved;
  final int sortTs;
  final Color? thumbnailColor;
  final VoidCallback onTap;

  _PostEntry({
    required this.kind,
    required this.title,
    required this.meta,
    required this.timeLabel,
    required this.solved,
    required this.sortTs,
    required this.thumbnailColor,
    required this.onTap,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary),
          child: Text(label),
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  final _PostEntry entry;
  const _PostRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFeed = entry.kind == 'feed';
    return InkWell(
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFeed) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: (entry.thumbnailColor ?? CocoTheme.primary).withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(Icons.photo_camera_outlined, size: 20, color: (entry.thumbnailColor ?? CocoTheme.primary).withOpacity(0.5)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFeed ? const Color(0xFFF4F4F2) : const Color(0xFFE6F1FB),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          isFeed ? l10n.myPostsKindFeed : l10n.myPostsFilterQna,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isFeed ? Colors.grey.shade700 : CocoTheme.primary),
                        ),
                      ),
                      if (entry.solved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(9)),
                          child: Text(l10n.qnaSolvedBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                        ),
                      ],
                      const Spacer(),
                      Text(entry.timeLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(entry.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, color: CocoTheme.secondary)),
                  const SizedBox(height: 4),
                  Text(entry.meta, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPosts extends StatelessWidget {
  final VoidCallback onGoToFeed;
  const _EmptyPosts({required this.onGoToFeed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.myPostsEmptyState, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CocoTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: onGoToFeed,
              child: Text(l10n.myPostsGoToFeedButton),
            ),
          ],
        ),
      ),
    );
  }
}

// qna_screen.dart/qna_post_detail_screen.dart의 _relativeTimeLabel과 동일한 로직 —
// 화면 파일마다 필요한 만큼만 복제해 쓰는 기존 코드베이스 패턴을 따른다.
String _relativeTimeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 2) return '어제';
  return '${diff.inDays}일 전';
}
