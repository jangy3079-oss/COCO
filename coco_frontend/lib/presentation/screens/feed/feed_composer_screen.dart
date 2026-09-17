import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/spot.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/spot_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 게시물 작성 3단계 위저드: 사진(선택) → 스팟 태그(실제 검색) → 한줄 설명.
/// 제출하면 coco_backend POST /api/feed로 실제 게시물을 만든다. 사진을 고르면
/// 그 자리에서 바로 POST /api/feed/images로 업로드해 imageUrl을 미리 받아두고,
/// 최종 게시 시 그 값을 함께 보낸다 — 사진은 선택이라 안 골라도 게시할 수 있다.
/// (예전엔 카테고리를 따로 고르는 4번째 단계가 있었지만, 실제 스팟을 태그하면
///  카테고리는 그 스팟이 이미 갖고 있어서 없앴다.)
class FeedComposerScreen extends StatefulWidget {
  const FeedComposerScreen({super.key});

  @override
  State<FeedComposerScreen> createState() => _FeedComposerScreenState();
}

class _FeedComposerScreenState extends State<FeedComposerScreen> {
  static const _totalSteps = 3;

  int _step = 1;
  Uint8List? _pickedImageBytes;
  bool _uploadingImage = false;
  String? _uploadedImageUrl;

  Spot? _selectedSpot;
  String _locationQuery = '';
  List<Spot> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  final _descController = TextEditingController();
  bool _submitting = false;

  final _spotRepository = SpotRepository();
  final _feedRepository = FeedRepository();

  @override
  void dispose() {
    _descController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  bool get _nextEnabled => switch (_step) {
        1 => true, // 사진은 선택이라 안 골라도 다음으로 넘어갈 수 있음
        2 => true, // 스팟 태그도 선택 — 안 골라도 다음으로 넘어갈 수 있음
        _ => true,
      };

  void _back() {
    if (_step > 1) {
      setState(() => _step -= 1);
    } else {
      context.pop();
    }
  }

  void _next() {
    if (!_nextEnabled) return;
    setState(() => _step += 1);
  }

  // 사진은 한 장만 지원(백엔드 feed_posts.image_url이 단일 컬럼) — 고르는 즉시 업로드해서
  // imageUrl을 미리 받아두면, 최종 "게시하기" 시점엔 이미 준비된 URL만 붙이면 된다.
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImageBytes = bytes;
      _uploadedImageUrl = null;
      _uploadingImage = true;
    });
    try {
      final url = await _feedRepository.uploadImage(bytes, picked.name);
      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = url;
        _uploadingImage = false;
      });
    } catch (e) {
      debugPrint('[FeedComposerScreen] 이미지 업로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _pickedImageBytes = null;
        _uploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.feedComposerPhotoUploadFailed)),
      );
    }
  }

  void _removePhoto() => setState(() {
        _pickedImageBytes = null;
        _uploadedImageUrl = null;
      });

  // 스팟 검색은 DB 조회(네트워크 호출)라 타이핑마다 바로 쏘지 않고 300ms 디바운스한다.
  // (route_builder_screen.dart의 "+ 스팟 추가" 검색과 동일한 패턴.)
  void _onLocationQueryChanged(String query) {
    setState(() => _locationQuery = query);
    _searchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final results = await _spotRepository.search(q);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      } catch (e) {
        debugPrint('[FeedComposerScreen] 스팟 검색 실패: $e');
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _submit() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty || _submitting || _uploadingImage) return;
    setState(() => _submitting = true);
    try {
      await _feedRepository.createPost(description: desc, spotId: _selectedSpot?.id, imageUrl: _uploadedImageUrl);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      debugPrint('[FeedComposerScreen] 게시물 작성 실패: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.feedComposerPostFailed)),
      );
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded)),
                  Text(l10n.feedComposerStepTitle(_step, _totalSteps), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  for (int i = 1; i <= _totalSteps; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? CocoTheme.primary : Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i != _totalSteps) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: switch (_step) {
                  1 => _PhotoStep(
                      imageBytes: _pickedImageBytes,
                      uploading: _uploadingImage,
                      onAdd: _pickImage,
                      onRemove: _removePhoto,
                    ),
                  2 => _LocationStep(
                      query: _locationQuery,
                      selected: _selectedSpot,
                      results: _searchResults,
                      searching: _searching,
                      onQueryChanged: _onLocationQueryChanged,
                      onSelect: (v) => setState(() => _selectedSpot = v),
                    ),
                  _ => _DescriptionStep(controller: _descController, onChanged: (_) => setState(() {})),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _step == _totalSteps
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _descController.text.trim().isNotEmpty && !_uploadingImage
                            ? CocoTheme.primary
                            : Colors.black.withOpacity(0.2),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _uploadingImage ? null : _submit,
                      child: Text(
                        _submitting ? l10n.feedComposerSubmitting : l10n.feedComposerSubmitButton,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _nextEnabled ? CocoTheme.primary : Colors.black.withOpacity(0.2),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _next,
                      child: Text(l10n.feedComposerNextButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진은 한 장만 지원(백엔드가 단일 imageUrl 컬럼) — 없어도 다음 단계로 넘어갈 수 있다.
class _PhotoStep extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool uploading;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _PhotoStep({required this.imageBytes, required this.uploading, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.feedComposerPhotoStepTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
        const SizedBox(height: 12),
        SizedBox(
          width: 120,
          height: 120,
          child: imageBytes == null
              ? InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withOpacity(0.2), width: 1.5),
                    ),
                    child: Icon(Icons.add, size: 24, color: Colors.grey.shade500),
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(imageBytes!, fit: BoxFit.cover),
                      ),
                    ),
                    if (uploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    if (!uploading)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text(l10n.feedComposerPhotoStepHint, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  final String query;
  final Spot? selected;
  final List<Spot> results;
  final bool searching;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Spot> onSelect;

  const _LocationStep({
    required this.query,
    required this.selected,
    required this.results,
    required this.searching,
    required this.onQueryChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.feedComposerLocationStepTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
        const SizedBox(height: 12),
        TextField(
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: l10n.feedComposerLocationSearchHint,
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
        const SizedBox(height: 8),
        if (searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (query.trim().isNotEmpty && results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.feedComposerLocationNoResults, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          )
        else
          for (final spot in results)
            InkWell(
              onTap: () => onSelect(spot),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.title,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected?.id == spot.id ? CocoTheme.primary : CocoTheme.secondary,
                              fontWeight: selected?.id == spot.id ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(spot.address, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
                        ],
                      ),
                    ),
                    if (selected?.id == spot.id) const Icon(Icons.check_rounded, size: 18, color: CocoTheme.primary),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _DescriptionStep extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _DescriptionStep({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.feedComposerDescStepTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: 200,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: l10n.feedComposerDescHint,
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }
}
