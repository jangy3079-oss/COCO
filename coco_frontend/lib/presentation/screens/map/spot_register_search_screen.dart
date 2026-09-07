import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/map/kakao_map_view.dart';
import 'map_mock_data.dart' show mapDefaultCenterLat, mapDefaultCenterLng;
import 'spot_register_mock_data.dart';

/// 스팟 등록 ① 장소 검색 화면. 지도 탭의 "스팟 등록" 버튼에서 진입한다.
/// 후보를 하나 골라 "이 위치로 등록하기"를 누르면 등록 폼(spot_register_form_screen)으로 넘어간다.
class SpotRegisterSearchScreen extends StatefulWidget {
  const SpotRegisterSearchScreen({super.key});

  @override
  State<SpotRegisterSearchScreen> createState() => _SpotRegisterSearchScreenState();
}

class _SpotRegisterSearchScreenState extends State<SpotRegisterSearchScreen> {
  String _query = '';
  SpotSearchCandidate? _picked;

  // 미니맵 기본 중심 좌표 — 진입 시 현재 위치로 재설정을 시도하고,
  // 권한 거부/실패 시 mapDefaultCenterLat/Lng(부산 남포동)를 그대로 쓴다.
  double _centerLat = mapDefaultCenterLat;
  double _centerLng = mapDefaultCenterLng;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
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
      });
    } catch (_) {
      // 위치 조회 실패 시 기본 좌표(부산 남포동) 유지 — 미니맵 자체는 정상 동작해야 하므로 조용히 무시.
    }
  }

  List<SpotSearchCandidate> get _results {
    final q = _query.trim();
    if (q.isEmpty) return spotRegisterCandidates;
    return spotRegisterCandidates.where((c) => c.name.contains(q) || c.address.contains(q)).toList();
  }

  // 지도를 직접 눌러 위치를 찍었을 때 — 검색 후보를 고른 것과 동일하게 취급해서
  // 아래쪽 "이 위치로 등록하기" 버튼과 다음 화면(등록 폼)이 그대로 재사용되도록 한다.
  void _pickManualLocation(double lat, double lng) {
    setState(() {
      _picked = SpotSearchCandidate(
        id: 'manual',
        name: '직접 선택한 위치',
        address: '지도에서 선택한 위치',
        lat: lat,
        lng: lng,
      );
    });
  }

  void _next() {
    if (_picked == null) return;
    context.push('/map/register/form', extra: _picked);
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
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const Text('스팟 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CocoTheme.primary),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.black45),
                        hintText: '장소명 또는 주소 검색',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('검색 결과가 없으면 지도를 눌러 위치를 직접 찍을 수 있어요', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.4))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 150,
                  child: KakaoMapView(
                    centerLat: _picked?.lat ?? _centerLat,
                    centerLng: _picked?.lng ?? _centerLng,
                    markers: _picked != null
                        ? [KakaoMapMarker(id: _picked!.id, lat: _picked!.lat, lng: _picked!.lng)]
                        : const [],
                    onMapTap: _pickManualLocation,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('검색 결과', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.45))),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                itemBuilder: (context, i) {
                  final c = _results[i];
                  final selected = _picked?.id == c.id;
                  return InkWell(
                    onTap: () => setState(() => _picked = c),
                    child: Container(
                      color: selected ? const Color(0xFFF5FAFE) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 18, color: selected ? CocoTheme.primary : Colors.black.withOpacity(0.3)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                                const SizedBox(height: 3),
                                Text(c.address, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
                              ],
                            ),
                          ),
                          if (selected) const Icon(Icons.check_rounded, size: 18, color: CocoTheme.primary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _picked != null ? CocoTheme.primary : Colors.black.withOpacity(0.1),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _next,
                child: Text(
                  '이 위치로 등록하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _picked != null ? Colors.white : Colors.black.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
