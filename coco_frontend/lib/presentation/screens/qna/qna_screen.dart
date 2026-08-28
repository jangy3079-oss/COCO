import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_type.dart';
import 'qna_mock_data.dart';

class QnaScreen extends StatefulWidget {
  const QnaScreen({super.key});

  @override
  State<QnaScreen> createState() => _QnaScreenState();
}

class _QnaScreenState extends State<QnaScreen> {
  String? _filter; // null=전체 | 'unanswered' | 'mine'
  String _sort = 'latest'; // latest | unanswered_first
  bool _filtersVisible = true;

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

  List<QnaPost> get _filteredSorted {
    var list = qnaMockPosts.where((p) {
      if (_filter == 'unanswered') return p.answers.isEmpty;
      if (_filter == 'mine') return p.mine;
      return true;
    }).toList();

    if (_sort == 'unanswered_first') {
      list.sort((a, b) => a.answers.length - b.answers.length);
    } else {
      list.sort((a, b) => b.ts - a.ts);
    }
    return list;
  }

  Future<void> _openDetail(QnaPost post) async {
    await context.push('/qna/post', extra: post);
    if (mounted) setState(() {});
  }

  Future<void> _openComposer() async {
    await context.push('/qna/compose');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredSorted;

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
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('커뮤니티', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                        const SizedBox(height: 4),
                        Text('관광객의 질문에 동네 주민이 답해요', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFFF0ECE6),
                    child: Text('나', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
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
                            _FilterChip(label: '전체', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                            const SizedBox(width: 8),
                            _FilterChip(label: '미답변', selected: _filter == 'unanswered', onTap: () => setState(() => _filter = 'unanswered')),
                            const SizedBox(width: 8),
                            _FilterChip(label: '내 질문', selected: _filter == 'mine', onTap: () => setState(() => _filter = 'mine')),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () => setState(() {
                                _sort = _sort == 'latest' ? 'unanswered_first' : 'latest';
                              }),
                              child: Text(
                                '${_sort == 'latest' ? '최신순' : '미답변 우선'} ⌄',
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
              child: posts.isEmpty
                  ? Center(
                      child: Text('조건에 맞는 질문이 없어요', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary),
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
    final isLocalAuthor = post.authorRole == UserType.local;
    final roleLabel = isLocalAuthor ? '로컬' : '관광객';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLocalAuthor ? const Color(0xFFE6F1FB) : const Color(0xFFF4F4F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isLocalAuthor ? CocoTheme.primary : Colors.grey.shade700),
                  ),
                ),
                if (post.solved) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(10)),
                    child: const Text('✓ 해결됨', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                  ),
                ],
                const Spacer(),
                Text(post.timeLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.title,
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
                  post.answers.isEmpty ? '아직 답변 없어요' : '답변 ${post.answers.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: post.answers.isEmpty ? CocoTheme.primary : Colors.grey.shade600,
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
