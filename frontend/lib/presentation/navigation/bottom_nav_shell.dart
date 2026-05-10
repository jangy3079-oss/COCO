import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavShell extends StatelessWidget {
  final Widget child;
  const BottomNavShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.home_rounded,        label: '홈',   path: '/home'),
    (icon: Icons.map_rounded,         label: '지도',  path: '/map'),
    (icon: Icons.photo_camera_rounded,label: '피드',  path: '/feed'),
    (icon: Icons.chat_bubble_rounded, label: 'Q&A',  path: '/qna'),
    (icon: Icons.person_rounded,      label: 'MY',   path: '/mypage'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIdx = _tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIdx < 0 ? 0 : currentIdx,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          label: t.label,
        )).toList(),
      ),
    );
  }
}
