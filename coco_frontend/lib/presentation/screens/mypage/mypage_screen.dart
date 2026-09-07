import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../map/map_mock_data.dart';
import '../map/map_screen.dart' show MockMapBackground;
import 'mypage_mock_data.dart';

/// 마이(MY) 메인 화면. 프로필 헤더 + "나의 지도" 미리보기 위젯 + 메뉴 리스트.
/// 메뉴 항목들은 전부 하단 탭 없는 전체화면(ShellRoute 바깥 최상위 라우트)으로 이동한다.
class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> {
  // 다른 화면(프로필 수정/찜 해제 등)에서 돌아왔을 때 반영되도록
  // 피드·커뮤니티 탭과 동일하게 push 후 setState하는 패턴을 쓴다.
  Future<void> _open(String path, {Object? extra}) async {
    await context.push(path, extra: extra);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final savedSpots = mockSpots.where((s) => savedSpotIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(myNickname, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(myRoleLabel, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(12)),
                        child: const Text(myNeighborhood, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.07)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: _MyMapCard(spots: savedSpots, onTap: () => _open('/mypage/map')),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.07)),
            _MenuRow(icon: Icons.article_outlined, label: '내가 쓴 글', onTap: () => _open('/mypage/posts')),
            _MenuRow(icon: Icons.favorite_border_rounded, label: '저장 · 좋아요', onTap: () => _open('/mypage/saved')),
            _MenuRow(icon: Icons.map_outlined, label: '내가 만든 골목지도', onTap: () => _open('/mypage/routes')),
            _MenuRow(icon: Icons.forum_outlined, label: '내 질문 · 답변 활동', onTap: () => _open('/mypage/posts', extra: 'qna')),
            _MenuRow(icon: Icons.person_outline_rounded, label: '프로필 수정', onTap: () => _open('/mypage/profile/edit')),
            _MenuRow(icon: Icons.notifications_outlined, label: '알림 설정', onTap: () => _open('/mypage/settings')),
            _MenuRow(icon: Icons.settings_outlined, label: '설정', onTap: () => _open('/mypage/settings')),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              label: 'COCO 이용 안내',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('준비 중이에요'), duration: Duration(seconds: 1)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MyMapCard extends StatelessWidget {
  final List<MockSpot> spots;
  final VoidCallback onTap;
  const _MyMapCard({required this.spots, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: spots.isEmpty
                  ? Container(
                      color: const Color(0xFFEAE8E2),
                      alignment: Alignment.center,
                      child: Text('아직 찜한 스팟이 없어요', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    )
                  // 미리보기는 탭만 카드 전체에서 받으면 되므로 지도 자체의 핀 탭은 막아둔다.
                  : IgnorePointer(
                      child: MockMapBackground(spots: spots, onSpotTap: (_) {}),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('나의 지도', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
              Text('찜한 스팟 ${spots.length}곳 · 전체보기 ›', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.07)))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, color: CocoTheme.secondary)),
            Icon(icon, size: 22, color: CocoTheme.secondary.withOpacity(0.75)),
          ],
        ),
      ),
    );
  }
}
