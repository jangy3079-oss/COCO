import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'feed_mock_data.dart';

class _ComposerPhoto {
  final String id;
  final Color color;
  const _ComposerPhoto({required this.id, required this.color});
}

const _photoPalette = [
  Color(0xFFF6D9C9),
  Color(0xFFE7E4DE),
  Color(0xFFD9E8D3),
  Color(0xFFE8DCCB),
  Color(0xFFDCE6EF),
];

/// 게시물 작성 4단계 위저드: 사진 → 장소 태그 → 카테고리 → 한줄 설명.
/// 제출하면 공유 목업 리스트(mockFeedItems) 맨 앞에 새 게시물을 추가하고
/// 피드 화면으로 돌아간다.
class FeedComposerScreen extends StatefulWidget {
  const FeedComposerScreen({super.key});

  @override
  State<FeedComposerScreen> createState() => _FeedComposerScreenState();
}

class _FeedComposerScreenState extends State<FeedComposerScreen> {
  static const _categories = ['노포', '골목', '공원', '카페'];

  int _step = 1;
  final List<_ComposerPhoto> _photos = [];
  String? _selectedLocation;
  String _locationQuery = '';
  String? _selectedCategory;
  final _descController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  bool get _nextEnabled => switch (_step) {
        1 => _photos.isNotEmpty,
        2 => _selectedLocation != null,
        3 => _selectedCategory != null,
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

  void _addPhoto() {
    setState(() {
      _photos.add(_ComposerPhoto(
        id: 'p${DateTime.now().microsecondsSinceEpoch}',
        color: _photoPalette[_photos.length % _photoPalette.length],
      ));
    });
  }

  void _removePhoto(String id) => setState(() => _photos.removeWhere((p) => p.id == id));

  Future<void> _submit() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final maxTs = mockFeedItems.isEmpty ? 0 : mockFeedItems.map((e) => e.ts).reduce((a, b) => a > b ? a : b);
    mockFeedItems.insert(
      0,
      FeedItem(
        id: 'u${DateTime.now().millisecondsSinceEpoch}',
        source: FeedSource.user,
        author: '나',
        category: _selectedCategory!,
        place: _selectedLocation!,
        desc: desc,
        neighborhood: '내 동네',
        dongId: 'nampo',
        distanceMin: 1,
        likes: 0,
        saves: 0,
        imgCount: _photos.isEmpty ? 1 : _photos.length,
        ts: maxTs + 1,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded)),
                  Text('게시물 작성 ($_step/4)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  for (int i = 1; i <= 4; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? CocoTheme.primary : Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i != 4) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: switch (_step) {
                  1 => _PhotoStep(photos: _photos, onAdd: _addPhoto, onRemove: _removePhoto),
                  2 => _LocationStep(
                      query: _locationQuery,
                      selected: _selectedLocation,
                      onQueryChanged: (v) => setState(() => _locationQuery = v),
                      onSelect: (v) => setState(() => _selectedLocation = v),
                      onPinOnMap: () => setState(() => _selectedLocation = '지도에서 선택한 위치'),
                    ),
                  3 => _CategoryStep(
                      categories: _categories,
                      selected: _selectedCategory,
                      onSelect: (v) => setState(() => _selectedCategory = v),
                    ),
                  _ => _DescriptionStep(controller: _descController, onChanged: (_) => setState(() {})),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _step == 4
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _descController.text.trim().isNotEmpty ? CocoTheme.primary : Colors.black.withOpacity(0.2),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submit,
                      child: Text(
                        _submitting ? '게시 중...' : '게시하기',
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
                      child: const Text('다음', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoStep extends StatelessWidget {
  final List<_ComposerPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  const _PhotoStep({required this.photos, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('사진을 올려주세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final p in photos)
              Stack(
                children: [
                  Positioned.fill(
                    child: Container(decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(10))),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      onTap: () => onRemove(p.id),
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
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black.withOpacity(0.2), width: 1.5),
                ),
                child: Icon(Icons.add, size: 24, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('갤러리에서 선택하거나 촬영해서 추가하세요', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  final String query;
  final String? selected;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelect;
  final VoidCallback onPinOnMap;

  const _LocationStep({
    required this.query,
    required this.selected,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onPinOnMap,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = composerLocationCandidates.where((l) => l.contains(query)).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('장소를 태그해주세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
        const SizedBox(height: 12),
        TextField(
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: '장소명 검색',
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 90,
          decoration: BoxDecoration(color: const Color(0xFFEAE8E2), borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Icon(Icons.map_outlined, size: 28, color: Colors.black.withOpacity(0.25)),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPinOnMap,
          child: const Center(
            child: Text('지도에서 직접 핀 찍기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.primary)),
          ),
        ),
        const SizedBox(height: 8),
        for (final loc in suggestions)
          InkWell(
            onTap: () => onSelect(loc),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
              child: Text(
                loc,
                style: TextStyle(
                  fontSize: 14,
                  color: selected == loc ? CocoTheme.primary : CocoTheme.secondary,
                  fontWeight: selected == loc ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryStep extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _CategoryStep({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('카테고리를 선택해주세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
        const SizedBox(height: 12),
        for (final c in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => onSelect(c),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == c ? CocoTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected == c ? CocoTheme.primary : Colors.grey.shade300),
                ),
                child: Text(
                  c,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected == c ? Colors.white : CocoTheme.secondary),
                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('한줄 설명을 남겨주세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: 200,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '이 스팟에 대한 후기를 적어주세요',
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
