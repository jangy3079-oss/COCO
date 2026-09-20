import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/network/login_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../feed/feed_mock_data.dart';
import '../map/map_mock_data.dart';

/// "저장 · 좋아요" 화면. 찜한 스팟 / 좋아요한 피드 / 저장한 피드 / 저장한 코스
/// 4개 필터를 탭으로 전환하며, 각 항목의 해제 버튼을 누르면 그 자리에서 바로
/// 공유 상태(likedSpotIds/FeedItem.liked/mockMyRoutes)에 반영된다.
class MySavedScreen extends StatefulWidget {
  final String initialFilter; // spots | likedFeed | savedFeed | routes
  const MySavedScreen({super.key, this.initialFilter = 'spots'});

  @override
  State<MySavedScreen> createState() => _MySavedScreenState();
}

class _MySavedScreenState extends State<MySavedScreen> {
  late String _filter = widget.initialFilter;

  final _feedRepository = FeedRepository();
  // GET /api/feed/liked 결과 — "좋아요한 피드" 탭 전용.
  List<FeedItem> _likedItems = [];
  bool _loadingLiked = false;
  // GET /api/feed/saved 결과 — "저장한 피드" 탭 전용.
  List<FeedItem> _savedItems = [];
  bool _loadingSaved = false;

  @override
  void initState() {
    super.initState();
    _loadLikedFeed();
    _loadSavedFeed();
  }

