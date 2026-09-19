import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/spot_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'map_mock_data.dart';

// map_screen.dart의 _categoryLabel()과 동일한 원칙: category 원본 값(백엔드/필터링에 쓰이는
// 한국어 키)은 그대로 두고, 화면에 보여줄 라벨만 다국어로 바꾼다.
String _categoryLabel(String category, AppLocalizations l10n) {
  switch (category) {
    case '음식점':
      return l10n.mapCategoryFood;
    case '골목':
      return l10n.mapCategoryAlley;
    case '공원':
      return l10n.mapCategoryPark;
    case '카페':
      return l10n.mapCategoryCafe;
    case '명소':
      return l10n.mapCategoryAttraction;
    case '문화시설':
      return l10n.mapCategoryCulture;
    default:
      return category;
  }
}

class SpotDetailScreen extends StatefulWidget {
  final String spotId;
  const SpotDetailScreen({super.key, required this.spotId});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  bool _liked = true;

  final _spotRepository = SpotRepository();
  bool _loading = false;
  bool _loadFailed = false;
  // "이런 스팟은 어때요"용 — 현재 스팟 주변의 다른 실제 DB 스팟들. 고정 데모
  // 스팟('spot-1' 등)도 실제 부산 좌표를 갖고 있어 동일하게 조회 가능하다.
  List<MockSpot> _relatedSpots = [];

  // 연관 스팟을 찾을 반경(도 단위) — 위경도 1도 ≈ 111km라 0.01이면 대략 1km 남짓.
  // 별도 "연관 관광지" API 없이, 주변 스팟을 그냥 작은 뷰포트로 다시 조회해서 대체한다.
  static const double _relatedRadiusDeg = 0.01;

  @override
  void initState() {
    super.initState();
    if (dbSpotCache.containsKey(widget.spotId)) {
      _loadRelatedSpots(dbSpotCache[widget.spotId]!);
    } else {
      _loadDbSpot();
    }
    // 이 화면에 직접 딥링크로 들어오는 등 likedSpotIds가 아직 한 번도 안 채워졌을
    // 수 있어서, 하트 상태를 정확히 보여주려면 여기서도 한 번 갱신해둔다.
    refreshLikedSpots(locale: context.read<LocaleController>().locale.languageCode);
  }

  Future<void> _loadDbSpot() async {
    setState(() => _loading = true);
    try {
      final id = int.parse(widget.spotId.substring(3));
      final spot = await _spotRepository.fetchById(
        id,
        locale: context.read<LocaleController>().locale.languageCode,
      );
      if (!mounted) return;
      if (spot == null) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        return;
      }
      final mockSpot = mockSpotFromDb(spot);
      dbSpotCache[widget.spotId] = mockSpot;
      setState(() => _loading = false);
      _loadRelatedSpots(mockSpot);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  // "이런 스팟은 어때요" — 별도 "연관 스팟" API 없이, 주변을 작은 뷰포트로 다시
  // 조회해서 대체한다. db 스팟이든 고정 데모 스팟이든 실제 위경도를 갖고 있어
  // 동일한 방식으로 조회할 수 있다.
  Future<void> _loadRelatedSpots(MockSpot spot) async {
    try {
      final nearby = await _spotRepository.fetchSpotsInViewport(
        swLat: spot.lat - _relatedRadiusDeg,
        neLat: spot.lat + _relatedRadiusDeg,
        swLng: spot.lng - _relatedRadiusDeg,
        neLng: spot.lng + _relatedRadiusDeg,
        locale: context.read<LocaleController>().locale.languageCode,
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
      setState(() => _relatedSpots = related);
    } catch (e) {
      debugPrint('[SpotDetailScreen] 연관 스팟 조회 실패: $e');
    }
  }

  // 찜(저장) 상태는 map_mock_data.dart의 공유 likedSpotIds(실제 백엔드와 동기화)를
  // 그대로 사용한다 — 지도 탭 북마크·MY탭 "찜한 스팟"과 같은 상태를 봐야 하므로
  // 화면 로컬 State가 아님. 고정 데모 스팟('spot-1' 등)은 API가 없어 항상 false.
  bool get _saved => isSpotSaved(widget.spotId);

  Future<void> _toggleSaved() async {
    final numId = dbSpotNumericId(widget.spotId);
    if (numId == null) return; // 데모 스팟은 찜 불가
    if (!requireLogin(context)) return;
    final wasSaved = _saved;
    setState(() {
      if (wasSaved) {
        likedSpotIds.remove(numId);
      } else {
        likedSpotIds.add(numId);
      }
    });
    try {
      await toggleSpotLike(numId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          likedSpotIds.add(numId);
        } else {
          likedSpotIds.remove(numId);
        }
      });
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        debugPrint('[SpotDetailScreen] 찜 토글 실패: $e');
      }
    }
  }

  MockSpot? get _spot => dbSpotCache[widget.spotId];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadFailed) {
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

    final related = _relatedSpots;

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
                  if (spot.description.trim().isNotEmpty) _ExpandableDescription(text: spot.description),
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
                _categoryLabel(spot.category, AppLocalizations.of(context)!),
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

// 기본 3줄만 보여주고, 실제로 3줄을 넘칠 때만 구분선+버튼을 노출해 전체 내용을
// 펼쳐볼 수 있게 한다. TextPainter로 3줄 제한 시 실제 줄바꿈이 넘치는지 미리 재서,
// 짧은 소개글에는 불필요한 "전체보기" 버튼이 뜨지 않게 한다.
class _ExpandableDescription extends StatefulWidget {
  final String text;
  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const int _collapsedMaxLines = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF3D3D3D));

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedMaxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _collapsedMaxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflows) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? '접기' : '전체보기',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: CocoTheme.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
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
