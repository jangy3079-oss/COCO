import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/spot.dart' as db;
import '../../../data/repositories/spot_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'map_mock_data.dart';

String _resolveSpotImageUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('//')) return 'https:$value';

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    // TourAPI의 http 이미지가 HTTPS 웹에서 차단되지 않도록 보안 주소로 정규화한다.
    return uri.scheme == 'http' ? uri.replace(scheme: 'https').toString() : value;
  }

  final baseUrl = DioClient.baseUrl.replaceFirst(RegExp(r'/+$'), '');
  return '$baseUrl/${value.replaceFirst(RegExp(r'^/+'), '')}';
}

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
      final cached = dbSpotCache[widget.spotId]!;
      _loadRelatedSpots(cached);
      // dbSpotCache는 스팟 id로만 캐싱돼 있어 locale이나 서버 번역 갱신을 못 따라간다
      // — 다른 화면(지도 뷰포트·찜 목록·연관 스팟 등)이 이 스팟을 다른 언어로 먼저
      // 캐싱해뒀거나, 세션 도중 서버에서 설명 번역이 새로 채워졌을 수 있다. 그래서
      // 캐시 히트여도 항상 백그라운드에서 한 번 더 조회해 다르면 조용히 교체한다 —
      // 사용자는 캐시된 내용을 먼저 보고, 잠깐 뒤 최신 내용으로 자연스럽게 갱신된다.
      _refreshSpotInBackground();
    } else {
      _loadDbSpot();
    }
    // 이 화면에 직접 딥링크로 들어오는 등 likedSpotIds가 아직 한 번도 안 채워졌을
    // 수 있어서, 하트 상태를 정확히 보여주려면 여기서도 한 번 갱신해둔다.
    refreshLikedSpots(locale: context.read<LocaleController>().locale.languageCode);
  }

  Future<void> _refreshSpotInBackground() async {
    final numId = dbSpotNumericId(widget.spotId);
    if (numId == null) return;
    try {
      final fresh = await _spotRepository.fetchById(
        numId,
        locale: context.read<LocaleController>().locale.languageCode,
      );
      if (!mounted || fresh == null) return;
      final updated = mockSpotFromDb(fresh);
      dbSpotCache[widget.spotId] = updated;
      setState(() {});
    } catch (e) {
      debugPrint('[SpotDetailScreen] 스팟 갱신 조회 실패: $e');
    }
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

  // "정보 추가" 버튼 노출 조건 — 소개글/사진 중 하나라도 없으면 뜬다. 데모 스팟은
  // 백엔드 행 자체가 없어 대상이 아니다.
  bool _missingDescription(MockSpot spot) => !spot.hasDescription;
  bool _missingPhoto(MockSpot spot) => spot.imageUrl.trim().isEmpty && spot.images.isEmpty;
  bool _needsInfo(MockSpot spot) =>
      dbSpotNumericId(widget.spotId) != null && (_missingDescription(spot) || _missingPhoto(spot));

  Future<void> _openEnrichSheet(MockSpot spot) async {
    if (!requireLogin(context)) return;
    final numId = dbSpotNumericId(widget.spotId);
    if (numId == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SpotEnrichSheet(
        spotId: numId,
        needsDescription: _missingDescription(spot),
        needsPhoto: _missingPhoto(spot),
        onSaved: (updated) {
          if (!mounted) return;
          setState(() => dbSpotCache[widget.spotId] = mockSpotFromDb(updated));
        },
      ),
    );
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
                  if (_needsInfo(spot)) ...[
                    const SizedBox(height: 12),
                    _EnrichPrompt(
                      missingDescription: _missingDescription(spot),
                      missingPhoto: _missingPhoto(spot),
                      onTap: () => _openEnrichSheet(spot),
                    ),
                  ],
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
              // 148 — 영어/일본어 스팟명은 140짜리 카드 폭에서 두 줄로 줄바꿈될 때가
              // 많아서(예: "Busan Opera House"), 한 줄 기준(132)으로는 넘쳤다. 이름
              // 두 줄 + 부제 한 줄까지 들어가도록 여유를 뒀다.
              height: 148,
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
          Positioned.fill(
            child: _PhotoCarousel(spot: spot),
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

class _PhotoCarousel extends StatefulWidget {
  final MockSpot spot;

  const _PhotoCarousel({required this.spot});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  List<String> _imageUrls(MockSpot spot) {
    final gallery = spot.images
        .map(_resolveSpotImageUrl)
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (gallery.isNotEmpty) return gallery;

    final representative = _resolveSpotImageUrl(spot.imageUrl);
    return representative.isEmpty ? const [] : [representative];
  }

  @override
  void didUpdateWidget(covariant _PhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spot.images != widget.spot.images ||
        oldWidget.spot.imageUrl != widget.spot.imageUrl) {
      _currentPage = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _imageUrls(widget.spot);
    if (urls.isEmpty) return _SpotPhotoPlaceholder(spot: widget.spot);
    if (urls.length == 1) {
      return _SpotNetworkImage(url: urls.first, spot: widget.spot);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (_, index) => _SpotNetworkImage(
              key: ValueKey(urls[index]),
              url: urls[index],
              spot: widget.spot,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 17,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  urls.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _currentPage ? 7 : 5,
                    height: index == _currentPage ? 7 : 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(index == _currentPage ? 1 : 0.55),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotNetworkImage extends StatelessWidget {
  final String url;
  final MockSpot spot;

  const _SpotNetworkImage({super.key, required this.url, required this.spot});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      // TourAPI 이미지 CDN은 CORS 허용 헤더가 없어 Flutter Web의 기본 바이트
      // 디코딩이 실패한다. 웹에서는 HTML <img>로 폴백해 표시한다.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, __, ___) => _SpotPhotoPlaceholder(spot: spot),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _SpotPhotoPlaceholder(spot: spot),
    );
  }
}

class _SpotPhotoPlaceholder extends StatelessWidget {
  final MockSpot spot;

  const _SpotPhotoPlaceholder({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: spot.pinColor.withOpacity(0.10),
      alignment: Alignment.center,
      child: Icon(Icons.photo_camera_outlined, size: 40, color: spot.pinColor.withOpacity(0.4)),
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
          mainAxisSize: MainAxisSize.min,
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
            // 영어/일본어 스팟명은 두 줄로 줄바꿈될 수 있어 maxLines로 높이를 예측
            // 가능하게 막고, 그 이상은 말줄임표로 자른다(overflow 방지).
            Text(
              spot.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary, height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(
              spot.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// 소개글/사진 중 하나라도 비어있는 스팟(주로 카카오 로컬 소스) 상세에 뜨는 배너.
// 탭하면 _SpotEnrichSheet가 열린다.
class _EnrichPrompt extends StatelessWidget {
  final bool missingDescription;
  final bool missingPhoto;
  final VoidCallback onTap;

  const _EnrichPrompt({
    required this.missingDescription,
    required this.missingPhoto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = missingDescription && missingPhoto
        ? '이 장소의 소개글과 사진이 아직 없어요'
        : missingDescription
            ? '이 장소의 소개글이 아직 없어요'
            : '이 장소의 사진이 아직 없어요';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF4F8FC), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded, size: 20, color: CocoTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ),
            const Text('정보 추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
            const Icon(Icons.chevron_right_rounded, size: 18, color: CocoTheme.primary),
          ],
        ),
      ),
    );
  }
}

// "정보 추가" 입력 폼 — 빈 필드만 골라서 보여준다(이미 값이 있는 소개글/사진은 다시
// 안 묻는다, 백엔드도 빈 필드만 채우기로 합의됨). description·사진 중 하나만 채워도
// 제출 가능.
class _SpotEnrichSheet extends StatefulWidget {
  final int spotId;
  final bool needsDescription;
  final bool needsPhoto;
  final ValueChanged<db.Spot> onSaved;

  const _SpotEnrichSheet({
    required this.spotId,
    required this.needsDescription,
    required this.needsPhoto,
    required this.onSaved,
  });

  @override
  State<_SpotEnrichSheet> createState() => _SpotEnrichSheetState();
}

class _SpotEnrichSheetState extends State<_SpotEnrichSheet> {
  final _descController = TextEditingController();
  final _spotRepository = SpotRepository();
  Uint8List? _imageBytes;
  bool _submitting = false;

  bool get _canSubmit {
    if (_submitting) return false;
    final descFilled = widget.needsDescription && _descController.text.trim().isNotEmpty;
    final photoFilled = widget.needsPhoto && _imageBytes != null;
    return descFilled || photoFilled;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final updated = await _spotRepository.enrichSpot(
        widget.spotId,
        description: widget.needsDescription ? _descController.text : null,
        imageBytes: widget.needsPhoto ? _imageBytes : null,
        locale: context.read<LocaleController>().locale.languageCode,
      );
      if (!mounted) return;
      widget.onSaved(updated);
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[SpotEnrichSheet] 정보 추가 실패: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정보 추가에 실패했어요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('정보 추가하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
          const SizedBox(height: 6),
          Text('다른 사람들에게 도움이 되는 정보를 채워주세요', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          if (widget.needsPhoto) ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF8F8F8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imageBytes == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 26),
                            const SizedBox(height: 6),
                            Text('사진 추가(선택)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity),
                      ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.needsDescription)
            TextField(
              controller: _descController,
              onChanged: (_) => setState(() {}),
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: '이 장소에 대해 소개해주세요',
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _canSubmit ? CocoTheme.primary : Colors.black.withOpacity(0.2),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _canSubmit ? _submit : null,
            child: Text(
              _submitting ? '등록 중...' : '등록하기',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