  Future<void> _loadLikedFeed() async {
    setState(() => _loadingLiked = true);
    try {
      final posts = await _feedRepository.fetchLikedFeed(
        locale: context.read<LocaleController>().locale.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _likedItems = posts.map(feedItemFromPost).toList();
        _loadingLiked = false;
      });
    } catch (e) {
      debugPrint('[MySavedScreen] 좋아요 피드 조회 실패: $e');
      if (mounted) setState(() => _loadingLiked = false);
    }
  }

  Future<void> _loadSavedFeed() async {
    setState(() => _loadingSaved = true);
    try {
      final posts = await _feedRepository.fetchSavedFeed(
        locale: context.read<LocaleController>().locale.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _savedItems = posts.map(feedItemFromPost).toList();
        _loadingSaved = false;
      });
    } catch (e) {
      debugPrint('[MySavedScreen] 저장 피드 조회 실패: $e');
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _toggleLike(FeedItem item) async {
    final postId = item.realPostId;
    if (postId == null) return;
    if (!requireLogin(context)) return;
    setState(() => item.liked = !item.liked);
    try {
      await _feedRepository.toggleLike(postId);
      // 좋아요 실제 해제 시 목록에서 지운다
      if (!item.liked && mounted) setState(() => _likedItems.remove(item));
    } catch (e) {
      if (!mounted) return;
      setState(() => item.liked = !item.liked);
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        debugPrint('[MySavedScreen] 좋아요 해제 실패: $e');
      }
    }
  }

  Future<void> _toggleSave(FeedItem item) async {
    final postId = item.realPostId;
    if (postId == null) return;
    if (!requireLogin(context)) return;
    setState(() => item.saved = !item.saved);
    try {
      await _feedRepository.toggleSave(postId);
      // 저장 실제 해제 시 목록에서 지운다
      if (!item.saved && mounted) setState(() => _savedItems.remove(item));
    } catch (e) {
      if (!mounted) return;
      setState(() => item.saved = !item.saved);
      if (isUnauthorized(e)) {
        requireLogin(context);
      } else {
        debugPrint('[MySavedScreen] 저장 해제 실패: $e');
      }
    }
  }

  List<(String, String)> _filters(AppLocalizations l10n) => [
        ('spots', l10n.mySavedFilterSpots),
        ('likedFeed', l10n.mySavedFilterLikedFeed),
        ('savedFeed', l10n.mySavedFilterSavedFeed),
        ('routes', l10n.mySavedFilterRoutes),
      ];

  List<_SavedEntry> get _entries {
    final l10n = AppLocalizations.of(context)!;
    switch (_filter) {
      case 'likedFeed':
        return _likedItems.map((f) => _SavedEntry(
              name: f.place,
              meta: l10n.mySavedMetaLiked(f.author ?? 'COCO', f.likeCount),
              color: categoryColor(f.category),
              icon: categoryIcon(f.category),
              actionLabel: l10n.mySavedActionUnlike,
              onAction: () => _toggleLike(f),
              onTap: () async {
                await context.push('/feed/post', extra: f);
                if (mounted) setState(() {});
              },
            )).toList();
      case 'savedFeed':
        return _savedItems.map((f) => _SavedEntry(
              name: f.place.isNotEmpty ? f.place : f.desc,
              meta: l10n.mySavedMetaSaved(f.author ?? 'COCO', f.saveCount),
              color: categoryColor(f.category),
              icon: categoryIcon(f.category),
              actionLabel: l10n.mySavedActionUnsave,
              onAction: () => _toggleSave(f),
              onTap: () async {
                await context.push('/feed/post', extra: f);
                if (mounted) setState(() {});
              },
            )).toList();
      case 'routes':
        return savedRoutes.map((r) {
          final numId = dbRouteNumericId(r.id);
          return _SavedEntry(
            name: r.name,
            meta: l10n.mySavedMetaRoute(r.stops.length),
            color: CocoTheme.primary,
            icon: Icons.map_outlined,
            actionLabel: l10n.mySavedActionUnsave,
            onAction: () async {
              if (numId == null) return;
              if (!requireLogin(context)) return;
              try {
                await toggleRouteSave(numId);
                if (mounted) setState(() {});
              } catch (e) {
                if (isUnauthorized(e)) {
                  requireLogin(context);
                } else {
                  debugPrint('[MySavedScreen] 코스 저장 해제 실패: $e');
                }
              }
            },
            // 저장한 코스는 내가 만든 게 아니라 저장만 해둔 것이라, 코스 상세에서
            // 편집·공유는 못 하고 보기만 가능하다(isOwner: false).
            onTap: () => context.push('/map/route/preview', extra: {
              'name': r.name,
              'stops': r.stops,
              'routeId': r.id,
              'isOwner': false,
            }),
          );
        }).toList();
      case 'spots':
      default:
        // 찜한 id 순서대로 DB 스팟을 map_mock_data.dart의 공유 캐시(dbSpotCache)에서
        // 찾는다 — refreshLikedSpots가 likedSpotIds와 함께 채워주므로 보통 다 있지만,
        // 혹시 캐시에 없는 id는 건너뛴다(이론상 거의 발생 안 함).
        final result = <_SavedEntry>[];
        for (final numId in likedSpotIds) {
          final s = dbSpotCache['db-$numId'];
          if (s == null) continue;
          result.add(_SavedEntry(
            name: s.name,
            meta: s.subtitle,
            color: s.pinColor,
            icon: s.icon,
            actionLabel: l10n.mySavedActionUnwish,
            onAction: () async {
              if (!requireLogin(context)) return;
              setState(() => likedSpotIds.remove(numId));
              try {
                await toggleSpotLike(numId);
              } catch (e) {
                if (!mounted) return;
                setState(() => likedSpotIds.add(numId));
                if (isUnauthorized(e)) {
                  requireLogin(context);
                } else {
                  debugPrint('[MySavedScreen] 찜 해제 실패: $e');
                }
              }
            },
            onTap: () async {
              await context.push('/map/spot/db-$numId');
              if (mounted) setState(() {});
            },
          ));
        }
        return result;
    }
  }

  ({String text, String cta, VoidCallback onCta}) get _empty {
    final l10n = AppLocalizations.of(context)!;
    switch (_filter) {
      case 'likedFeed':
        return (text: l10n.mySavedEmptyLikedFeed, cta: l10n.myPostsGoToFeedButton, onCta: () => context.go('/feed'));
      case 'savedFeed':
        return (text: l10n.mySavedEmptySavedFeed, cta: l10n.myPostsGoToFeedButton, onCta: () => context.go('/feed'));
      case 'routes':
        return (text: l10n.mySavedEmptyRoutes, cta: l10n.myMapGoToMapButton, onCta: () => context.go('/map'));
      case 'spots':
      default:
        return (text: l10n.mySavedEmptySpots, cta: l10n.myMapGoToMapButton, onCta: () => context.go('/map'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final empty = _empty;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 6),
                  Text(l10n.myPageMenuSaved, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _filters(l10n)) ...[
                      _FilterChip(label: f.$2, selected: _filter == f.$1, onTap: () => setState(() => _filter = f.$1)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: (_filter == 'likedFeed' && _loadingLiked) || (_filter == 'savedFeed' && _loadingSaved)
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                  ? _EmptyState(text: empty.text, cta: empty.cta, onCta: empty.onCta)
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                      itemBuilder: (context, i) => _SavedRow(entry: entries[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedEntry {
  final String name;
  final String meta;
  final Color color;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onTap;

  _SavedEntry({
    required this.name,
    required this.meta,
    required this.color,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.onTap,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(fontFamily: 'NotoSansKR', fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary),
          child: Text(label),
        ),
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  final _SavedEntry entry;
  const _SavedRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: entry.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(entry.icon, color: entry.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                  const SizedBox(height: 3),
                  Text(entry.meta, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: entry.onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.black.withOpacity(0.12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(entry.actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  final String cta;
  final VoidCallback onCta;
  const _EmptyState({required this.text, required this.cta, required this.onCta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CocoTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: onCta,
              child: Text(cta),
            ),
          ],
        ),
      ),
    );
  }
}
