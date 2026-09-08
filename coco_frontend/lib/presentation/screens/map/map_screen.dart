import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/map/kakao_map_view.dart';
import 'map_mock_data.dart';

// 하단 "주변 스팟" 시트의 스냅 지점(화면 높이 대비 비율) — 시트 자신과, 그 위에 떠
// 있는 플로팅 버튼(스팟등록/현재위치) 둘 다 이 값을 기준으로 위치를 맞춰야 하므로
// 파일 상단에 공유 상수로 뺐다.
const double kSheetCollapsedExtent = 0.09; // 아예 내리기 — 핸들+제목만 살짝 보임
const double kSheetMidExtent = 0.32; // 기본 상태
const double kSheetExpandedExtent = 0.92; // 아예 올리기 — 거의 전체화면

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 실제 스팟 category 값(spots.category: 노포|공원|카페|골목)에 맞춘 필터
  static const _categories = ['전체', '노포', '골목', '공원', '카페'];
  String _selectedCategory = '전체';

  // 지도 중심 좌표 — 진입 시 현재 위치로 재설정을 시도하고, 권한 거부/실패 시
  // mapDefaultCenterLat/Lng(부산 남포동)를 그대로 쓴다.
  double _centerLat = mapDefaultCenterLat;
  double _centerLng = mapDefaultCenterLng;
  // GPS로 실제 위치를 구했을 때만 true — 지도 위 "내 위치" 파란 점은 이 값이
  // true일 때만 표시한다(기본 좌표로 조용히 폴백한 경우에는 점을 띄우지 않음).
  bool _locationAvailable = false;

  // 지도 화면(뷰포트) 범위 — 드래그/줌이 끝날 때마다 갱신되며, 이 범위 안에 있는
  // 스팟만 지도/하단 시트에 표시한다(핀 밀집 방지). null이면 아직 한 번도 idle
  // 이벤트가 안 온 것이므로 전체를 보여준다. 실제 서버 연동 시에는 이 콜백에서
  // `/api/spot?swLat=...&neLat=...` 뷰포트 쿼리를 호출하도록 교체하면 된다.
  double? _swLat, _swLng, _neLat, _neLng;

  void _onBoundsChanged(double swLat, double swLng, double neLat, double neLng) {
    setState(() {
      _swLat = swLat;
      _swLng = swLng;
      _neLat = neLat;
      _neLng = neLng;
    });
  }

  // 하단 시트가 지금 화면의 몇 %를 차지하고 있는지 — 시트 위에 뜬 플로팅 버튼이
  // 시트를 따라 같이 움직이게 하려고 ValueNotifier로 공유한다(Stack 전체를
  // setState로 다시 그리지 않고 버튼 위치만 가볍게 갱신하기 위함).
  final ValueNotifier<double> _sheetExtent = ValueNotifier(kSheetMidExtent);

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _sheetExtent.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _centerLat = position.latitude;
        _centerLng = position.longitude;
        _locationAvailable = true;
      });
    } catch (_) {
      // 위치 조회 실패 시 기본 좌표(부산 남포동) 유지 — 지도 자체는 정상 동작해야 하므로 조용히 무시.
    }
  }

  List<MockSpot> get _filteredSpots {
    final byCategory = _selectedCategory == '전체'
        ? mockSpots
        : mockSpots.where((s) => s.category == _selectedCategory).toList();
    final swLat = _swLat, swLng = _swLng, neLat = _neLat, neLng = _neLng;
    if (swLat == null || swLng == null || neLat == null || neLng == null) {
      return byCategory;
    }
    return byCategory
        .where((s) => s.lat >= swLat && s.lat <= neLat && s.lng >= swLng && s.lng <= neLng)
        .toList();
  }

  // 찜(저장) 상태는 map_mock_data.dart의 공유 savedSpotIds를 그대로 사용한다
  // (스팟 상세 화면·MY탭과 동일한 상태를 공유해야 하므로 화면 로컬 State가 아님).
  void _toggleSaved(String spotId) {
    setState(() {
      if (savedSpotIds.contains(spotId)) {
        savedSpotIds.remove(spotId);
      } else {
        savedSpotIds.add(spotId);
      }
    });
  }

  void _openSpotDetail(MockSpot spot) {
    context.push('/map/spot/${spot.id}');
  }

  void _handleSaveCourse() {
    if (savedSpotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('담고 싶은 스팟을 먼저 북마크해주세요')),
      );
      return;
    }
    final selectedStops =
        mockSpots.where((s) => savedSpotIds.contains(s.id)).toList();
    context.push('/map/route/new', extra: selectedStops);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CocoTheme.surface,
      // 검색창 포커스로 키보드가 뜰 때 지도 레이아웃 전체가 눌려서 바텀시트가
      // 찌그러지는 걸 방지 (지도 화면은 키보드가 위에 떠 있는 형태가 자연스러움)
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 지도 영역 — 좌우/여백 없이 화면 전체를 채움
              Positioned.fill(
                child: KakaoMapView(
                  centerLat: _centerLat,
                  centerLng: _centerLng,
                  markers: [
                    for (final spot in _filteredSpots)
                      KakaoMapMarker(id: spot.id, lat: spot.lat, lng: spot.lng, name: spot.name),
                  ],
                  onMarkerTap: (spotId) => _openSpotDetail(mockSpotById(spotId)),
                  myLocationLat: _locationAvailable ? _centerLat : null,
                  myLocationLng: _locationAvailable ? _centerLng : null,
                  onBoundsChanged: _onBoundsChanged,
                ),
              ),
              // 타이틀 + 검색창 + 카테고리 필터 (지도 위에 블러 그라데이션과 함께 떠 있는 형태.
              // 피드/커뮤니티 탭과 동일한 타이틀 스타일 적용)
              // ShaderMask(dstIn)로 블러 레이어 자체의 알파를 아래쪽으로 갈수록 서서히 줄여서,
              // 블러가 있다가 갑자기 뚝 끊기지 않고 점점 옅어지며 사라지도록 처리.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.68, 1.0],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.6, 1.0],
                            colors: [
                              Colors.white.withOpacity(0.96),
                              Colors.white.withOpacity(0.78),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '지도',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CocoTheme.secondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '내 주변 골목과 노포를 찾아보세요',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Expanded(child: _MapSearchBar()),
                                    const SizedBox(width: 10),
                                    _MyRoutesButton(onTap: () => context.push('/mypage/routes')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _CategoryChipsRow(
                                  categories: _categories,
                                  selected: _selectedCategory,
                                  onSelected: (c) => setState(() => _selectedCategory = c),
                                ),
                                // 블러가 서서히 사라질 여백(페이드 테일) — 이 구간에서
                                // ShaderMask 알파가 1→0으로 떨어지며 블러도 함께 옅어진다.
                                const SizedBox(height: 44),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 우측 하단 버튼 묶음 — 스팟 등록 + 현재 위치로 재중심을 같은 줄에 나란히 배치.
              // 시트를 드래그하면 _sheetExtent가 바뀌고, 이 버튼들도 바로 따라 움직인다
              // (ValueListenableBuilder라 이 버튼 부분만 다시 그려지고 지도는 그대로 유지됨).
              ValueListenableBuilder<double>(
                valueListenable: _sheetExtent,
                builder: (context, extent, child) => Positioned(
                  left: 16,
                  right: 16,
                  bottom: constraints.maxHeight * extent + 16,
                  child: child!,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _RegisterSpotButton(onTap: () => context.push('/map/register/search')),
                    const SizedBox(width: 10),
                    _RecenterButton(onTap: _loadCurrentLocation),
                  ],
                ),
              ),
              // 하단 "주변 스팟" 바텀시트 (드래그로 확장 가능)
              _NearbySpotsSheet(
                extentNotifier: _sheetExtent,
                spots: _filteredSpots,
                savedSpotIds: savedSpotIds,
                onToggleSaved: _toggleSaved,
                onSpotTap: _openSpotDetail,
                onSaveCourse: _handleSaveCourse,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 검색창 우측의 원형 버튼 — 탭하면 "내가 만든 코스" 화면(MY탭)으로 이동한다.
class _MyRoutesButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MyRoutesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '내 코스',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Color(0x0F000000))),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.route_outlined, color: CocoTheme.primary, size: 20),
          ),
        ),
      ),
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

