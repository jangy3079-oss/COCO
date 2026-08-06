import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'map_mock_data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 실제 스팟 category 값(spots.category: 노포|공원|카페|골목)에 맞춘 필터
  static const _categories = ['전체', '노포', '골목', '공원', '카페'];
  String _selectedCategory = '전체';

  // 골목지도(코스)에 담을 스팟 — "주변 스팟" 목록에서 북마크로 선택
  final Set<String> _savedSpotIds = {};

  List<MockSpot> get _filteredSpots => _selectedCategory == '전체'
      ? mockSpots
      : mockSpots.where((s) => s.category == _selectedCategory).toList();

  void _toggleSaved(String spotId) {
    setState(() {
      if (_savedSpotIds.contains(spotId)) {
        _savedSpotIds.remove(spotId);
      } else {
        _savedSpotIds.add(spotId);
      }
    });
  }

  void _openSpotDetail(MockSpot spot) {
    context.push('/map/spot/${spot.id}');
  }

  void _handleSaveCourse() {
    if (_savedSpotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('담고 싶은 스팟을 먼저 북마크해주세요')),
      );
      return;
    }
    final selectedStops =
        mockSpots.where((s) => _savedSpotIds.contains(s.id)).toList();
    context.push('/map/route/new', extra: selectedStops);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CocoTheme.surface,
      // 검색창 포커스로 키보드가 뜰 때 지도 레이아웃 전체가 눌려서 바텀시트가
      // 찌그러지는 걸 방지 (지도 화면은 키보드가 위에 떠 있는 형태가 자연스러움)
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: const _MapHeaderBar(),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sheetCollapsedHeight = constraints.maxHeight * 0.32;
                return Stack(
                  children: [
                    // 지도 영역 — 좌우/여백 없이 화면 전체를 채움
                    Positioned.fill(
                      child: _MockMapBackground(
                        spots: _filteredSpots,
                        onSpotTap: _openSpotDetail,
                      ),
                    ),
                    // 검색창 + 카테고리 필터 (지도 위에 떠 있는 형태)
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 16,
                      child: Column(
                        children: [
                          const _MapSearchBar(),
                          const SizedBox(height: 12),
                          _CategoryChipsRow(
                            categories: _categories,
                            selected: _selectedCategory,
                            onSelected: (c) => setState(() => _selectedCategory = c),
                          ),
                        ],
                      ),
                    ),
                    // 현재 위치로 재중심 버튼
                    Positioned(
                      right: 16,
                      bottom: sheetCollapsedHeight + 16,
                      child: const _RecenterButton(),
                    ),
                    // 하단 "주변 스팟" 바텀시트 (드래그로 확장 가능)
                    _NearbySpotsSheet(
                      spots: _filteredSpots,
                      savedSpotIds: _savedSpotIds,
                      onToggleSaved: _toggleSaved,
                      onSpotTap: _openSpotDetail,
                      onSaveCourse: _handleSaveCourse,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeaderBar extends StatelessWidget {
  const _MapHeaderBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'COCO',
          style: TextStyle(
            color: CocoTheme.primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFFEFEAE4),
        ),
      ],
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          hintText: '골목, 노포, 공원 검색...',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChipsRow({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in categories) ...[
            _CategoryChip(
              label: category,
              selected: category == selected,
              onTap: () => onSelected(category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? CocoTheme.primary : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : CocoTheme.secondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MockMapBackground extends StatelessWidget {
  final List<MockSpot> spots;
  final ValueChanged<MockSpot> onSpotTap;
  const _MockMapBackground({required this.spots, required this.onSpotTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Container(
          color: const Color(0xFFE8E2D8),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 건물 블록
              _block(left: w * 0.05, top: h * 0.08, width: w * 0.22, height: h * 0.16, color: const Color(0xFFE0D5C8)),
              _block(left: w * 0.62, top: h * 0.06, width: w * 0.22, height: h * 0.12, color: const Color(0xFFE0D5C8)),
              _block(left: w * 0.05, top: h * 0.56, width: w * 0.22, height: h * 0.20, color: const Color(0xFFE0D5C8)),
              _block(left: w * 0.62, top: h * 0.62, width: w * 0.16, height: h * 0.14, color: const Color(0xFFE0D5C8)),
              // 공원 블록
              _block(left: w * 0.46, top: h * 0.30, width: w * 0.28, height: h * 0.22, color: const Color(0xFFA8C9A8)),
              // 강/수변 블록
              _block(left: w * 0.76, top: h * 0.78, width: w * 0.32, height: h * 0.32, color: const Color(0xFFB8D4E3)),
              // 도로 (세로)
              _road(left: w * 0.35, top: 0, width: 2, height: h),
              _road(left: w * 0.62, top: 0, width: 2, height: h),
              _road(left: w * 0.86, top: 0, width: 2, height: h),
              // 도로 (가로)
              _road(left: 0, top: h * 0.55, width: w, height: 2),
              // 동네 이름
              Positioned(left: w * 0.06, top: h * 0.40, child: _neighborhoodLabel('중구')),
              Positioned(left: w * 0.48, top: h * 0.66, child: _neighborhoodLabel('남포동')),
              // 스팟 핀
              for (final spot in spots)
                Positioned(
                  left: w * spot.left - 60,
                  top: h * spot.top,
                  width: 120,
                  child: _SpotPin(spot: spot, onTap: () => onSpotTap(spot)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _block({
    required double left,
    required double top,
    required double width,
    required double height,
    required Color color,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _road({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(color: Colors.white.withOpacity(0.85)),
    );
  }

  Widget _neighborhoodLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: CocoTheme.secondary.withOpacity(0.28),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SpotPin extends StatelessWidget {
  final MockSpot spot;
  final VoidCallback onTap;
  const _SpotPin({required this.spot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              spot.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CocoTheme.secondary),
            ),
          ),
          const SizedBox(height: 2),
          Icon(Icons.location_on, color: spot.pinColor, size: 30),
        ],
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.my_location_rounded, color: CocoTheme.primary, size: 20),
    );
  }
}

class _NearbySpotsSheet extends StatelessWidget {
  final List<MockSpot> spots;
  final Set<String> savedSpotIds;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<MockSpot> onSpotTap;
  final VoidCallback onSaveCourse;

  const _NearbySpotsSheet({
    required this.spots,
    required this.savedSpotIds,
    required this.onToggleSaved,
    required this.onSpotTap,
    required this.onSaveCourse,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.18,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('주변 스팟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text('${spots.length}곳', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: spots.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, i) => _SpotListTile(
                    spot: spots[i],
                    saved: savedSpotIds.contains(spots[i].id),
                    onToggleSaved: () => onToggleSaved(spots[i].id),
                    onTap: () => onSpotTap(spots[i]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CocoTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onSaveCourse,
                  child: const Text('코스 저장하기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpotListTile extends StatelessWidget {
  final MockSpot spot;
  final bool saved;
  final VoidCallback onToggleSaved;
  final VoidCallback onTap;

  const _SpotListTile({
    required this.spot,
    required this.saved,
    required this.onToggleSaved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: spot.pinColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(spot.icon, color: spot.pinColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(spot.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggleSaved,
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            color: saved ? CocoTheme.primary : Colors.grey.shade500,
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_rounded),
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}
