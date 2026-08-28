import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../feed/feed_mock_data.dart';
import '../qna/qna_mock_data.dart';
import 'mypage_mock_data.dart';

/// "내가 쓴 글" 화면. mockFeedItems(작성자==나) + qnaMockPosts(mine)를 합쳐서 보여준다.
/// 두 데이터가 하나의 새 모델로 통합되어 있지 않아, 화면 표시에 필요한 값만 뽑아
/// 화면 로컬 클래스(_PostEntry)로 매핑한다 — 별도 공유 모델을 새로 만들 필요는 없음.
class MyPostsScreen extends StatefulWidget {
  final String initialFilter; // all | feed | qna
  const MyPostsScreen({super.key, this.initialFilter = 'all'});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  late String _filter = widget.initialFilter;

  // FeedItem에는 실제 타임스탬프가 없고 정렬용 ts(정수)만 있어서, 정확한 상대
  // 시간 대신 근사치 라벨을 보여준다. 실 서버 연동 시 created_at 기준으로 교체.
  String _feedTimeLabel(FeedItem f) {
    if (f.ts >= 8) return '오늘';
    if (f.ts >= 6) return '어제';
    if (f.ts >= 3) return '이번 주';
    return '지난달';
  }

  List<_PostEntry> get _entries {
    final feedEntries = mockFeedItems
        .where((f) => f.source == FeedSource.user && f.author == myNickname)
        .map((f) => _PostEntry(
              kind: 'feed',
              title: f.place,
              meta: '좋아요 ${f.likeCount} · 댓글 ${f.comments.length}',
              timeLabel: _feedTimeLabel(f),
              solved: false,
              sortTs: f.ts,
              thumbnailColor: categoryColor(f.category),
              onTap: () async {
                await context.push('/feed/post', extra: f);
                if (mounted) setState(() {});
              },
              onDelete: () => setState(() => mockFeedItems.remove(f)),
            ));
    final qnaEntries = qnaMockPosts.where((p) => p.mine).map((p) => _PostEntry(
          kind: 'qna',
          title: p.title,
          meta: '답변 ${p.answers.length}',
          timeLabel: p.timeLabel,
          solved: p.solved,
          sortTs: p.ts,
          thumbnailColor: null,
          onTap: () async {
            await context.push('/qna/post', extra: p);
            if (mounted) setState(() {});
          },
          onDelete: () => setState(() => qnaMockPosts.remove(p)),
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
                  const Text('내가 쓴 글', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterChip(label: '전체', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(label: '피드 게시물', selected: _filter == 'feed', onTap: () => setState(() => _filter = 'feed')),
                  const SizedBox(width: 8),
                  _FilterChip(label: '질문', selected: _filter == 'qna', onTap: () => setState(() => _filter = 'qna')),
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
  final VoidCallback onDelete;

  _PostEntry({
    required this.kind,
    required this.title,
    required this.meta,
    required this.timeLabel,
    required this.solved,
    required this.sortTs,
    required this.thumbnailColor,
    required this.onTap,
    required this.onDelete,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary)),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  final _PostEntry entry;
  const _PostRow({required this.entry});

  @override
  Widget build(BuildContext context) {
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
                          isFeed ? '피드' : '질문',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isFeed ? Colors.grey.shade700 : CocoTheme.primary),
                        ),
                      ),
                      if (entry.solved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(9)),
                          child: const Text('✓ 해결됨', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
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
            PopupMenuButton<String>(
              icon: Text('⋯', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
              padding: EdgeInsets.zero,
              onSelected: (_) => entry.onDelete(),
              itemBuilder: (context) => const [PopupMenuItem(value: 'delete', child: Text('삭제'))],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('아직 쓴 글이 없어요', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CocoTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: onGoToFeed,
              child: const Text('피드로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}
