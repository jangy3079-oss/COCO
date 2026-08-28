import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/map/map_mock_data.dart';
import '../screens/map/spot_detail_screen.dart';
import '../screens/map/route_builder_screen.dart';
import '../screens/map/route_preview_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/feed/feed_mock_data.dart';
import '../screens/feed/feed_post_detail_screen.dart';
import '../screens/feed/feed_composer_screen.dart';
import '../screens/qna/qna_screen.dart';
import '../screens/qna/qna_mock_data.dart';
import '../screens/qna/qna_post_detail_screen.dart';
import '../screens/qna/qna_composer_screen.dart';
import '../screens/mypage/mypage_screen.dart';
import '../screens/mypage/my_map_screen.dart';
import '../screens/mypage/my_posts_screen.dart';
import '../screens/mypage/my_saved_screen.dart';
import '../screens/mypage/settings_screen.dart';
import '../screens/mypage/profile_edit_screen.dart';
import 'bottom_nav_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
    GoRoute(path: '/login',  builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
    // 스팟 상세 / 골목지도 만들기 / 골목지도 미리보기는 하단 탭 없이 전체 화면으로
    // 뜨는 흐름이라 ShellRoute 바깥의 최상위 라우트로 둔다.
    GoRoute(
      path: '/map/spot/:id',
      builder: (c, s) => SpotDetailScreen(spotId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/map/route/new',
      builder: (c, s) => RouteBuilderScreen(
        initialStops: (s.extra as List<MockSpot>?) ?? const [],
      ),
    ),
    GoRoute(
      path: '/map/route/preview',
      builder: (c, s) {
        final data = s.extra as Map<String, dynamic>;
        return RoutePreviewScreen(
          routeName: data['name'] as String,
          stops: data['stops'] as List<MockSpot>,
        );
      },
    ),
    // 피드 게시물 상세 / 게시물 작성도 하단 탭 없는 전체 화면 흐름이라
    // ShellRoute 바깥의 최상위 라우트로 둔다.
    GoRoute(
      path: '/feed/post',
      builder: (c, s) => FeedPostDetailScreen(item: s.extra as FeedItem),
    ),
    GoRoute(
      path: '/feed/compose',
      builder: (c, s) => const FeedComposerScreen(),
    ),
    // 질문 상세 / 질문 작성도 하단 탭 없는 전체 화면 흐름이라
    // ShellRoute 바깥의 최상위 라우트로 둔다.
    GoRoute(
      path: '/qna/post',
      builder: (c, s) => QnaPostDetailScreen(post: s.extra as QnaPost),
    ),
    GoRoute(
      path: '/qna/compose',
      builder: (c, s) => const QnaComposerScreen(),
    ),
    // 마이(MY) 탭 하위 화면들도 하단 탭 없는 전체 화면 흐름이라
    // ShellRoute 바깥의 최상위 라우트로 둔다.
    GoRoute(
      path: '/mypage/map',
      builder: (c, s) => const MyMapScreen(),
    ),
    GoRoute(
      path: '/mypage/posts',
      builder: (c, s) => MyPostsScreen(initialFilter: (s.extra as String?) ?? 'all'),
    ),
    GoRoute(
      path: '/mypage/saved',
      builder: (c, s) => MySavedScreen(initialFilter: (s.extra as String?) ?? 'spots'),
    ),
    GoRoute(
      path: '/mypage/settings',
      builder: (c, s) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/mypage/profile/edit',
      builder: (c, s) => const ProfileEditScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => BottomNavShell(child: child),
      routes: [
        GoRoute(path: '/feed',    builder: (c, s) => const FeedScreen()),
        GoRoute(path: '/map',     builder: (c, s) => const MapScreen()),
        GoRoute(path: '/qna',     builder: (c, s) => const QnaScreen()),
        GoRoute(path: '/mypage',  builder: (c, s) => const MypageScreen()),
      ],
    ),
  ],
);
