import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/qna/qna_screen.dart';
import '../screens/mypage/mypage_screen.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell>
    with SingleTickerProviderStateMixin {
  // 선택되지 않은 탭 아이콘/라벨 색 — 기본 M3 회색보다 약간 어둡게
  static const _unselectedColor = Color(0xFF616161);
  static const _mapTabIndex = 1;

  // ⚠️ 탭 화면들을 go_router의 ShellRoute가 넘겨주는 widget.child를 그대로 쓰지 않고,
  // 여기서 직접, 한 번만 만들어서 계속 재사용한다.
  //
  // 이전에 겪었던 문제들의 진짜 원인: plain ShellRoute는 탭이 바뀌어도 내부적으로
  // "같은 Navigator"를 재사용해서 현재 페이지만 바꿔치기하는 구조다. 그래서
  // AnimatedSwitcher로 widget.child를 슬라이드/페이드시키면, 전환 애니메이션이
  // 진행되는 짧은 순간 이전 화면과 새 화면이 사실상 동일한 GlobalKey를 공유한 채
  // 동시에 트리에 올라가버려 "Duplicate GlobalKey" 충돌이 났다. 또한 AnimatedSwitcher는
  // 같은 key를 가진 자식이 다시 나타나면 예전에 캐시해둔(다른 방향으로 만들어졌던)
  // 전환 애니메이션을 재사용해버려서, 매번 새로 계산한 이동 방향과 실제 화면에 보이는
  // 방향이 어긋나는 문제도 있었다.
  //
  // 아래처럼 4개 화면을 각각 고유하고 고정된 Key로 딱 한 번만 만들어 계속 들고 있으면:
  // - 전환 중 두 화면을 동시에 Stack에 띄워도 서로 다른 Key라 절대 충돌하지 않고
  // - 매 전환마다 내가 직접 만드는 AnimationController로 방향을 새로 계산해서 적용하므로
  //   캐시된 이전 애니메이션이 재사용될 일도 없다.
  static final List<Widget> _screens = [
    const KeyedSubtree(key: ValueKey('feed'), child: FeedScreen()),
    const KeyedSubtree(key: ValueKey('map'), child: MapScreen()),
    const KeyedSubtree(key: ValueKey('qna'), child: QnaScreen()),
    const KeyedSubtree(key: ValueKey('mypage'), child: MypageScreen()),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  // 슬라이드(지도가 아닌 화면)에만 easing을 입혀서 더 빠르고 부드럽게 느껴지게 한다.
  // 지도 화면의 페이드는 그대로 _controller(선형)를 써서 건드리지 않는다.
  late final Animation<double> _slideCurve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  int _currentIndex = 0;
  // null이면 전환 애니메이션이 진행 중이 아니라는 뜻 — 이때는 현재 화면 하나만 그린다.
  int? _outgoingIndex;
  bool _forward = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 지도 탭(index 1)의 카카오맵은 HtmlElementView로 띄우는 플랫폼 뷰라서, Flutter web에서
  // Transform 기반 애니메이션(SlideTransition)을 씌우면 실제 DOM 위치가 프레임 단위로
  // 따라오지 못하고 애니메이션이 끝나는 순간에만 재동기화되며 튀는 게 Flutter 자체의
  // 알려진 한계다(https://github.com/flutter/flutter/issues/24408 등 — opacity/clipping은
  // 적용되지만 위치 이동 트랜스폼은 플랫폼 뷰에 안정적으로 안 먹힘). 그래서 지도 화면
  // "자신"만 Transform 없이 페이드로 두고, 지도가 아닌 화면은 그대로 슬라이드시킨다 —
  // 지도와 짝지어지는 전환에서도 최소한 반대쪽 화면의 움직임으로 방향감은 남는다.
  Widget _transitionFor({
    required int index,
    required Offset beginOffset,
    required Offset endOffset,
    required bool fadeIn,
    required Widget child,
  }) {
    if (index == _mapTabIndex) {
      return FadeTransition(
        opacity: fadeIn
            ? _controller
            : Tween<double>(begin: 1, end: 0).animate(_controller),
        child: child,
      );
    }
    return SlideTransition(
      position: Tween<Offset>(begin: beginOffset, end: endOffset)
          .animate(_slideCurve),
      child: child,
    );
  }

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
    final resolvedIdx = currentIdx < 0 ? 0 : currentIdx;

    // 실제로 탭이 바뀐 순간에만 새 전환을 시작한다. 방향은 "바뀌기 직전 인덱스"
    // 기준으로 그 즉시 계산해서 _forward에 고정하고, 애니메이션이 끝나면
    // _outgoingIndex를 지워서 다시 화면 하나만 그리는 상태로 돌아간다.
    if (resolvedIdx != _currentIndex) {
      _outgoingIndex = _currentIndex;
      _forward = resolvedIdx > _currentIndex;
      _currentIndex = resolvedIdx;
      _controller
        ..stop()
        ..value = 0;
      _controller.forward().whenComplete(() {
        if (mounted) setState(() => _outgoingIndex = null);
      });
    }

    final outgoingIndex = _outgoingIndex;
    final dx = _forward ? 1.0 : -1.0;

    return Scaffold(
      // ⚠️ 전환 중이든 아니든 항상 "AnimatedBuilder > Stack > SlideTransition/
      // FadeTransition" 이라는 동일한 트리 구조를 유지한다. 예전엔 전환이 끝나면
      // 이 래퍼들을 통째로 걷어내고 화면을 Scaffold.body에 바로 꽂았는데, 그 순간
      // 화면의 부모가 바뀌면서(Stack 밑 → Scaffold 바로 밑) 한 프레임 재배치가
      // 일어나 "끝나는 순간 움찔"하는 원인이 됐다. 지금은 idle 상태에서도 컨트롤러
      // 값이 애니메이션 종료 지점(1.0)에 그대로 머물러 있어서 Tween이 항상
      // Offset.zero/불투명도 1.0으로 수렴하므로, 구조를 안 바꿔도 동일하게 보인다.
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final incoming = _transitionFor(
            index: _currentIndex,
            beginOffset: Offset(dx, 0),
            endOffset: Offset.zero,
            fadeIn: true,
            child: _screens[_currentIndex],
          );
          if (outgoingIndex == null) {
            return Stack(fit: StackFit.expand, children: [incoming]);
          }
          final outgoing = _transitionFor(
            index: outgoingIndex,
            beginOffset: Offset.zero,
            endOffset: Offset(-dx, 0),
            fadeIn: false,
            child: _screens[outgoingIndex],
          );
          return Stack(fit: StackFit.expand, children: [outgoing, incoming]);
        },
      ),
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
