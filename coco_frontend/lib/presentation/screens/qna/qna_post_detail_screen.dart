import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/qna_post.dart';
import '../../../data/repositories/qna_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../map/map_mock_data.dart' show MockSpot, dbSpotCache;

/// 질문 상세 + 답변 채택 화면. QnaScreen에서 push할 때 질문 id(int)만 extra로
/// 전달받고, 여기서 GET /api/qna/posts/{id}로 상세(질문+답변)를 직접 조회한다.
class QnaPostDetailScreen extends StatefulWidget {
  final int postId;
  const QnaPostDetailScreen({super.key, required this.postId});

  @override
  State<QnaPostDetailScreen> createState() => _QnaPostDetailScreenState();
}

class _QnaPostDetailScreenState extends State<QnaPostDetailScreen> {
  final _answerController = TextEditingController();
  final _qnaRepository = QnaRepository();

  QnaPostDetail? _detail;
  bool _loading = true;
  bool _loadFailed = false;
  bool _submittingAnswer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final detail = await _qnaRepository.getPostDetail(widget.postId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[QnaPostDetailScreen] 질문 상세 조회 실패: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _adopt(int answerId) async {
    if (!requireLogin(context)) return;
    try {
      await _qnaRepository.adopt(widget.postId, answerId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else if (e is DioException && e.response?.statusCode == 403) {
        // 질문 작성자 본인이 아니면 백엔드가 403을 준다 — 채택 버튼은 보통
        // 본인 질문에서만 보이지만(아래 showAdoptButton), 만일에 대비한 안내.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.qnaAdoptForbiddenMessage)),
        );
      } else {
        debugPrint('[QnaPostDetailScreen] 채택 실패: $e');
      }
    }
  }

  Future<void> _submitAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty || _submittingAnswer) return;
    if (!requireLogin(context)) return;

    setState(() => _submittingAnswer = true);
    try {
      await _qnaRepository.createAnswer(widget.postId, text);
      if (!mounted) return;
      _answerController.clear();
      await _load();
      if (!mounted) return;
      setState(() => _submittingAnswer = false);
    } catch (e) {
      debugPrint('[QnaPostDetailScreen] 답변 작성 실패: $e');
      if (!mounted) return;
      setState(() => _submittingAnswer = false);
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.feedPostDetailCommentFailed)),
        );
      }
    }
  }

  void _report() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.qnaPostDetailReportSubmitted), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final detail = _detail;
    if (_loadFailed || detail == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(child: Text(l10n.qnaLoadFailedMessage)),
      );
    }

    final post = detail.post;
    // spotId만 있고 이름/좌표/아이콘 같은 나머지 정보는 안 내려주니, 지도/상세에서
    // 한 번이라도 캐싱된 적 있으면(dbSpotCache) 그걸로 미리보기 카드를 꾸미고,
    // 없으면 이름만 보여준다(추가 API 호출 없이 최선을 다하는 수준으로 충분).
    final MockSpot? spot = post.spotId != null ? dbSpotCache['db-${post.spotId}'] : null;
    // 채택 버튼은 아직 채택된 답변이 없고, 이 질문을 "내"가 쓴 경우에만 노출한다.
    // 백엔드 응답엔 소유 여부 플래그가 없어 닉네임으로 판단 — 실제 권한 체크는
    // 어차피 adopt API가 403으로 최종 검증한다(_adopt의 403 처리 참고).
    final isMine = AuthTokenStore.nickname != null && AuthTokenStore.nickname == post.userNickname;

    // 채택 정렬: 채택된 답변을 맨 위로
    final sortedAnswers = [...detail.answers]
      ..sort((a, b) => (b.adopted ? 1 : 0) - (a.adopted ? 1 : 0));

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
                  Text(l10n.qnaPostDetailPageTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                  const Spacer(),
                  TextButton(
                    onPressed: _report,
                    child: Text(l10n.qnaPostDetailReportButton, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 8))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
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
                          const SizedBox(height: 10),
                          Text(post.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.4, color: CocoTheme.secondary)),
                          const SizedBox(height: 10),
                          Text(post.content, style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade800)),
                          if (post.spotId != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              // go()로 이동하면 뒤로가기 스택이 리셋돼서 스팟 상세의
                              // 뒤로가기 버튼이 먹통이 됨 — push로 스택에 쌓이게 함.
                              onTap: () => context.push('/map/spot/db-${post.spotId}'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black.withOpacity(0.07)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: (spot?.pinColor ?? CocoTheme.secondary).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(spot?.icon ?? Icons.place_rounded, size: 20, color: (spot?.pinColor ?? CocoTheme.secondary).withOpacity(0.6)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(spot?.name ?? post.spotName ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                                          if (spot != null) Text(spot.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    Text(l10n.qnaPostDetailViewOnMap, style: const TextStyle(fontSize: 12, color: CocoTheme.primary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(l10n.qnaPostDetailLanguageNotice, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.qnaAnswerCount(sortedAnswers.length), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                          Text(l10n.qnaPostDetailAutoRefreshHint, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                    for (final a in sortedAnswers)
                      _AnswerCard(
                        answer: a,
                        showAdoptButton: post.adoptedAnswerId == null && isMine,
                        onAdopt: () => _adopt(a.id),
                      ),
                    const SizedBox(height: 16),
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
                      controller: _answerController,
                      decoration: InputDecoration(
                        hintText: l10n.qnaPostDetailAnswerHint,
                        filled: true,
                        fillColor: const Color(0xFFF6F6F4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _submitAnswer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: CocoTheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _submitAnswer,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(width: 40, height: 40, child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18)),
                    ),
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

class _AnswerCard extends StatelessWidget {
  final QnaAnswer answer;
  final bool showAdoptButton;
  final VoidCallback onAdopt;

  const _AnswerCard({
    required this.answer,
    required this.showAdoptButton,
    required this.onAdopt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdopted = answer.adopted;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAdopted ? const Color(0xFFF4F9FE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isAdopted ? CocoTheme.primary : Colors.black.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFF0ECE6),
                child: Text(answer.authorInitial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
              ),
              const SizedBox(width: 8),
              Text(answer.userNickname, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
              if (answer.isLocal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(9)),
                  child: Text(l10n.feedLocalBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                ),
              ],
              if (isAdopted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: CocoTheme.primary, borderRadius: BorderRadius.circular(9)),
                  child: Text(l10n.qnaAdoptedBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
              const Spacer(),
              Text(_relativeTimeLabel(answer.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 10),
          Text(answer.content, style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade800)),
          if (showAdoptButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: CocoTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onAdopt,
                child: Text(l10n.qnaAdoptButton, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.primary)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// qna_screen.dart와 동일한 소소한 상대 시간 포맷터 — 화면 파일마다 필요한 만큼만
// 갖는 기존 코드베이스 패턴(feed_mock_data.dart의 _relativeTimeLabel 참고).
String _relativeTimeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 2) return '어제';
  return '${diff.inDays}일 전';
}
