import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/reference/busan_dong_data.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'busan_district_map.dart';
import 'feed_mock_data.dart';

String _localizedFeedRegion(String region, String languageCode) {
  const english = <String, String>{
    '강서구': 'Gangseo-gu',
    '사상구': 'Sasang-gu',
    '사하구': 'Saha-gu',
    '영도구': 'Yeongdo-gu',
    '남구': 'Nam-gu',
    '부산진구': 'Busanjin-gu',
    '수영구': 'Suyeong-gu',
    '해운대구': 'Haeundae-gu',
    '북구': 'Buk-gu',
    '동래·연제': 'Dongnae · Yeonje',
    '중·동·서구': 'Jung · Dong · Seo',
    '금정구': 'Geumjeong-gu',
    '기장군': 'Gijang-gun',
  };
  const japanese = <String, String>{
    '강서구': '江西区',
    '사상구': '沙上区',
    '사하구': '沙下区',
    '영도구': '影島区',
    '남구': '南区',
    '부산진구': '釜山鎮区',
    '수영구': '水営区',
    '해운대구': '海雲台区',
    '북구': '北区',
    '동래·연제': '東莱・蓮堤',
    '중·동·서구': '中・東・西区',
    '금정구': '金井区',
    '기장군': '機張郡',
  };
  if (languageCode == 'en') return english[region] ?? region;
  if (languageCode == 'ja') return japanese[region] ?? region;
  return region;
}

String _localizedDongLabel(
    String id, AppLocalizations l10n, String languageCode) {
  if (id == kAllDongId) return l10n.feedFilterBusanAll;
  final parts = id.split('|');
  if (parts.length != 2) return l10n.feedFilterBusanAll;
  if (parts[1] == '__구전체__') {
    return l10n.feedFilterDistrictAll(
      _localizedFeedRegion(parts[0], languageCode),
    );
  }
  final dong = normalizeBusanDongName(parts[1]);
  return languageCode == 'ko' ? dong : _romanizeAdministrativeName(dong);
}

String _romanizeAdministrativeName(String name) {
  const initials = <String>[
    'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '',
    'j', 'jj', 'ch', 'k', 't', 'p', 'h'
  ];
  const vowels = <String>[
    'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae',
    'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i'
  ];
  const finals = <String>[
    '', 'k', 'k', 'ks', 'n', 'nj', 'nh', 't', 'l', 'lk', 'lm', 'lb',
    'ls', 'lt', 'lp', 'lh', 'm', 'p', 'ps', 't', 't', 'ng', 't', 't',
    'k', 't', 'p', 'h'
  ];
  const suffixes = <String, String>{
    '동': '-dong',
    '읍': '-eup',
    '면': '-myeon',
    '리': '-ri',
  };
  var stem = name;
  var suffix = '';
  for (final entry in suffixes.entries) {
    if (stem.endsWith(entry.key)) {
      stem = stem.substring(0, stem.length - 1);
      suffix = entry.value;
      break;
    }
  }
  final buffer = StringBuffer();
  for (final rune in stem.runes) {
    if (rune < 0xAC00 || rune > 0xD7A3) {
      buffer.writeCharCode(rune);
      continue;
    }
    final syllable = rune - 0xAC00;
    buffer
      ..write(initials[syllable ~/ 588])
      ..write(vowels[(syllable % 588) ~/ 28])
      ..write(finals[syllable % 28]);
  }
  final romanized = buffer.toString();
  if (romanized.isEmpty) return name;
  return '${romanized[0].toUpperCase()}${romanized.substring(1)}$suffix';
}

