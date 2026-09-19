import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/route_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/map/kakao_map_view.dart';
import '../map/map_mock_data.dart' show MockSpot, mockSpotFromRouteStop, spotsCenter;
import 'feed_mock_data.dart';
import 'feed_screen.dart' show showShareSheet;

/// 피드 게시물 상세 화면 (당근마켓 스타일). FeedScreen에서 push할 때 같은
/// FeedItem 인스턴스를 extra로 전달받아 직접 mutate한다 — 피드 목록(feed_screen)이
/// 들고 있는 것과 같은 인스턴스라, 여기서 좋아요/저장/댓글을 바꾸면 피드 목록으로
/// 돌아갔을 때도 그대로 반영된다.
///
/// 골목지도(type == route) 게시물은 사진 슬라이드 마지막에 정적 골목지도
/// 슬라이드가 하나 더 붙고, 그 슬라이드를 보고 있을 때만 아래에 골목지도
/// 요약 카드(보기/저장 버튼)가 나타난다 — 레퍼런스의 슬라이드-연동 동작.
class FeedPostDetailScreen extends StatefulWidget {
  final FeedItem item;
  const FeedPostDetailScreen({super.key, required this.item});

  @override
  State<FeedPostDetailScreen> createState() => _FeedPostDetailScreenState();
}

class _FeedPostDetailScreenState extends State<FeedPostDetailScreen> {
  final _commentController = TextEditingController();
  final _feedRepository = FeedRepository();
  final _routeRepository = RouteRepository();
  int _slide = 0;
  bool _submittingComment = false;

  bool get _isRoute => widget.item.type == FeedPostType.route;
  int get _totalSlides => (_isRoute ? widget.item.imgCount + 1 : widget.item.imgCount).clamp(1, 99);
  bool get _onMapSlide => _isRoute && _slide == _totalSlides - 1;

  @override
  void initState() {
    super.initState();
    // 실제 게시물이면 댓글은 목록 조회 응답에 안 담겨있어서 상세 화면 진입 시 따로 가져온다.
    final postId = widget.item.realPostId;
    if (postId != null) _loadComments(postId);
  }

  Future<void> _loadComments(int postId) async {
    try {
      final comments = await _feedRepository.fetchComments(postId);
      if (!mounted) return;
      setState(() {
        widget.item.comments
          ..clear()
          ..addAll(comments.map(feedCommentFromDto));
      });
    } catch (e) {
      debugPrint('[FeedPostDetailScreen] 댓글 조회 실패: $e');
    }
  }

  // 목업 코스(routeStops가 이미 있음)는 그대로 쓰고, 실제 게시물(routeId만 있고
  // FeedPostResponse엔 스팟 목록이 없음)은 여기서 코스 상세를 조회해 스팟 목록을 채운다.
  Future<void> _openRoutePreview(FeedItem item) async {
    var stops = item.routeStops;
    // 실제 게시물이면(item.author == 백엔드 userNickname) 로그인한 나와 닉네임이
    // 같은지로 진짜 소유권을 판단하고, 목업 데이터는 예전처럼 source로만 판단한다
    // (목업 작성자는 실제 로그인 계정과 무관해서 닉네임 비교가 의미가 없음).
    var isOwner = item.source == FeedSource.user;
    if (stops == null || stops.isEmpty) {
      final numId = int.tryParse(item.routeId ?? '');
      if (numId == null) return;
      try {
        final route = await _routeRepository.getById(numId);
        stops = route.spots.map(mockSpotFromRouteStop).toList();
        isOwner = AuthTokenStore.nickname != null && AuthTokenStore.nickname == item.author;
      } catch (e) {
        debugPrint('[FeedPostDetailScreen] 코스 조회 실패: $e');
        return;
      }
    }
    if (!mounted) return;
    context.push('/map/route/preview', extra: {
      'name': item.displayTitle,
      'stops': stops,
      'routeId': item.routeId,
      'isOwner': isOwner,
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final postId = widget.item.realPostId;
    if (postId == null) {
      setState(() => widget.item.liked = !widget.item.liked);
      return;
    }
    setState(() => widget.item.liked = !widget.item.liked);
    try {
      await _feedRepository.toggleLike(postId);
    } catch (e) {
      debugPrint('[FeedPostDetailScreen] 좋아요 실패: $e');
      if (mounted) setState(() => widget.item.liked = !widget.item.liked);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submittingComment) return;

    final postId = widget.item.realPostId;
    if (postId == null) {
      // 목업 시드 게시물은 예전처럼 로컬에만 추가.
      setState(() {
        widget.item.comments.add(FeedComment(
          id: 'c${DateTime.now().millisecondsSinceEpoch}',
          author: AppLocalizations.of(context)!.feedMeAvatarLabel,
          text: text,
        ));
      });
      _commentController.clear();
      return;
    }

    setState(() => _submittingComment = true);
    try {
      final saved = await _feedRepository.createComment(postId, text);
      if (!mounted) return;
      setState(() {
        widget.item.comments.add(feedCommentFromDto(saved));
        _submittingComment = false;
      });
      _commentController.clear();
    } catch (e) {
      debugPrint('[FeedPostDetailScreen] 댓글 작성 실패: $e');
      if (!mounted) return;
      setState(() => _submittingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.feedPostDetailCommentFailed)),
      );
    }
  }

