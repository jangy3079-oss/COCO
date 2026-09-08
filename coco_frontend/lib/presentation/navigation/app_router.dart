import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/map/map_mock_data.dart';
import '../screens/map/spot_detail_screen.dart';
import '../screens/map/route_builder_screen.dart';
import '../screens/map/route_preview_screen.dart';
import '../screens/map/spot_register_mock_data.dart';
import '../screens/map/spot_register_search_screen.dart';
import '../screens/map/spot_register_form_screen.dart';
import '../screens/map/spot_register_pending_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/feed/feed_mock_data.dart';
import '../screens/feed/feed_post_detail_screen.dart';
import '../screens/feed/feed_composer_screen.dart';
import '../screens/feed/feed_route_compose_screen.dart';
import '../screens/qna/qna_screen.dart';
import '../screens/qna/qna_mock_data.dart';
import '../screens/qna/qna_post_detail_screen.dart';
import '../screens/qna/qna_composer_screen.dart';
import '../screens/mypage/mypage_screen.dart';
import '../screens/mypage/my_posts_screen.dart';
import '../screens/mypage/my_saved_screen.dart';
import '../screens/mypage/my_routes_screen.dart';
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
      builder: (c, s) {
        final extra = s.extra;
        // "내가 만든 골목지도"의 편집 진입은 {editingRouteId, initialName, initialStops}
        // Map으로 넘어오고, 지도 탭 "코스 저장하기"의 신규 생성 진입은 List<MockSpot>가
        // 그대로 넘어온다 — 두 호출부 모양이 달라서 여기서 갈라서 받는다.
        if (extra is Map<String, dynamic>) {
          return RouteBuilderScreen(
            initialStops: extra['initialStops'] as List<MockSpot>? ?? const [],
            editingRouteId: extra['editingRouteId'] as String?,
            initialName: extra['initialName'] as String? ?? '',
          );
        }
        return RouteBuilderScreen(initialStops: (extra as List<MockSpot>?) ?? const []);
      },
    ),
    GoRoute(
      path: '/map/route/preview',
      builder: (c, s) {
        final data = s.extra as Map<String, dynamic>;
        return RoutePreviewScreen(
          routeName: data['name'] as String,
          stops: data['stops'] as List<MockSpot>,
          routeId: data['routeId'] as String?,
          isOwner: data['isOwner'] as bool? ?? true,
        );
      },
    ),
    // 스팟 등록 플로우(장소 검색 → 등록 폼 → 심사 대기)도 하단 탭 없는
    // 전체 화면 흐름이라 ShellRoute 바깥의 최상위 라우트로 둔다.
    GoRoute(
      path: '/map/register/search',
      builder: (c, s) => const SpotRegisterSearchScreen(),
    ),
    GoRoute(
      path: '/map/register/form',
      builder: (c, s) => SpotRegisterFormScreen(picked: s.extra as SpotSearchCandidate),
    ),
    GoRoute(
      path: '/map/register/pending',
      builder: (c, s) {
        final data = s.extra as Map<String, dynamic>;
        return SpotRegisterPendingScreen(
          name: data['name'] as String,
          address: data['address'] as String,
          categoryLabel: data['categoryLabel'] as String,
          exposureLabel: data['exposureLabel'] as String,
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
    // 골목지도 미리보기 화면의 "공유" 버튼에서 진입 — 코스를 피드에 공유하는 전용 작성 화면.
    GoRoute(
      path: '/feed/compose-route',
      builder: (c, s) {
        final data = s.extra as Map<String, dynamic>;
        return FeedRouteComposeScreen(
          routeName: data['name'] as String,
          stops: data['stops'] as List<MockSpot>,
          routeId: data['routeId'] as String?,
        );
      },
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
    // (구 /mypage/map "나의 지도"는 /mypage/routes "내가 만든 코스" 화면에
    // 지도 탭으로 통합되었다. my_map_screen.dart 파일 자체는 남겨두되 라우트는 제거.)
    GoRoute(
      path: '/mypage/posts',
      builder: (c, s) => MyPostsScreen(initialFilter: (s.extra as String?) ?? 'all'),
    ),
    GoRoute(
      path: '/mypage/saved',
      builder: (c, s) => MySavedScreen(initialFilter: (s.extra as String?) ?? 'spots'),
    ),
    GoRoute(
      path: '/mypage/routes',
      builder: (c, s) => const MyRoutesScreen(),
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