String _localizedSortLabel(String sortBy, AppLocalizations l10n) =>
    switch (sortBy) {
      'likes' => l10n.feedFilterSortLikes,
      'saves' => l10n.feedFilterSortSaves,
      _ => l10n.feedFilterSortLatest,
    };

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  FeedPostType? _typeFilter; // null = 전체
  String _dongId = kAllDongId; // busanGuList 기반 dongId. 기본은 부산 전체이고
  // GPS 조회에 성공하면 _resolveDefaultDong()이 가장 가까운 동으로 바꿔준다.
  String _defaultDongId = kAllDongId; // "초기화" 버튼이 되돌아갈 기본값
  String? _myNearestDongId; // 필터 시트에서 "내 위치 기준" 배지를 붙일 동
  String _sortBy = 'latest'; // latest | likes | saves
  int _visibleCount = 5;
  bool _loadingMore = false;

  final _scrollController = ScrollController();
  final _feedRepository = FeedRepository();
  // GET /api/feed로 받아온 실제 게시물.
  List<FeedItem> _realItems = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRealPosts();
    _resolveDefaultDong();
  }

  // 위치 권한이 있으면 내 위치에서 가장 가까운 동을 기본 동네 필터로 쓰고,
  // 권한이 없거나 조회에 실패하면 "부산 전체"를 기본값으로 유지한다
  // (map_screen.dart의 _loadCurrentLocation과 동일한 패턴).
  Future<void> _resolveDefaultDong() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      final nearest = nearestDongId(position.latitude, position.longitude);
      if (!mounted || nearest == null) return;
      setState(() {
        _myNearestDongId = nearest;
        _dongId = nearest;
        _defaultDongId = nearest;
      });
    } catch (_) {
      // 위치 조회 실패 시 "부산 전체" 기본값 유지 — 조용히 무시.
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRealPosts() async {
    try {
      final posts = await _feedRepository.fetchFeed();
      if (!mounted) return;
      setState(() => _realItems = posts.map(feedItemFromPost).toList());
    } catch (e) {
      debugPrint('[FeedScreen] 피드 목록 조회 실패: $e');
    }
  }

  bool get _isRankingView => _typeFilter == FeedPostType.route;

  List<FeedItem> get _filteredSorted {
    // 타입 필터(전체/일상/코스)와 동네 필터(반경 기반 근접 매칭, matchesDongFilter
    // 참고)를 함께 적용한다. 좌표가 없는 게시물(스팟 태그 없이 쓴 글)은 동네
    // 필터와 무관하게 항상 포함된다.
    var list = _realItems
        .where((it) => _typeFilter == null || it.type == _typeFilter)
        .where((it) =>
            matchesDongFilter(lat: it.lat, lng: it.lng, dongId: _dongId))
        .toList();

    switch (_sortBy) {
      case 'likes':
        list.sort((a, b) => b.likeCount - a.likeCount);
        break;
      case 'saves':
        list.sort((a, b) => b.saveCount - a.saveCount);
        break;
      default:
        list.sort((a, b) => b.ts - a.ts);
    }
    return list;
  }

  bool get _hasMore => _visibleCount < _filteredSorted.length;

  void _onScroll() {
    final position = _scrollController.position;
    if (_loadingMore || !_hasMore || _isRankingView) return;
    if (position.pixels >= position.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() => _loadingMore = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _visibleCount = min(_visibleCount + 3, _filteredSorted.length);
      });
    });
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 380),
        reverseDuration: Duration(milliseconds: 300),
      ),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => _FilterSheet(
          dongId: _dongId,
          sortBy: _sortBy,
          resultCount: _filteredSorted.length,
          myNearestDongId: _myNearestDongId,
          onDongSelected: (id) => setSheetState(() => _dongId = id),
          onSortSelected: (v) => setSheetState(() => _sortBy = v),
          onReset: () => setSheetState(() {
            _dongId = _defaultDongId;
            _sortBy = 'latest';
          }),
          onApply: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (mounted) setState(() => _visibleCount = 5);
  }

  Future<void> _openDetail(FeedItem item) async {
    await context.push('/feed/post', extra: item);
    if (mounted) setState(() {});
  }

  Future<void> _openComposer() async {
    await context.push('/feed/compose');
    if (mounted) await _loadRealPosts();
  }

  // 실제 게시물(item.realPostId != null)은 서버에 좋아요를 반영하고, 목업 시드 데이터는
  // 예전처럼 로컬에서만 토글한다. 낙관적으로 먼저 뒤집고, 실패하면 원래대로 되돌린다.
  Future<void> _toggleLike(FeedItem item) async {
    final postId = item.realPostId;
    if (postId == null) {
      setState(() => item.liked = !item.liked);
      return;
    }
    setState(() => item.liked = !item.liked);
    try {
      await _feedRepository.toggleLike(postId);
    } catch (e) {
      debugPrint('[FeedScreen] 좋아요 실패: $e');
      if (mounted) setState(() => item.liked = !item.liked);
    }
  }

  // 피드 저장(북마크) 토글 — toggleLike와 동일한 낙관적 업데이트 패턴.
  // 실제 게시물은 서버에 반영하고, 목업 시드 데이터는 로컬에서만 토글한다.
  Future<void> _toggleSave(FeedItem item) async {
    final postId = item.realPostId;
    if (postId == null) {
      setState(() => item.saved = !item.saved);
      return;
    }
    setState(() => item.saved = !item.saved);
    try {
      await _feedRepository.toggleSave(postId);
    } catch (e) {
      debugPrint('[FeedScreen] 저장 실패: $e');
      if (mounted) setState(() => item.saved = !item.saved);
    }
  }

  Future<void> _share(FeedItem item) async {
    // 공유 시트에서 카카오톡/인스타/메시지 중 하나를 실제로 골랐을 때만 카운트를
    // 올린다 — 시트만 열었다가 아무것도 안 누르고 닫으면 안 올라가야 한다.
    final shared = await showShareSheet(context);
    if (shared && mounted) setState(() => item.shares += 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final visibleItems = _filteredSorted.take(_visibleCount).toList();
    final isDefaultFilter = _dongId == _defaultDongId && _sortBy == 'latest';

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: CocoTheme.primary,
        shape: const CircleBorder(),
        onPressed: _openComposer,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FeedHeaderBar(
                dongLabel: _localizedDongLabel(_dongId, l10n, languageCode)),
            // 필터 영역 — 스크롤 여부와 상관없이 항상 고정으로 보여준다.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _FilterRow(
                isDefaultFilter: isDefaultFilter,
                onOpenSheet: _openFilterSheet,
                typeFilter: _typeFilter,
                onTypeSelected: (v) => setState(() {
                  _typeFilter = v;
                  _visibleCount = 5;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_localizedDongLabel(_dongId, l10n, languageCode)} · ${_localizedSortLabel(_sortBy, l10n)}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.black.withOpacity(0.4)),
                ),
              ),
            ),
            Expanded(
              child: visibleItems.isEmpty
                  ? const _EmptyState()
                  : _isRankingView
                      ? _RouteRankingList(
                          items: visibleItems,
                          onToggleSave: (item) => _toggleSave(item),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: visibleItems.length + 1,
                          itemBuilder: (context, i) {
                            if (i == visibleItems.length) {
                              return _ListFooter(
                                loadingMore: _loadingMore,
                                showEndMessage: !_loadingMore && !_hasMore,
                              );
                            }
                            final item = visibleItems[i];
                            return _FeedCard(
                              item: item,
                              onToggleLike: () => _toggleLike(item),
                              onToggleSave: () => _toggleSave(item),
                              onShare: () => _share(item),
                              onPrevImg: () => setState(() => item.imgIndex =
                                  (item.imgIndex - 1 + item.imgCount) %
                                      item.imgCount),
                              onNextImg: () => setState(() => item.imgIndex =
                                  (item.imgIndex + 1) % item.imgCount),
                              onOpenDetail: () => _openDetail(item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 인스타그램 등 외부 SNS 공유를 흉내낸 목업 시트.
/// 카카오톡/인스타그램/메시지 중 하나를 실제로 고르면 true, 아무것도 안 고르고
/// 시트를 닫으면(바깥 탭/뒤로가기) false 또는 null을 반환한다 — 호출부가 이 값을
/// 보고 공유수를 올릴지 말지 정한다.
/// TODO: 실제 OS 공유 시트 연동 시 share_plus 등으로 교체.
Future<bool> showShareSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final shared = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.feedShareTitle,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CocoTheme.secondary)),
            const SizedBox(height: 18),
            Row(
              children: [
                _ShareTile(
                    icon: Icons.chat_bubble_rounded,
                    color: const Color(0xFFFEE500),
                    label: l10n.feedShareKakao,
                    onTap: () => Navigator.of(context).pop(true)),
                const SizedBox(width: 16),
                _ShareTile(
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFFE1306C),
                    label: l10n.feedShareInstagram,
                    onTap: () => Navigator.of(context).pop(true)),
                const SizedBox(width: 16),
                _ShareTile(
                    icon: Icons.sms_rounded,
                    color: Colors.grey.shade600,
                    label: l10n.feedShareMessage,
                    onTap: () => Navigator.of(context).pop(true)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return shared ?? false;
}

class _ShareTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ShareTile(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: CocoTheme.secondary)),
        ],
      ),
    );
  }
}