  void _prevSlide() => setState(() => _slide = (_slide - 1 + _totalSlides) % _totalSlides);
  void _nextSlide() => setState(() => _slide = (_slide + 1) % _totalSlides);

  Future<void> _share() async {
    final shared = await showShareSheet(context);
    if (shared && mounted) setState(() => widget.item.shares += 1);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = categoryColor(item.category);
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
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  Text(l10n.feedPostDetailPageTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFFF0ECE6),
                            child: Text(item.authorInitial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                          ),
                          const SizedBox(width: 8),
                          Text(item.author ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                          const SizedBox(width: 6),
                          const _LocalBadge(),
                          const Spacer(),
                          Text(item.timeLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: AspectRatio(
                        aspectRatio: 340 / 280,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _onMapSlide
                                    ? _RouteMapSlide(stops: item.routeStops ?? const [])
                                    : item.imageUrl != null
                                        ? Image.network('${DioClient.baseUrl}${item.imageUrl}', fit: BoxFit.cover)
                                        : Container(
                                            color: color.withOpacity(0.12),
                                            alignment: Alignment.center,
                                            child: Icon(categoryIcon(item.category), size: 40, color: color.withOpacity(0.4)),
                                          ),
                              ),
                              if (_totalSlides > 1) ...[
                                Positioned(
                                  left: 10,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(child: _CarouselArrow(icon: Icons.chevron_left_rounded, onTap: _prevSlide)),
                                ),
                                Positioned(
                                  right: 10,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(child: _CarouselArrow(icon: Icons.chevron_right_rounded, onTap: _nextSlide)),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 12,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (int i = 0; i < _totalSlides; i++)
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          width: i == _slide ? 18 : 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(3),
                                            color: i == _slide ? CocoTheme.primary : Colors.white.withOpacity(0.85),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Text(item.desc, style: TextStyle(fontSize: 14, height: 1.7, color: Colors.black.withOpacity(0.7))),
                    ),
                    // 스팟 태그 없이 쓴 글이면 place가 빈 문자열이라 위치 배지를 아예 안 그린다.
                    if (!_isRoute && item.place.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: InkWell(
                          onTap: () => context.go('/map'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 15, color: CocoTheme.accent),
                                const SizedBox(width: 6),
                                Text(item.dong, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                                const SizedBox(width: 4),
                                Text(item.place, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_onMapSlide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _RouteSummaryCard(item: item, onView: _openRoutePreview),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(margin: const EdgeInsets.only(bottom: 14), height: 1, color: Colors.black.withOpacity(0.07)),
                          Row(
                            children: [
                              _ActionIcon(
                                icon: item.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                iconColor: item.liked ? CocoTheme.primary : Colors.grey.shade600,
                                label: '${item.likeCount}',
                                onTap: _toggleLike,
                              ),
                              const SizedBox(width: 18),
                              _ActionIcon(
                                icon: Icons.mode_comment_outlined,
                                iconColor: Colors.grey.shade600,
                                label: '${item.comments.length}',
                                onTap: () {},
                              ),
                              const SizedBox(width: 18),
                              _ActionIcon(
                                icon: Icons.share_outlined,
                                iconColor: Colors.grey.shade600,
                                label: '${item.shares}',
                                onTap: _share,
                              ),
                              if (!_isRoute) ...[
                                const Spacer(),
                                _ActionIcon(
                                  icon: item.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  iconColor: item.saved ? CocoTheme.secondary : Colors.grey.shade600,
                                  label: '${item.saveCount}',
                                  onTap: () => setState(() => item.saved = !item.saved),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                      child: Text(l10n.feedPostDetailCommentsCount(item.comments.length), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                    ),
                    for (final c in item.comments)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFF0ECE6),
                              child: Text(c.authorInitial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.author, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                                  const SizedBox(height: 2),
                                  Text(c.text, style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: l10n.feedPostDetailCommentHint,
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CocoTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _submitComment,
                    child: Text(l10n.feedPostDetailCommentSubmit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalBadge extends StatelessWidget {
  const _LocalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: CocoTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(AppLocalizations.of(context)!.feedLocalBadge, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 30, height: 30, child: Icon(icon, size: 18, color: CocoTheme.secondary)),
      ),
    );
  }
}

/// 골목지도 게시물의 마지막 캐러셀 슬라이드 — 정적 경로+번호 핀 그래픽.
/// TODO: 실제 코스 데이터(MockRoute) 연동 시 진짜 좌표 기반 스냅샷으로 교체.
/// 실제 골목지도(코스)를 카카오맵 위에 순서 번호 핀으로 보여준다.
/// 예전엔 고정된 위치에 점 4개만 찍어두는 정적 목업이었는데, 이제 실제 스팟
/// 좌표/순서를 그대로 반영한다(map_screen.dart 코스 필터 화면과 동일한 스타일).
/// 캐러셀 슬라이드라 좌우 화살표로 넘기는 용도 외에 지도 자체를 조작할 필요는
/// 없어서, 투명 위젯을 한 겹 덮어 실제 지도 DOM(드래그/카카오 로고 링크 등)에
/// 클릭이 닿지 않게 막는다 — IgnorePointer만으로는 platform view의 진짜 DOM
/// 클릭(예: 카카오 로고가 새 탭을 여는 문제)을 못 막기 때문.
class _RouteMapSlide extends StatelessWidget {
  final List<MockSpot> stops;
  const _RouteMapSlide({required this.stops});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final center = spotsCenter(stops);
    return Stack(
      children: [
        Positioned.fill(
          child: KakaoMapView(
            centerLat: center.$1,
            centerLng: center.$2,
            level: 6,
            clusteringEnabled: false,
            markers: [
              for (final (i, spot) in stops.indexed)
                KakaoMapMarker(id: spot.id, lat: spot.lat, lng: spot.lng, name: spot.name, order: i + 1),
            ],
          ),
        ),
        const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.94), borderRadius: BorderRadius.circular(14)),
            child: Text(l10n.feedRouteMapSlideBadge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
          ),
        ),
      ],
    );
  }
}

/// 골목지도 마지막 슬라이드 아래에 붙는 요약 카드 — 골목지도 보기/저장.
class _RouteSummaryCard extends StatefulWidget {
  final FeedItem item;
  final ValueChanged<FeedItem> onView;
  const _RouteSummaryCard({required this.item, required this.onView});

  @override
  State<_RouteSummaryCard> createState() => _RouteSummaryCardState();
}

class _RouteSummaryCardState extends State<_RouteSummaryCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: CocoTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(l10n.feedRouteSummaryBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
              ),
              const SizedBox(width: 6),
              Text(l10n.feedRouteSummaryAuthorLine(item.author ?? ''), style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35))),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.displayTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
          const SizedBox(height: 4),
          Text(
            l10n.feedRouteSummaryStats(item.stopCount ?? 0, item.distanceKm.toStringAsFixed(1), item.durationMin),
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  // 코스 상세(route_preview_screen)로 이동 — 내가 올린 코스면(routeId 있음)
                  // 편집도 가능하고, 다른 로컬이 올린 코스면 보기 전용으로 뜬다.
                  onPressed: (item.routeStops == null || item.routeStops!.isEmpty) && item.routeId == null
                      ? null
                      : () => widget.onView(item),
                  child: Text(l10n.feedRouteSummaryViewButton, style: const TextStyle(color: CocoTheme.secondary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: item.routeSaved ? const Color(0xFFFF5A36) : Colors.white,
                    foregroundColor: item.routeSaved ? Colors.white : const Color(0xFFFF5A36),
                    minimumSize: const Size.fromHeight(44),
                    side: item.routeSaved ? null : const BorderSide(color: Color(0xFFFF5A36)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => item.routeSaved = !item.routeSaved),
                  child: Text(item.routeSaved ? l10n.feedSaveButtonSaved : l10n.feedSaveButtonUnsaved, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (item.routeSaved)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                l10n.feedRouteSummarySavedHint,
                style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.4)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