/// 목업 지도 배경(건물/도로 블록 + 스팟 핀). 지도 탭 본문뿐 아니라
/// MY탭의 "내가 만든 코스" 화면(my_routes_screen.dart)의 지도 탭에서도 재사용한다.
class MockMapBackground extends StatelessWidget {
  final List<MockSpot> spots;
  final ValueChanged<MockSpot> onSpotTap;
  const MockMapBackground({super.key, required this.spots, required this.onSpotTap});

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
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.my_location_rounded, color: CocoTheme.primary, size: 20),
        ),
      ),
    );
  }
}

/// 지도 위 "스팟 등록" 플로팅 버튼 — 탭하면 장소 검색(스팟 등록 ①)으로 이동.
class _RegisterSpotButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterSpotButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CocoTheme.primary,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: CocoTheme.primary.withOpacity(0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('스팟 등록', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// DraggableScrollableSheet는 리스트 항목 수가 적어서 스크롤할 내용이 시트 안에
// 다 들어차지 않으면(=오버스크롤 여유가 없으면), 살짝 흔들리는 탭 제스처까지도
// "리사이즈 드래그"로 가로채 버려서 탭이 잘 안 먹는 문제가 있다(Flutter의 알려진 동작).
// 그래서 리사이즈 제스처는 핸들 영역에서만 받고, 리스트는 별도 스크롤뷰로 분리해서
// 탭이 항상 정상 동작하도록 직접 구현한다. 핸들을 드래그하면 완전히 접힘/기본/거의
// 전체화면 세 지점 중 가까운 곳으로 스냅된다.
class _NearbySpotsSheet extends StatefulWidget {
  final ValueNotifier<double> extentNotifier;
  final List<MockSpot> spots;
  final Set<String> savedSpotIds;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<MockSpot> onSpotTap;
  final VoidCallback onSaveCourse;

  const _NearbySpotsSheet({
    required this.extentNotifier,
    required this.spots,
    required this.savedSpotIds,
    required this.onToggleSaved,
    required this.onSpotTap,
    required this.onSaveCourse,
  });

  @override
  State<_NearbySpotsSheet> createState() => _NearbySpotsSheetState();
}

class _NearbySpotsSheetState extends State<_NearbySpotsSheet> {
  // 핸들+제목 줄만 있을 때 필요한 최소 높이(px) — 완전히 접힌 상태에서도 이 정도는
  // 있어야 오버플로우가 안 난다.
  static const double _headerMinPx = 74;
  // 리스트/버튼까지 같이 보이려면 필요한 최소 높이(px). 이보다 낮아지면 리스트/버튼을
  // 안 그려서, 줄어드는 도중에 고정 크기 위젯들이 공간을 못 찾아 오버플로우
  // 나는 걸 막는다. extent(비율) 기준이 아니라 실제 픽셀 기준으로 판단해야
  // 화면 크기가 달라도 항상 안전하다.
  static const double _bodyMinPx = 190;

  bool _dragging = false;

  void _snapToNearest(double current, double maxHeight) {
    final points = [_collapsedFloor(maxHeight), kSheetMidExtent, kSheetExpandedExtent];
    var nearest = points.first;
    var best = (points.first - current).abs();
    for (final p in points) {
      final d = (p - current).abs();
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    widget.extentNotifier.value = nearest;
    setState(() => _dragging = false);
  }

  // 화면이 아주 낮을 때(가로모드 등)는 0.09 비율만으로는 핸들 영역조차 다 못
  // 그릴 수 있어서, "핀 영역에 필요한 최소 픽셀"을 비율로 환산해 둘 중 더 큰
  // 쪽을 완전히 접힌 상태의 실제 하한으로 쓴다.
  double _collapsedFloor(double maxHeight) =>
      kSheetCollapsedExtent > _headerMinPx / maxHeight ? kSheetCollapsedExtent : _headerMinPx / maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final collapsedFloor = _collapsedFloor(maxHeight);
        return ValueListenableBuilder<double>(
          valueListenable: widget.extentNotifier,
          builder: (context, extent, _) {
            final sheetHeight = maxHeight * extent;
            // 접힘 지점에 가까울 때는 리스트/버튼을 아예 안 그려서 좁은 공간에서
            // 내용이 눌리거나 넘치지 않게 한다(픽셀 기준이라 화면 크기와 무관하게 안전).
            final showBody = sheetHeight > _bodyMinPx;

            // Stack의 non-positioned 자식은 기본적으로 위쪽 정렬이라, 바닥에 붙는
            // 바텀시트처럼 보이려면 직접 Align(bottomCenter)로 감싸야 한다.
            return Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: sheetHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16),
                  ],
                ),
                child: Column(
                  children: [
                    // 핸들 영역 — 리사이즈 드래그는 여기서만 받아서 아래 리스트의 탭 제스처와
                    // 서로 뺏어가지 않게 분리한다. 탭하면 기본↔거의 전체화면을 토글한다.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) => setState(() => _dragging = true),
                      onVerticalDragUpdate: (details) {
                        widget.extentNotifier.value = (widget.extentNotifier.value - details.delta.dy / maxHeight)
                            .clamp(collapsedFloor, kSheetExpandedExtent);
                      },
                      onVerticalDragEnd: (_) => _snapToNearest(widget.extentNotifier.value, maxHeight),
                      onTap: () => widget.extentNotifier.value =
                          extent >= kSheetExpandedExtent - 0.05 ? kSheetMidExtent : kSheetExpandedExtent,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('주변 스팟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                Text('${widget.spots.length}곳', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showBody) ...[
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: widget.spots.length,
                          separatorBuilder: (_, __) => const Divider(height: 24),
                          itemBuilder: (context, i) => _SpotListTile(
                            spot: widget.spots[i],
                            saved: widget.savedSpotIds.contains(widget.spots[i].id),
                            onToggleSaved: () => widget.onToggleSaved(widget.spots[i].id),
                            onTap: () => widget.onSpotTap(widget.spots[i]),
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
                          onPressed: widget.onSaveCourse,
                          child: const Text('코스 저장하기'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
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
