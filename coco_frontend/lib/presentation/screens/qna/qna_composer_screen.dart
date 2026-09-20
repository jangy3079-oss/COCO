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
  final _spotController = TextEditingController();
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
    _spotController.dispose();
    _spotSearchDebounce?.cancel();
    super.dispose();
  }

  void _onSpotQueryChanged(String query) {
    setState(() {
      _spotQuery = query;
      if (_selectedSpot != null && query != _selectedSpot!.title) {
        _selectedSpot = null;
      }
    });
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
      _spotQuery = spot.title;
      _spotController.text = spot.title;
      _spotController.selection = TextSelection.collapsed(
        offset: _spotController.text.length,
      );
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.close_rounded,
            size: 21,
            color: Color(0xFF9AA0A6),
          ),
        ),
        title: Text(
          l10n.qnaComposerTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(
              l10n.feedPostDetailCommentSubmit,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _canSubmit ? CocoTheme.primary : Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
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
                    TextField(
                      controller: _spotController,
                      onChanged: _onSpotQueryChanged,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.feedComposerLocationSearchHint,
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withValues(alpha: 0.38),
                        ),
                        prefixIcon: const Icon(
                          Icons.place_outlined,
                          color: CocoTheme.primary,
                        ),
                        suffixIcon: _selectedSpot == null
                            ? null
                            : const Icon(
                                Icons.check_circle_rounded,
                                color: CocoTheme.primary,
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_spotSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_spotResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (final spot in _spotResults)
                              ListTile(
                                dense: true,
                                onTap: () => _selectSpot(spot),
                                title: Text(
                                  spot.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  spot.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                              ),
                          ],
                        ),
                      )
                    else if (_spotQuery.trim().isNotEmpty &&
                        _selectedSpot == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          l10n.feedComposerLocationNoResults,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
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
