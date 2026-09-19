import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/spot.dart';
import '../../../data/repositories/qna_repository.dart';
import '../../../data/repositories/spot_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 질문 작성 화면. 제출하면 실제 백엔드(POST /api/qna/posts)에 등록하고
/// 커뮤니티 목록으로 돌아간다.
class QnaComposerScreen extends StatefulWidget {
  const QnaComposerScreen({super.key});

  @override
  State<QnaComposerScreen> createState() => _QnaComposerScreenState();
}

class _QnaComposerScreenState extends State<QnaComposerScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _qnaRepository = QnaRepository();
  final _spotRepository = SpotRepository();

  // 실제 DB 스팟 검색(GET /api/spot/search) — feed_composer_screen.dart의
  // "장소를 태그해주세요" 단계와 동일한 패턴(타이핑 300ms 디바운스).
  Spot? _selectedSpot;
  String _spotQuery = '';
  List<Spot> _spotResults = [];
  bool _spotSearching = false;
  Timer? _spotSearchDebounce;
  bool _submitting = false;

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty &&
      !_submitting;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _spotSearchDebounce?.cancel();
    super.dispose();
  }

  void _onSpotQueryChanged(String query) {
    setState(() => _spotQuery = query);
    _spotSearchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _spotResults = []);
      return;
    }
    _spotSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _spotSearching = true);
      try {
        final results = await _spotRepository.search(
          q,
          locale: context.read<LocaleController>().locale.languageCode,
        );
        if (!mounted) return;
        setState(() {
          _spotResults = results;
          _spotSearching = false;
        });
      } catch (e) {
        debugPrint('[QnaComposerScreen] 스팟 검색 실패: $e');
        if (mounted) setState(() => _spotSearching = false);
      }
    });
  }

  void _selectSpot(Spot spot) {
    setState(() {
      _selectedSpot = spot;
      _spotQuery = '';
      _spotResults = [];
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (!requireLogin(context)) return;

    setState(() => _submitting = true);
    try {
      await _qnaRepository.createPost(
        title: _titleController.text.trim(),
        content: _bodyController.text.trim(),
        spotId: _selectedSpot?.id,
        locale: context.read<LocaleController>().locale.languageCode,
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      debugPrint('[QnaComposerScreen] 질문 작성 실패: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.qnaComposerSubmitFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 4,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 21,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                  ),
                  Text(
                    l10n.qnaComposerTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: CocoTheme.secondary,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: TextButton(
                      onPressed: _canSubmit ? _submit : null,
                      child: Text(
                        l10n.feedPostDetailCommentSubmit,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _canSubmit
                              ? CocoTheme.primary
                              : Colors.grey.shade400,
                        ),
                      ),
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
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: CocoTheme.secondary),
                      decoration: InputDecoration(
                        hintText: l10n.qnaComposerTitleHint,
                        border: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _bodyController,
                      onChanged: (_) => setState(() {}),
                      maxLines: 8,
                      minLines: 5,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: Colors.grey.shade800),
                      decoration: InputDecoration(
                        hintText: l10n.qnaComposerBodyHint,
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(l10n.qnaComposerSpotTagLabel,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: CocoTheme.secondary)),
                        const SizedBox(width: 6),
                        Text(l10n.qnaComposerOptionalLabel,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_selectedSpot != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SpotTagChip(
                            label: _selectedSpot!.title,
                            selected: true,
                            onTap: () => setState(() => _selectedSpot = null),
                          ),
                        ],
                      )
                    else ...[
                      TextField(
                        onChanged: _onSpotQueryChanged,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: l10n.feedComposerLocationSearchHint,
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8F8F8),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                        ),
                      ),
                      if (_spotSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                        )
                      else if (_spotQuery.trim().isNotEmpty &&
                          _spotResults.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(l10n.feedComposerLocationNoResults,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500)),
                        )
                      else if (_spotResults.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final spot in _spotResults)
                                _SpotTagChip(
                                    label: spot.title,
                                    selected: false,
                                    onTap: () => _selectSpot(spot)),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF4F8FC),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Colors.grey.shade700),
                          children: [
                            TextSpan(
                                text: l10n.qnaComposerLanguageNoticePrefix),
                            TextSpan(
                                text: l10n.qnaComposerLanguageNoticeLang,
                                style: const TextStyle(
                                    color: CocoTheme.primary,
                                    fontWeight: FontWeight.w700)),
                            TextSpan(
                                text: l10n.qnaComposerLanguageNoticeSuffix),
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
  const _SpotTagChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F1FB) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? CocoTheme.primary : Colors.grey.shade700),
          child: Text(label),
        ),
      ),
    );
  }
}
