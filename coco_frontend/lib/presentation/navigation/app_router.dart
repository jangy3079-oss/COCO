import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/qna/qna_screen.dart';
import '../screens/mypage/mypage_screen.dart';
import 'bottom_nav_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login',  builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
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
