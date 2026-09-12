import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/spot_repository.dart';
import 'map_mock_data.dart';

class SpotDetailScreen extends StatefulWidget {
  final String spotId;
  const SpotDetailScreen({super.key, required this.spotId});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  bool _liked = true;

  // "db-"로 시작하면 목업이 아니라 실제 DB(TourAPI/카카오 로컬 수집) 스팟이다.
  bool get _isDbSpot => widget.spotId.startsWith('db-');

  final _spotRepository = SpotRepository();
  bool _loading = false;
  bool _loadFailed = false;
  // "이런 스팟은 어때요"용 — 현재 DB 스팟 주변의 다른 실제 스팟들.
  List<MockSpot> _relatedDbSpots = [];

  // 연관 스팟을 찾을 반경(도 단위) — 위경도 1도 ≈ 111km라 0.01이면 대략 1km 남짓.
  // 별도 "연관 관광지" API 없이, 주변 스팟을 그냥 작은 뷰포트로 다시 조회해서 대체한다.
  static const double _relatedRadiusDeg = 0.01;

  @override
  void initState() {
    super.initState();
    if (_isDbSpot) {
      if (dbSpotCache.containsKey(widget.spotId)) {
        _loadRelatedDbSpots();
      } else {
        _loadDbSpot();
      }
    }
  }

  Future<void> _loadDbSpot() async {
    setState(() => _loading = true);
    try {
      final id = int.parse(widget.spotId.substring(3));
      final spot = await _spotRepository.fetchById(id);
      if (!mounted) return;
      if (spot == null) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        return;
      }
      dbSpotCache[widget.spotId] = mockSpotFromDb(spot);
      setState(() => _loading = false);
      _loadRelatedDbSpots();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _loadRelatedDbSpots() async {
    final spot = dbSpotCache[widget.spotId];
    if (spot == null) return;
    try {
      final nearby = await _spotRepository.fetchSpotsInViewport(
        swLat: spot.lat - _relatedRadiusDeg,
        neLat: spot.lat + _relatedRadiusDeg,
        swLng: spot.lng - _relatedRadiusDeg,
        neLng: spot.lng + _relatedRadiusDeg,
      );
      if (!mounted) return;
      final related = nearby
          .where((s) => 'db-${s.id}' != widget.spotId)
          .take(3)
          .map(mockSpotFromDb)
          .toList();
      // 스팟 상세로 다시 들어갈 때 재조회 없이 바로 찾을 수 있게 캐싱.
      for (final s in related) {
        dbSpotCache[s.id] = s;
      }
      setState(() => _relatedDbSpots = related);
    } catch (e) {
      debugPrint('[SpotDetailScreen] 연관 스팟 조회 실패: $e');
    }
  }

  // 찜(저장) 상태는 map_mock_data.dart의 공유 savedSpotIds를 그대로 사용한다
  // (지도 탭 북마크·MY탭 "찜한 스팟"과 같은 상태를 봐야 하므로 화면 로컬 State가 아님).
  bool get _saved => savedSpotIds.contains(widget.spotId);
  void _toggleSaved() {
    setState(() {
      if (_saved) {
        savedSpotIds.remove(widget.spotId);
      } else {
        savedSpotIds.add(widget.spotId);
      }
    });
  }

  MockSpot? get _spot {
    if (_isDbSpot) return dbSpotCache[widget.spotId];
    for (final spot in mockSpots) {
      if (spot.id == widget.spotId) return spot;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isDbSpot && _loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isDbSpot && _loadFailed) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('스팟 정보를 불러오지 못했어요')),
      );
    }

    final spot = _spot;
    if (spot == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('스팟을 찾을 수 없어요')),
      );
    }

    // DB 스팟은 주변 실제 스팟을(뷰포트 재조회로), 목업 스팟은 그대로 목업 중에서 고른다.
    final related = _isDbSpot
        ? _relatedDbSpots
        : mockSpots.where((s) => s.id != spot.id).take(3).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SpotPhotoHeader(
              spot: spot,
              liked: _liked,
              saved: _saved,
              onToggleLiked: () => setState(() => _liked = !_liked),
              onToggleSaved: _toggleSaved,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CocoTheme.secondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    spot.address,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionPillButton(
                          label: _liked ? '좋아요 완료' : '좋아요',
                          active: _liked,
                          activeColor: CocoTheme.primary,
                          onTap: () => setState(() => _liked = !_liked),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionPillButton(
                          label: _saved ? '저장됨' : '저장',
                          active: _saved,
                          activeColor: CocoTheme.secondary,
                          onTap: _toggleSaved,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionPillButton(
                          label: '공유',
                          active: false,
                          activeColor: CocoTheme.secondary,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    spot.description,
                    style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '이런 스팟은 어때요',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 20),
                itemCount: related.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _RelatedSpotCard(spot: related[i]),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SpotPhotoHeader extends StatelessWidget {
  final MockSpot spot;
  final bool liked;
  final bool saved;
  final VoidCallback onToggleLiked;
  final VoidCallback onToggleSaved;

  const _SpotPhotoHeader({
    required this.spot,
    required this.liked,
    required this.saved,
    required this.onToggleLiked,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          // TODO: spot.imageUrl(TourAPI 관광사진) 연동 전까지의 사진 플레이스홀더
          Positioned.fill(
            child: Container(
              color: spot.pinColor.withOpacity(0.10),
              alignment: Alignment.center,
              child: Icon(Icons.photo_camera_outlined, size: 40, color: spot.pinColor.withOpacity(0.4)),
            ),
          ),
          Positioned(
            left: 16,
            top: 44,
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.pop(),
            ),
          ),
          Positioned(
            right: 16,
            top: 44,
            child: Row(
              children: [
                _CircleIconButton(
                  icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  iconColor: liked ? CocoTheme.primary : CocoTheme.secondary,
                  onTap: onToggleLiked,
                ),
                const SizedBox(width: 8),
                _CircleIconButton(
                  icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  onTap: onToggleSaved,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                spot.category,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: iconColor ?? CocoTheme.secondary),
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? activeColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : CocoTheme.secondary,
          ),
        ),
      ),
    );
  }
}

class _RelatedSpotCard extends StatelessWidget {
  final MockSpot spot;
  const _RelatedSpotCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/map/spot/${spot.id}'),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 88,
              decoration: BoxDecoration(
                color: spot.pinColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(spot.icon, color: spot.pinColor.withOpacity(0.5), size: 24),
            ),
            const SizedBox(height: 6),
            Text(spot.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
            Text(spot.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
