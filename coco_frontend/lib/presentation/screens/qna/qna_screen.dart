import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/qna_post.dart';
import '../../../data/repositories/qna_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

class QnaScreen extends StatefulWidget {
  const QnaScreen({super.key});

  @override
  State<QnaScreen> createState() => _QnaScreenState();
}

class _QnaScreenState extends State<QnaScreen> {
  String? _filter; // null=전체 | 'unanswered' | 'mine' (백엔드 filter 파라미터: all|unanswered|mine)
  String _sort = 'latest'; // latest | unanswered_first — 백엔드 sort 파라미터 값과 동일
  bool _filtersVisible = true;

  final _scrollController = ScrollController();
  final _qnaRepository = QnaRepository();
  List<QnaPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels <= 0) {
      if (!_filtersVisible) setState(() => _filtersVisible = true);
    } else if (position.userScrollDirection == ScrollDirection.reverse && _filtersVisible) {
      setState(() => _filtersVisible = false);
    } else if (position.userScrollDirection == ScrollDirection.forward && !_filtersVisible) {
      setState(() => _filtersVisible = true);
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await _qnaRepository.listPosts(filter: _filter ?? 'all', sort: _sort);
      if (!mounted) return;
      // SOS 질문은 정렬 옵션(최신순/미답변순)과 무관하게 항상 맨 위에 고정한다.
      // List.sort는 안정 정렬이 아니라서, 각 그룹 안의 기존 순서를 지키려면
      // 직접 둘로 나눠서 이어붙여야 한다.
      final sosPosts = posts.where((p) => p.isSos).toList();
      final restPosts = posts.where((p) => !p.isSos).toList();
      setState(() {
        _posts = [...sosPosts, ...restPosts];
        _loading = false;
      });
    } catch (e) {
      debugPrint('[QnaScreen] 질문 목록 조회 실패: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _selectFilter(String? filter) {
    if (filter == 'mine' && !requireLogin(context)) return;
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _loadPosts();
  }

  void _toggleSort() {
    setState(() => _sort = _sort == 'latest' ? 'unanswered_first' : 'latest');
    _loadPosts();
  }

  Future<void> _openDetail(QnaPost post) async {
    await context.push('/qna/post', extra: post.id);
    if (mounted) _loadPosts();
  }

  Future<void> _openComposer() async {
    if (!requireLogin(context)) return;
    await context.push('/qna/compose');
    if (mounted) _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: CocoTheme.primary,
        onPressed: _openComposer,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.qnaHeaderTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                        const SizedBox(height: 4),
                        Text(l10n.qnaHeaderSubtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFFF0ECE6),
                    child: Text(l10n.feedMeAvatarLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                  ),
                ],
              ),
            ),
            // 필터칩 + 정렬 토글 — 스크롤 방향에 따라 접고 펼침 (피드 탭과 동일 패턴)
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            _FilterChip(label: l10n.feedFilterAll, selected: _filter == null, onTap: () => _selectFilter(null)),
                            const SizedBox(width: 8),
                            _FilterChip(label: l10n.qnaFilterUnanswered, selected: _filter == 'unanswered', onTap: () => _selectFilter('unanswered')),
                            const SizedBox(width: 8),
                            _FilterChip(label: l10n.qnaFilterMine, selected: _filter == 'mine', onTap: () => _selectFilter('mine')),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: _toggleSort,
                              child: Text(
                                '${_sort == 'latest' ? l10n.qnaSortLatest : l10n.qnaSortUnansweredFirst} ⌄',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : posts.isEmpty
                      ? Center(
                          child: Text(l10n.qnaEmptyState, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: posts.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                          itemBuilder: (context, i) => _QuestionCard(post: posts[i], onTap: () => _openDetail(posts[i])),
                        ),
            ),
          ],
        ),
      ),
    );
  }
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
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(fontFamily: 'NotoSansKR', fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary),
          child: Text(label),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QnaPost post;
  final VoidCallback onTap;
  const _QuestionCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: post.isSos ? const Color(0xFFFFF3F2) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (post.isSos) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10)),
                    child: const Text('SOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(post.userNickname, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                if (post.solved) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(10)),
                    child: Text(l10n.qnaSolvedBadge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                  ),
                ],
                const Spacer(),
                Text(_relativeTimeLabel(post.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.displayTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4, color: CocoTheme.secondary),
            ),
            const SizedBox(height: 4),
            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (post.spotName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF4F4F2), borderRadius: BorderRadius.circular(8)),
                    child: Text('📍 ${post.spotName}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  post.answerCount == 0 ? l10n.qnaAnswerCountZero : l10n.qnaAnswerCount(post.answerCount),
                  style: TextStyle(
                    fontSize: 12,
                    color: post.answerCount == 0 ? CocoTheme.primary : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// feed_mock_data.dart의 _relativeTimeLabel과 동일한 로직 — 화면 파일마다 필요한
// 만큼만 갖는 기존 코드베이스 패턴을 그대로 따랐다(공용 유틸로 뺄 만큼 쓰이진 않음).
String _relativeTimeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 2) return '어제';
  return '${diff.inDays}일 전';
}
