import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/locale/locale_controller.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/feed_post.dart';
import '../../../data/models/spot.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/spot_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../map/map_mock_data.dart';

const _maxFeedImages = 10;

/// 당근의 게시글 작성 화면처럼 사진·설명·장소·코스를 한 화면에서 입력한다.
class FeedComposerScreen extends StatefulWidget {
  final MockRoute? initialRoute;

  const FeedComposerScreen({super.key, this.initialRoute});

  @override
  State<FeedComposerScreen> createState() => _FeedComposerScreenState();
}

class _FeedComposerScreenState extends State<FeedComposerScreen> {
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _feedRepository = FeedRepository();
  final _spotRepository = SpotRepository();

  final List<Uint8List> _pickedImageBytes = [];
  final List<String> _uploadedImageUrls = [];
  final List<Spot> _searchResults = [];

  late MockRoute? _selectedRoute = widget.initialRoute;
  Spot? _selectedSpot;
  Timer? _searchDebounce;
  bool _uploadingImages = false;
  bool _searching = false;
  bool _loadingRoutes = true;
  bool _submitting = false;

  bool get _canSubmit =>
      _descriptionController.text.trim().isNotEmpty &&
      !_uploadingImages &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    await refreshMyRoutes();
    if (mounted) setState(() => _loadingRoutes = false);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxFeedImages - _pickedImageBytes.length;
    if (remaining <= 0 || _uploadingImages) return;

    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final selected = picked.take(remaining).toList();
    final bytes =
        await Future.wait(selected.map((image) => image.readAsBytes()));
    if (!mounted) return;

    setState(() {
      _pickedImageBytes.addAll(bytes);
      _uploadingImages = true;
    });

