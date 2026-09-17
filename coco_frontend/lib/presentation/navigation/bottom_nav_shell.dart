import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

class BottomNavShell extends StatelessWidget {
  final Widget child;
  const BottomNavShell({super.key, required this.child});

  // 선택되지 않은 탭 아이콘/라벨 색 — 기본 M3 회색보다 약간 어둡게
  static const _unselectedColor = Color(0xFF616161);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 라벨이 로케일에 따라 바뀌어야 해서, 더 이상 컴파일타임 상수가 아니라
    // build() 안에서 매번 새로 만든다.
    final tabs = [
      (icon: Icons.home_rounded,   label: l10n.navFeed,      path: '/feed'),
      (icon: Icons.map_rounded,    label: l10n.navMap,       path: '/map'),
      (icon: Icons.groups_rounded, label: l10n.navCommunity, path: '/qna'),
      (icon: Icons.person_rounded, label: l10n.navMy,        path: '/mypage'),
    ];
    final location = GoRouterState.of(context).uri.toString();
    final currentIdx = tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      // 배경(흰색)과 동일한 색으로 통일 — 기본 NavigationBar의 surface 틴트/그림자를
      // 걷어내고 흰 배경 + 옅은 상단 구분선만 남긴다.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          // 선택된 탭 아이콘 뒤 pill 표시 안 함 — 색 구분은 아이콘/라벨 색으로만
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? CocoTheme.primary : _unselectedColor,
            );
          }),
          selectedIndex: currentIdx < 0 ? 0 : currentIdx,
          onDestinationSelected: (i) => context.go(tabs[i].path),
          destinations: tabs.map((t) => NavigationDestination(
            icon: Icon(t.icon, color: _unselectedColor),
            selectedIcon: Icon(t.icon, color: CocoTheme.primary),
            label: t.label,
          )).toList(),
        ),
      ),
    );
  }
}
