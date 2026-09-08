import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_type.dart';
import '../map/map_mock_data.dart';
import 'qna_mock_data.dart';

/// 질문 작성 화면. 제출하면 공유 목업 리스트(qnaMockPosts) 맨 앞에 추가하고
/// 커뮤니티 목록으로 돌아간다.
class QnaComposerScreen extends StatefulWidget {
  const QnaComposerScreen({super.key});

  @override
  State<QnaComposerScreen> createState() => _QnaComposerScreenState();
}

class _QnaComposerScreenState extends State<QnaComposerScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _selectedSpot;

  bool get _canSubmit => _titleController.text.trim().isNotEmpty && _bodyController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    final maxTs = qnaMockPosts.isEmpty ? 0 : qnaMockPosts.map((p) => p.ts).reduce((a, b) => a > b ? a : b);
    qnaMockPosts.insert(
      0,
      QnaPost(
        id: 'q${DateTime.now().millisecondsSinceEpoch}',
        authorRole: UserType.tourist,
        title: _titleController.text.trim(),
        content: _bodyController.text.trim(),
        spotName: _selectedSpot,
        timeLabel: '방금',
        ts: maxTs + 1,
        mine: true,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('취소', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ),
                  const Expanded(
                    child: Text(
                      '질문 작성',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary),
                    ),
                  ),
                  TextButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: Text(
                      '등록',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _canSubmit ? CocoTheme.primary : Colors.grey.shade400),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CocoTheme.secondary),
                      decoration: InputDecoration(
                        hintText: '제목',
                        border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _bodyController,
                      onChanged: (_) => setState(() {}),
                      maxLines: 8,
                      minLines: 5,
                      style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade800),
                      decoration: const InputDecoration(
                        hintText: '이 동네에 대해 궁금한 걸 물어보세요',
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('장소 태그', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                        const SizedBox(width: 6),
                        Text('선택', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final spot in mockSpots)
                          _SpotTagChip(
                            label: spot.name,
                            selected: _selectedSpot == spot.name,
                            onTap: () => setState(() => _selectedSpot = _selectedSpot == spot.name ? null : spot.name),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFF4F8FC), borderRadius: BorderRadius.circular(12)),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 12, height: 1.6, color: Colors.grey.shade700),
                          children: const [
                            TextSpan(text: '이 질문은 '),
                            TextSpan(text: '한국어', style: TextStyle(color: CocoTheme.primary, fontWeight: FontWeight.w700)),
                            TextSpan(text: '로 게시돼요. 로컬 주민이 가능하면 같은 언어로 답변해요.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotTagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SpotTagChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F1FB) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? CocoTheme.primary : Colors.grey.shade700),
        ),
      ),
    );
  }
}