    try {
      final urls = <String>[];
      for (var i = 0; i < selected.length; i++) {
        urls.add(await _feedRepository.uploadImage(bytes[i], selected[i].name));
      }
      if (!mounted) return;
      setState(() {
        _uploadedImageUrls.addAll(urls);
        _uploadingImages = false;
      });
    } catch (e) {
      debugPrint('[FeedComposerScreen] 이미지 업로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _pickedImageBytes.removeRange(
          _pickedImageBytes.length - bytes.length,
          _pickedImageBytes.length,
        );
        _uploadingImages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.feedComposerPhotoUploadFailed)),
      );
    }
  }

  void _removePhoto(int index) {
    if (_uploadingImages) return;
    setState(() {
      _pickedImageBytes.removeAt(index);
      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }

  void _searchSpot(String query) {
    setState(() {
      if (_selectedSpot != null && query != _selectedSpot!.title) {
        _selectedSpot = null;
      }
    });
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (mounted) setState(() => _searching = true);
      try {
        final results = await _spotRepository.search(
          trimmed,
          locale: context.read<LocaleController>().locale.languageCode,
        );
        if (!mounted) return;
        setState(() {
          _searchResults
            ..clear()
            ..addAll(results.take(4));
          _searching = false;
        });
      } catch (e) {
        debugPrint('[FeedComposerScreen] 장소 검색 실패: $e');
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectSpot(Spot spot) {
    setState(() {
      _selectedSpot = spot;
      _locationController.text = spot.title;
      _searchResults.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _openRouteSheet() async {
    if (_loadingRoutes) {
      await refreshMyRoutes();
      if (!mounted) return;
      setState(() => _loadingRoutes = false);
    }
    final routes = mockMyRoutes
        .where((route) => !route.isDraft && route.stops.isNotEmpty)
        .toList();
    final selected = await showModalBottomSheet<MockRoute?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  AppLocalizations.of(sheetContext)!.feedRoutePickerTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loadingRoutes
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: CocoTheme.primary))
                    : routes.isEmpty
                        ? _EmptyRoutes(
                            onClose: () => Navigator.pop(sheetContext))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: routes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final route = routes[index];
                              return _RouteOption(
                                route: route,
                                selected: route.id == _selectedRoute?.id,
                                onTap: () => Navigator.pop(sheetContext, route),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _selectedRoute = selected);
  }

  Future<void> _submit() async {
    if (!_canSubmit || !requireLogin(context)) return;
    setState(() => _submitting = true);
    try {
      await _feedRepository.createPost(
        description: _descriptionController.text.trim(),
        spotId: _selectedSpot?.id,
        routeId: dbRouteNumericId(_selectedRoute?.id ?? ''),
        imageUrl: _uploadedImageUrls.isEmpty
            ? null
            : encodeFeedImageUrls(_uploadedImageUrls),
      );
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[FeedComposerScreen] 게시물 작성 실패: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.feedComposerPostFailed)),
      );
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
            )),
        title: Text(l10n.feedComposerPageTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PhotoPicker(
                      imageBytes: _pickedImageBytes,
                      uploading: _uploadingImages,
                      onAdd: _pickImages,
                      onRemove: _removePhoto,
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel(label: l10n.feedComposerDescStepTitle),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      maxLength: 300,
                      minLines: 5,
                      maxLines: 8,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l10n.feedComposerDescHint,
                        hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.32), height: 1.5),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(
                        label: l10n.feedComposerCourseLabel, optional: true),
                    const SizedBox(height: 10),
                    _AttachCard(
                      icon: Icons.route_rounded,
                      title: _selectedRoute?.name ??
                          l10n.feedComposerCoursePlaceholder,
                      subtitle: _selectedRoute == null
                          ? l10n.feedComposerCourseHint
                          : l10n.myRoutesStopsDistance(
                              _selectedRoute!.stops.length,
                              _selectedRoute!.distanceKm.toStringAsFixed(1),
                            ),
                      selected: _selectedRoute != null,
                      onTap: _openRouteSheet,
                      onClear: _selectedRoute == null
                          ? null
                          : () => setState(() => _selectedRoute = null),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: l10n.feedComposerLocationStepTitle),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _locationController,
                      onChanged: _searchSpot,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.feedComposerLocationSearchHint,
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.38),
                        ),
                        prefixIcon: const Icon(Icons.place_outlined,
                            color: CocoTheme.primary),
                        suffixIcon: _selectedSpot == null
                            ? null
                            : const Icon(Icons.check_circle_rounded,
                                color: CocoTheme.primary),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      )
                    else if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.black.withOpacity(0.08)),
                        ),
                        child: Column(
                          children: [
                            for (final spot in _searchResults)
                              ListTile(
                                dense: true,
                                onTap: () => _selectSpot(spot),
                                title: Text(
                                  spot.title,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(spot.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: CocoTheme.primary,
                  disabledBackgroundColor: Colors.black.withOpacity(0.12),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _submitting
                      ? l10n.feedComposerSubmitting
                      : l10n.feedComposerSubmitButton,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final List<Uint8List> imageBytes;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotoPicker(
      {required this.imageBytes,
      required this.uploading,
      required this.onAdd,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: l10n.feedComposerPhotoStepTitle),
        const SizedBox(height: 6),
        Text(
          l10n.feedComposerPhotoStepHint,
          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageBytes.length +
                (imageBytes.length < _maxFeedImages ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == imageBytes.length) {
                return InkWell(
                  onTap: uploading ? null : onAdd,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 108,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.12)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_camera_outlined,
                            color: CocoTheme.primary, size: 27),
                        const SizedBox(height: 7),
                        Text(
                          '${imageBytes.length}/$_maxFeedImages',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CocoTheme.primary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(imageBytes[index],
                        width: 108, height: 108, fit: BoxFit.cover),
                  ),
                  if (index == 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: CocoTheme.primary,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          '대표',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (!uploading)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: GestureDetector(
                        onTap: () => onRemove(index),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.58),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (uploading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2, color: CocoTheme.primary),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _SectionLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CocoTheme.secondary),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context)!.feedComposerOptional,
            style:
                TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35)),
          ),
        ],
      ],
    );
  }
}

class _AttachCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _AttachCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2F9FE) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? CocoTheme.primary.withOpacity(0.45)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: CocoTheme.primary.withOpacity(0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: CocoTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.black.withOpacity(0.43))),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 19))
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  final MockRoute route;
  final bool selected;
  final VoidCallback onTap;

  const _RouteOption(
      {required this.route, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2F9FE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected
                  ? CocoTheme.primary
                  : Colors.black.withOpacity(0.09)),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_rounded, color: CocoTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    AppLocalizations.of(context)!.myRoutesStopsDistance(
                      route.stops.length,
                      route.distanceKm.toStringAsFixed(1),
                    ),
                    style: TextStyle(
                        fontSize: 11, color: Colors.black.withOpacity(0.43)),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: CocoTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoutes extends StatelessWidget {
  final VoidCallback onClose;

  const _EmptyRoutes({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signpost_outlined,
                color: CocoTheme.primary, size: 36),
            const SizedBox(height: 12),
            Text(l10n.feedRoutePickerEmpty,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(
              l10n.feedRoutePickerEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.black.withOpacity(0.43)),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onClose, child: const Text('확인')),
          ],
        ),
      ),
    );
  }
}