class _FeedHeaderBar extends StatelessWidget {
  final String dongLabel;
  const _FeedHeaderBar({required this.dongLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.feedHeaderTitle,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: CocoTheme.secondary)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: CocoTheme.primary),
                  const SizedBox(width: 4),
                  Text(dongLabel,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CocoTheme.primary)),
                  const SizedBox(width: 4),
                  Text(l10n.feedBasisSuffix,
                      style: TextStyle(
                          fontSize: 13, color: Colors.black.withOpacity(0.35))),
                ],
              ),
            ],
          ),
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFF0ECE6),
            child: Text(l10n.feedMeAvatarLabel,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CocoTheme.secondary)),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final bool isDefaultFilter;
  final VoidCallback onOpenSheet;
  final FeedPostType? typeFilter;
  final ValueChanged<FeedPostType?> onTypeSelected;

  const _FilterRow({
    required this.isDefaultFilter,
    required this.onOpenSheet,
    required this.typeFilter,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        InkWell(
          onTap: onOpenSheet,
          borderRadius: BorderRadius.circular(19),
          splashColor: Colors.black.withOpacity(0.08),
          highlightColor: Colors.black.withOpacity(0.08),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDefaultFilter
                  ? Colors.white
                  : CocoTheme.primary.withOpacity(0.12),
              border: Border.all(
                  color: isDefaultFilter
                      ? Colors.grey.shade300
                      : CocoTheme.primary),
            ),
            child: Icon(Icons.tune_rounded,
                size: 18,
                color: isDefaultFilter
                    ? Colors.black.withOpacity(0.45)
                    : CocoTheme.primary),
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 22, color: Colors.black.withOpacity(0.1)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TypeChip(
                    label: l10n.feedFilterAll,
                    selected: typeFilter == null,
                    onTap: () => onTypeSelected(null)),
                const SizedBox(width: 8),
                _TypeChip(
                    label: l10n.feedFilterDaily,
                    selected: typeFilter == FeedPostType.spot,
                    onTap: () => onTypeSelected(FeedPostType.spot)),
                const SizedBox(width: 8),
                _TypeChip(
                    label: l10n.feedFilterRoute,
                    selected: typeFilter == FeedPostType.route,
                    onTap: () => onTypeSelected(FeedPostType.route)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : CocoTheme.secondary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// 필터 아이콘 탭 시 뜨는 바텀시트 — 구 선택 → 동 칩이 부드럽게 펼쳐지는 동네 필터 +
/// 정렬 칩 + 적용 버튼. 부산 16개 구·군 전체(busanGuList)를 다루다 보니 동 목록이
/// 길어질 수 있어(중구만 41개) 가운데 영역만 스크롤되게 하고 손잡이/제목/적용
/// 버튼은 고정한다.
class _FilterSheet extends StatefulWidget {
  final String dongId;
  final String sortBy;
  final int resultCount;
  final String? myNearestDongId;
  final ValueChanged<String> onDongSelected;
  final ValueChanged<String> onSortSelected;
  final VoidCallback onReset;
  final VoidCallback onApply;

  const _FilterSheet({
    required this.dongId,
    required this.sortBy,
    required this.resultCount,
    required this.myNearestDongId,
    required this.onDongSelected,
    required this.onSortSelected,
    required this.onReset,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _expandedGu;
  late bool _sheetExpanded;

  @override
  void initState() {
    super.initState();
    // 시트를 열었을 때 이미 특정 동/구가 선택돼 있으면 그 구를 펼친 채로 보여준다.
    _expandedGu = _guOf(widget.dongId);
    _sheetExpanded = _expandedGu != null;
  }

  @override
  void didUpdateWidget(covariant _FilterSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // "초기화" 버튼 등으로 바깥에서 dongId가 바뀌면 펼침 상태도 맞춰준다.
    if (oldWidget.dongId != widget.dongId) {
      final gu = _guOf(widget.dongId);
      _expandedGu = gu;
      if (gu != null) _sheetExpanded = true;
    }
  }

  String? _guOf(String dongId) {
    final parts = dongId.split('|');
    return parts.length == 2 ? parts.first : null;
  }

  List<String> _dongsOf(String regionName) {
    final guNames = busanGusForFeedRegion(regionName);
    final names = <String>{};
    for (final gu in busanGuList) {
      if (!guNames.contains(gu.name)) continue;
      for (final dong in gu.dongs) {
        names.add(normalizeBusanDongName(dong.name));
      }
    }
    return names.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final expandedGu = _expandedGu;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        height: screenHeight * (_sheetExpanded ? 0.90 : 0.64),
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.feedFilterSheetTitle,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CocoTheme.secondary)),
                    TextButton(
                      onPressed: widget.onReset,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: Text(l10n.feedFilterReset,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.4))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(l10n.feedFilterDongLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.45))),
                          if (widget.myNearestDongId != null) ...[
                            const SizedBox(width: 8),
                            Text(
                                l10n.feedFilterNearLabel(_localizedDongLabel(
                                    widget.myNearestDongId!,
                                    l10n,
                                    languageCode)),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black.withOpacity(0.32))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SheetChip(
                        label:
                            _localizedDongLabel(kAllDongId, l10n, languageCode),
                        selected: widget.dongId == kAllDongId,
                        onTap: () => widget.onDongSelected(kAllDongId),
                      ),
                      const SizedBox(height: 10),
                      // 실제 부산 행정경계 지도에서 구를 직접 탭해서 고른다 — 탭한 구가
                      // 파란 테두리 + 하늘색 채움으로 표시되고, 바로 아래 그 구의 동
                      // 목록이 펼쳐진다.
                      BusanDistrictMap(
                        selectedRegion: expandedGu,
                        onRegionTap: (region) => setState(() {
                          _sheetExpanded = true;
                          _expandedGu = _expandedGu == region ? null : region;
                        }),
                      ),
                      if (expandedGu != null)
                        TweenAnimationBuilder<double>(
                          key: ValueKey(expandedGu),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 340),
                          curve: Curves.easeOutCubic,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SheetChip(
                                  label: _localizedDongLabel(
                                      makeGuAllId(expandedGu),
                                      l10n,
                                      languageCode),
                                  selected:
                                      widget.dongId == makeGuAllId(expandedGu),
                                  onTap: () => widget
                                      .onDongSelected(makeGuAllId(expandedGu)),
                                ),
                                for (final dong in _dongsOf(expandedGu))
                                  _SheetChip(
                                    label: dong,
                                    selected: widget.dongId ==
                                        makeDongId(expandedGu, dong),
                                    icon: widget.myNearestDongId ==
                                            makeDongId(expandedGu, dong)
                                        ? Icons.location_on_rounded
                                        : null,
                                    onTap: () => widget.onDongSelected(
                                        makeDongId(expandedGu, dong)),
                                  ),
                              ],
                            ),
                          ),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 22 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.feedFilterSortLabel,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.45))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in feedSortLabels.entries)
                          _SheetChip(
                            label: _localizedSortLabel(entry.key, l10n),
                            selected: widget.sortBy == entry.key,
                            onTap: () => widget.onSortSelected(entry.key),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CocoTheme.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: widget.onApply,
                  child: Text(l10n.feedFilterApplyButton(widget.resultCount),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _SheetChip(
      {required this.label,
      required this.selected,
      this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : CocoTheme.secondary),
              child: Text(label),
            ),
            if (icon != null) ...[
              const SizedBox(width: 5),
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                tween: ColorTween(
                    end: selected ? Colors.white : CocoTheme.primary),
                builder: (context, color, _) =>
                    Icon(icon, size: 12, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.feedEmptyTitle,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(l10n.feedEmptySubtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  final bool loadingMore;
  final bool showEndMessage;
  const _ListFooter({required this.loadingMore, required this.showEndMessage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.8, color: CocoTheme.primary),
            ),
            const SizedBox(width: 8),
            Text(l10n.feedLoadingMore,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    if (showEndMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: Text(l10n.feedEndOfList,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400))),
      );
    }
    return const SizedBox(height: 12);
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;
  final VoidCallback onPrevImg;
  final VoidCallback onNextImg;
  final VoidCallback onOpenDetail;

  const _FeedCard({
    required this.item,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onShare,
    required this.onPrevImg,
    required this.onNextImg,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.black.withOpacity(0.05)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFF0ECE6),
                child: Text(item.authorInitial,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CocoTheme.secondary)),
              ),
              const SizedBox(width: 8),
              Text(item.author ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CocoTheme.secondary)),
              const SizedBox(width: 6),
              const _LocalBadge(),
              if (item.trending) ...[
                const SizedBox(width: 6),
                const _TrendingBadge(),
              ],
              const Spacer(),
              Text(item.timeLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 10),
          _FeedCardPhoto(
              item: item,
              onTap: onOpenDetail,
              onPrevImg: onPrevImg,
              onNextImg: onNextImg),
          const SizedBox(height: 12),
          InkWell(
            onTap: onOpenDetail,
            child: Text(item.displayTitle,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CocoTheme.secondary)),
          ),
          const SizedBox(height: 4),
          Text(
            item.desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14, height: 1.4, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionIcon(
                icon: item.liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor:
                    item.liked ? CocoTheme.primary : Colors.grey.shade600,
                label: '${item.likeCount}',
                onTap: onToggleLike,
              ),
              const SizedBox(width: 18),
              _ActionIcon(
                icon: Icons.mode_comment_outlined,
                iconColor: Colors.grey.shade600,
                label: '${item.comments.length}',
                onTap: onOpenDetail,
              ),
              const SizedBox(width: 18),
              _ActionIcon(
                icon: Icons.share_outlined,
                iconColor: Colors.grey.shade600,
                label: '${item.shares}',
                onTap: onShare,
              ),
              const Spacer(),
              _ActionIcon(
                icon: item.saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                iconColor:
                    item.saved ? CocoTheme.secondary : Colors.grey.shade600,
                label: '${item.saveCount}',
                onTap: onToggleSave,
              ),
            ],
          ),
        ],
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
      decoration: BoxDecoration(
          color: CocoTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(AppLocalizations.of(context)!.feedLocalBadge,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: CocoTheme.primary)),
    );
  }
}

