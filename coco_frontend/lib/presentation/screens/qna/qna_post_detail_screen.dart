import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_type.dart';
import 'qna_mock_data.dart';

/// 질문 상세 + 답변 채택 화면. QnaScreen에서 push할 때 같은 QnaPost 인스턴스를
/// extra로 전달받아 직접 mutate한다 (feed 상세 화면과 동일한 패턴).
class QnaPostDetailScreen extends StatefulWidget {
  final QnaPost post;
  const QnaPostDetailScreen({super.key, required this.post});

  @override
  State<QnaPostDetailScreen> createState() => _QnaPostDetailScreenState();
}

class _QnaPostDetailScreenState extends State<QnaPostDetailScreen> {
  final _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _adopt(String answerId) {
    setState(() => widget.post.adoptedAnswerId = answerId);
  }

  void _submitAnswer() {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.post.answers.add(QnaAnswer(
        id: 'a${DateTime.now().millisecondsSinceEpoch}',
        author: '나',
        isLocal: false,
        content: text,
        timeLabel: '방금',
      ));
    });
    _answerController.clear();
  }

  void _report() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('신고가 접수되었습니다'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isLocalAuthor = post.authorRole == UserType.local;
    final spot = post.taggedSpot;

    // 채택 정렬: 채택된 답변을 맨 위로
    final sortedAnswers = [...post.answers]
      ..sort((a, b) => (b.id == post.adoptedAnswerId ? 1 : 0) - (a.id == post.adoptedAnswerId ? 1 : 0));

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
                  const Text('질문', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                  const Spacer(),
                  TextButton(
                    onPressed: _report,
                    child: Text('신고', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isLocalAuthor ? const Color(0xFFE6F1FB) : const Color(0xFFF4F4F2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isLocalAuthor ? '로컬' : '관광객',
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
                          const SizedBox(height: 10),
                          Text(post.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.4, color: CocoTheme.secondary)),
                          const SizedBox(height: 10),
                          Text(post.content, style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade800)),
                          if (spot != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              // go()로 이동하면 뒤로가기 스택이 리셋돼서 스팟 상세의
                              // 뒤로가기 버튼이 먹통이 됨 — push로 스택에 쌓이게 함.
                              onTap: () => context.push('/map/spot/${spot.id}'),
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
                                        color: spot.pinColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(spot.icon, size: 20, color: spot.pinColor.withOpacity(0.6)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(spot.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                                          Text(spot.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    const Text('지도에서 보기', style: TextStyle(fontSize: 12, color: CocoTheme.primary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text('이 질문은 한국어로 작성되었어요', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('답변 ${post.answers.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                          Text('15초마다 자동 새로고침', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                    for (final a in sortedAnswers)
                      _AnswerCard(
                        answer: a,
                        isAdopted: a.id == post.adoptedAnswerId,
                        // 채택 버튼은 아직 채택된 답변이 없고, 이 질문을 "내"가 쓴 경우에만 노출.
                        // TODO: 로그인/세션 연동 후 post.mine 대신 실제 로그인 유저 id와 post.userId 비교로 교체.
                        showAdoptButton: post.adoptedAnswerId == null && post.mine,
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
                        hintText: '답변을 남겨보세요',
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
  final bool isAdopted;
  final bool showAdoptButton;
  final VoidCallback onAdopt;

  const _AnswerCard({
    required this.answer,
    required this.isAdopted,
    required this.showAdoptButton,
    required this.onAdopt,
  });

  @override
  Widget build(BuildContext context) {
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
              Text(answer.author, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
              if (answer.isLocal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(9)),
                  child: const Text('로컬', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                ),
              ],
              if (isAdopted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: CocoTheme.primary, borderRadius: BorderRadius.circular(9)),
                  child: const Text('✓ 채택됨', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
              const Spacer(),
              Text(answer.timeLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
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
                child: const Text('이 답변 채택하기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.primary)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
