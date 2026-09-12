import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../feed/feed_mock_data.dart';
import '../map/map_mock_data.dart';

/// "저장 · 좋아요" 화면. 찜한 스팟 / 좋아요한 피드 / 저장한 피드 / 저장한 코스
/// 4개 필터를 탭으로 전환하며, 각 항목의 해제 버튼을 누르면 그 자리에서 바로
/// 공유 상태(savedSpotIds/FeedItem.liked·saved/mockMyRoutes)에 반영된다.
class MySavedScreen extends StatefulWidget {
  final String initialFilter; // spots | likedFeed | savedFeed | routes
  const MySavedScreen({super.key, this.initialFilter = 'spots'});

  @override
  State<MySavedScreen> createState() => _MySavedScreenState();
}

class _MySavedScreenState extends State<MySavedScreen> {
  late String _filter = widget.initialFilter;

  static const _filters = [
    ('spots', '찜한 스팟'),
    ('likedFeed', '좋아요한 피드'),
    ('savedFeed', '저장한 피드'),
    ('routes', '저장한 코스'),
  ];

  List<_SavedEntry> get _entries {
    switch (_filter) {
      case 'likedFeed':
        return mockFeedItems.where((f) => f.liked).map((f) => _SavedEntry(
              name: f.place,
              meta: '@${f.author ?? 'COCO'} · 좋아요 ${f.likeCount}',
              color: categoryColor(f.category),
              icon: categoryIcon(f.category),
              actionLabel: '좋아요 해제',
              onAction: () => setState(() => f.liked = false),
              onTap: () async {
                await context.push('/feed/post', extra: f);
                if (mounted) setState(() {});
              },
            )).toList();
      case 'savedFeed':
        return mockFeedItems.where((f) => f.saved).map((f) => _SavedEntry(
              name: f.place,
              meta: '@${f.author ?? 'COCO'} · 저장 ${f.saveCount}',
              color: categoryColor(f.category),
              icon: categoryIcon(f.category),
              actionLabel: '저장 해제',
              onAction: () => setState(() => f.saved = false),
              onTap: () async {
                await context.push('/feed/post', extra: f);
                if (mounted) setState(() {});
              },
            )).toList();
      case 'routes':
        return mockMyRoutes.map((r) => _SavedEntry(
              name: r.name,
              meta: '스팟 ${r.stops.length}곳 · 내가 만든 코스',
              color: CocoTheme.primary,
              icon: Icons.map_outlined,
              actionLabel: '삭제',
              onAction: () => setState(() => mockMyRoutes.remove(r)),
              // 저장한 코스는 내가 만든 게 아니라 저장만 해둔 것이라, 코스 상세에서
              // 편집·공유는 못 하고 보기만 가능하다(isOwner: false).
              onTap: () => context.push('/map/route/preview', extra: {
                'name': r.name,
                'stops': r.stops,
                'routeId': r.id,
                'isOwner': false,
              }),
            )).toList();
      case 'spots':
      default:
        // 찜한 id 순서대로 목업/DB 스팟을 각자의 출처에서 찾는다 — DB 스팟은
        // map_mock_data.dart의 공유 캐시(dbSpotCache)에서(지도/상세 화면에서 한 번이라도
        // 불러온 적 있어야 여기서도 보인다 — 앱을 새로 켠 직후라 캐시가 비어있으면 아직 안 보일 수 있음).
        final result = <_SavedEntry>[];
        for (final id in savedSpotIds) {
          MockSpot? s;
          if (id.startsWith('db-')) {
            s = dbSpotCache[id];
          } else {
            for (final m in mockSpots) {
              if (m.id == id) {
                s = m;
                break;
              }
            }
          }
          if (s == null) continue;
          result.add(_SavedEntry(
            name: s.name,
            meta: s.subtitle,
            color: s.pinColor,
            icon: s.icon,
            actionLabel: '찜 해제',
            onAction: () => setState(() => savedSpotIds.remove(id)),
            onTap: () async {
              await context.push('/map/spot/$id');
              if (mounted) setState(() {});
            },
          ));
        }
        return result;
    }
  }

  ({String text, String cta, VoidCallback onCta}) get _empty {
    switch (_filter) {
      case 'likedFeed':
        return (text: '좋아요한 피드가 없어요', cta: '피드로 가기', onCta: () => context.go('/feed'));
      case 'savedFeed':
        return (text: '저장한 피드가 없어요', cta: '피드로 가기', onCta: () => context.go('/feed'));
      case 'routes':
        return (text: '만든 코스가 없어요\n지도 탭에서 코스를 만들어보세요', cta: '지도로 가기', onCta: () => context.go('/map'));
      case 'spots':
      default:
        return (text: '찜한 스팟이 없어요\n지도 탭에서 스팟을 찜해보세요', cta: '지도로 가기', onCta: () => context.go('/map'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final empty = _empty;

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
                  const Text('저장 · 좋아요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _filters) ...[
                      _FilterChip(label: f.$2, selected: _filter == f.$1, onTap: () => setState(() => _filter = f.$1)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: entries.isEmpty
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary)),
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