// 게시물이 태그한 스팟이 인기(trending) 상태일 때 표시 — 지도 탭의 로컬픽/인기 핀
// 강조색(#FF7A33)과 맞춰서 "인기 스팟" 개념을 시각적으로 통일했다.
class _TrendingBadge extends StatelessWidget {
  const _TrendingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFFF7A33).withOpacity(0.14),
          borderRadius: BorderRadius.circular(10)),
      child: Text(AppLocalizations.of(context)!.feedTrendingBadge,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7A33))),
    );
  }
}

class _FeedCardPhoto extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;
  final VoidCallback onPrevImg;
  final VoidCallback onNextImg;

  const _FeedCardPhoto(
      {required this.item,
      required this.onTap,
      required this.onPrevImg,
      required this.onNextImg});

  @override
  Widget build(BuildContext context) {
    final isRoute = item.type == FeedPostType.route;
    final color = isRoute ? CocoTheme.primary : categoryColor(item.category);

    // 캐러셀 화살표를 누르면 그제서야 다음 사진을 요청해서 느리게 느껴졌던
    // 문제 — 바로 옆(이전/다음) 사진을 미리 캐시해둬서 눌렀을 때 이미 로드된
    // 상태로 바로 넘어가게 한다.
    if (item.imgCount > 1) {
      final urls = item.imageUrls;
      final neighborIndexes = {
        (item.imgIndex + 1) % item.imgCount,
        (item.imgIndex - 1 + item.imgCount) % item.imgCount,
      };
      for (final idx in neighborIndexes) {
        if (idx < urls.length) {
          precacheImage(
              NetworkImage('${DioClient.baseUrl}${urls[idx]}'), context);
        }
      }
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              // 실제 업로드된 사진이 있으면 그걸 보여주고, 없으면(목업/코스/사진 미첨부)
              // 카테고리 색상 플레이스홀더를 그대로 쓴다.
              Positioned.fill(
                child: item.currentImageUrl != null
                    ? Image.network(
                        '${DioClient.baseUrl}${item.currentImageUrl}',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: color.withOpacity(0.08),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: color.withOpacity(0.12),
                        alignment: Alignment.center,
                        child: Icon(
                          isRoute
                              ? Icons.signpost_rounded
                              : categoryIcon(item.category),
                          size: 36,
                          color: color.withOpacity(0.4),
                        ),
                      ),
              ),
              if (isRoute)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      AppLocalizations.of(context)!
                          .feedRouteSpotCountBadge(item.stopCount ?? 0),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CocoTheme.primary),
                    ),
                  ),
                )
              // 스팟 태그 없이 쓴 글이면 place가 빈 문자열이라 위치 배지를 아예 안 그린다.
              else if (item.place.isNotEmpty)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.dong,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: CocoTheme.primary)),
                        const SizedBox(width: 6),
                        Text(item.place,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: CocoTheme.secondary)),
                      ],
                    ),
                  ),
                ),
              if (item.imgCount > 1) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: _CarouselArrow(
                          icon: Icons.chevron_left_rounded, onTap: onPrevImg)),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: _CarouselArrow(
                          icon: Icons.chevron_right_rounded, onTap: onNextImg)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < item.imgCount; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == item.imgIndex
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
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
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 18, color: CocoTheme.secondary)),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _ActionIcon(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.onTap});

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
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

