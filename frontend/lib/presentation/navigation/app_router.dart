import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/qna/qna_screen.dart';
import '../screens/mypage/mypage_screen.dart';
import 'bottom_nav_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => BottomNavShell(child: child),
      routes: [
        GoRoute(path: '/home',    builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/map',     builder: (c, s) => const MapScreen()),
        GoRoute(path: '/feed',    builder: (c, s) => const FeedScreen()),
        GoRoute(path: '/qna',     builder: (c, s) => const QnaScreen()),
        GoRoute(path: '/mypage',  builder: (c, s) => const MypageScreen()),
      ],
    ),
  ],
);