/// 골목지도 탭 전용 랭킹 리스트 — 카드 피드 대신 순위·통계 중심으로 보여준다.
class _RouteRankingList extends StatelessWidget {
  final List<FeedItem> items;
  final ValueChanged<FeedItem> onToggleSave;
  const _RouteRankingList({required this.items, required this.onToggleSave});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (int i = 0; i < items.length; i++)
          _RouteRankRow(
              rank: i + 1,
              item: items[i],
              onToggleSave: () => onToggleSave(items[i])),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Text(
            AppLocalizations.of(context)!.feedRankingSavedHint,
            style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Colors.black.withOpacity(0.35)),
          ),
        ),
      ],
    );
  }
}

class _RouteRankRow extends StatelessWidget {
  final int rank;
  final FeedItem item;
  final VoidCallback onToggleSave;
  const _RouteRankRow(
      {required this.rank, required this.item, required this.onToggleSave});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: rank == 1
                      ? CocoTheme.primary
                      : Colors.black.withOpacity(0.3)),
            ),
          ),
          const SizedBox(width: 12),
          const _RouteThumb(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CocoTheme.secondary)),
                const SizedBox(height: 3),
                Text(
                    '@${item.author} · ${item.dong} · ${l10n.feedRankSpotCount(item.stopCount ?? 0)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.black.withOpacity(0.45))),
                const SizedBox(height: 5),
                Text(
                    l10n.feedRankStatsLine(
                        item.saveCount, item.likeCount, item.shares),
                    style: TextStyle(
                        fontSize: 11, color: Colors.black.withOpacity(0.4))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggleSave,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: item.saved ? const Color(0xFFFF5A36) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: item.saved
                        ? const Color(0xFFFF5A36)
                        : Colors.grey.shade300),
              ),
              child: Text(
                item.saved
                    ? l10n.feedSaveButtonSaved
                    : l10n.feedSaveButtonUnsaved,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.saved
                        ? Colors.white
                        : Colors.black.withOpacity(0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 골목지도 랭킹 항목의 64x64 장식용 썸네일 — 실제 좌표 없이 골목지도 느낌만 낸다.
class _RouteThumb extends StatelessWidget {
  const _RouteThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
          color: const Color(0xFFEAE8E2),
          borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
              left: 0,
              top: 28,
              right: 0,
              height: 4,
              child: Container(color: Colors.white)),
          Positioned(
              left: 23,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(color: Colors.white)),
          Positioned(left: 9, top: 14, child: _pin()),
          Positioned(left: 37, top: 37, child: _pin()),
        ],
      ),
    );
  }

  Widget _pin() => Transform.rotate(
        angle: -0.78,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
              color: CocoTheme.primary,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                  bottomRight: Radius.circular(5))),
        ),
      );
}
