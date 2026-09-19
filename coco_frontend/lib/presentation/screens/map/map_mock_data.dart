import 'package:flutter/material.dart';
import '../../../data/models/route.dart';
import '../../../data/models/spot.dart' as db;
import '../../../data/repositories/route_repository.dart';
import '../../../data/repositories/spot_repository.dart';

// TODO: 실제 지도 SDK(flutter_naver_map) 연동 전까지는 KakaoMapView 대신 이 파일의
// left/top(지도 영역 대비 상대 위치, MockMapBackground 캔버스 전용)로 그리는 화면이
// 남아있다. 현재 flutter_naver_map은 jni/Gradle 툴체인 충돌로 pubspec에서 비활성화된
// 상태(pubspec.yaml 주석 참고).
//
// MockSpot 자체는 더 이상 목업이 아니라, 스팟 상세/코스 만들기/코스 미리보기 등
// 여러 화면이 공유하는 스팟 모양(shape)이다 — 실제 DB 스팟은 mockSpotFromDb로
// 이 모양에 맞춰 변환해서 쓴다.
class MockSpot {
  final String id;
  final String name;
  final String category; // 노포 | 골목 | 공원 | 카페
  final String subtitle;
  final String address;
  final String description;
  final String dong; // 동네 이름 — "내가 만든 골목지도" 등 코스 목록에서 스팟 옆에 짧게 보여줌
  final double left; // 지도 영역 대비 상대 위치 (0~1) — MockMapBackground(목업 캔버스) 전용
  final double top;
  final double lat; // 실제 위경도 — KakaoMapView(실제 지도) 전용
  final double lng;
  // 코스를 피드에 공유할 때(feed_route_compose_screen) 대표 스팟의 사진을 게시물
  // 사진으로 쓴다 — 사진이 없는 스팟(카카오 로컬 소스 등)은 빈 문자열.
  final String imageUrl;

  const MockSpot({
    required this.id,
    required this.name,
    required this.category,
    required this.subtitle,
    required this.address,
    required this.description,
    required this.dong,
    required this.left,
    required this.top,
    required this.lat,
    required this.lng,
    this.imageUrl = '',
  });

  Color get pinColor => switch (category) {
        '공원' => const Color(0xFF4C9A63),
        '노포' => const Color(0xFFE8604C),
        _ => const Color(0xFF1A1A1A),
      };

  IconData get icon => switch (category) {
        '공원' => Icons.park_rounded,
        '노포' => Icons.storefront_rounded,
        '골목' => Icons.signpost_rounded,
        '카페' => Icons.local_cafe_rounded,
        _ => Icons.place_rounded,
      };
}

// 스팟 찜(저장) 상태 — 지도 탭(주변 스팟 목록 북마크)과 스팟 상세 화면,
// 마이(MY) 탭(나의 지도·저장한 스팟 목록)이 함께 참조하는 공유 상태.
// PART 1(찜 실API 연동)부터는 실제 백엔드(GET/POST /api/spot/{id}/like)와 동기화되는
// 정수 id 집합이다(dbSpotNumericId로 'db-{id}' 문자열에서 뽑아낸 값).
final Set<int> likedSpotIds = {};
final _likeSpotRepository = SpotRepository();

/// 'db-{id}'에서 실제 백엔드 정수 id를 뽑는다. 데모 스팟이면 null(=찜 불가 판정에도 쓰임).
int? dbSpotNumericId(String spotId) =>
    spotId.startsWith('db-') ? int.tryParse(spotId.substring(3)) : null;

/// spotId(MockSpot.id, 문자열)가 지금 찜한 상태인지 — 화면들이 하트/북마크 아이콘을
/// 채울지 판단할 때 쓴다. 데모 스팟은 항상 false(찜 개념이 없음).
bool isSpotSaved(String spotId) {
  final numId = dbSpotNumericId(spotId);
  return numId != null && likedSpotIds.contains(numId);
}

/// GET /api/spot/liked로 실제 찜 목록을 가져와 likedSpotIds + dbSpotCache를 채운다.
/// 마이탭 진입 시/지도 탭 진입 시 한 번씩 호출한다. 로그인 안 된 상태(401)면 조용히
/// 무시 — 화면들은 그냥 "찜한 스팟 없음"으로 보인다.
Future<void> refreshLikedSpots({String locale = 'ko'}) async {
  try {
    final spots = await _likeSpotRepository.fetchLikedSpots(locale: locale);
    likedSpotIds
      ..clear()
      ..addAll(spots.map((s) => s.id));
    for (final s in spots) {
      dbSpotCache['db-${s.id}'] = mockSpotFromDb(s);
    }
  } catch (e) {
    debugPrint('[map_mock_data] 찜 목록 조회 실패: $e');
  }
}

/// 찜 토글 실제 API 호출 — 성공하면 likedSpotIds도 함께 갱신한다. 호출부가 먼저
/// 낙관적으로 UI를 바꾸고, 실패하면 되돌리는 방식을 쓰므로 여기선 에러를 그대로 던진다.
/// (데모 스팟은 호출부에서 dbSpotNumericId가 null인지로 미리 걸러야 함 — 여기선 가정하지 않음.)
Future<bool> toggleSpotLike(int numId) async {
  final result = await _likeSpotRepository.toggleLike(numId);
  if (result.liked) {
    likedSpotIds.add(numId);
  } else {
    likedSpotIds.remove(numId);
  }
  return result.liked;
}

/// 골목지도(코스). 지도 탭에서 "코스 저장하기"로 만든 코스가 여기 쌓이고,
/// 마이(MY) 탭의 "내가 만든 골목지도"/"저장한 코스"에서 보여준다.
/// PART 2(코스 실API 연동)부터는 mockRouteFromApi가 실제 백엔드(RouteMap)를 이 모양으로
/// 바꿔 채운다 — 화면들(route_builder/route_preview/my_routes 등)이 전부 MockRoute 하나의
/// 모양을 기준으로 짜여 있어서, PART 1의 MockSpot/mockSpotFromDb와 동일한 전략을 썼다.
class MockRoute {
  final String id; // 'route-{백엔드 id}'
  final String name;
  final List<MockSpot> stops;
  final bool isPublic; // true: 전체 공유, false: 나만 보기
  final bool isDraft; // true: 스팟만 담고 아직 완성하지 않은 "작성 중" 코스
  final int likes;
  final int saves;
  final int shares;

  MockRoute({
    required this.id,
    required this.name,
    required this.stops,
    this.isPublic = false,
    this.isDraft = false,
    this.likes = 0,
    this.saves = 0,
    this.shares = 0,
  });

  double get distanceKm => stops.length * 0.3;
}

/// 'route-{id}'에서 실제 백엔드 정수 id를 뽑는다.
int? dbRouteNumericId(String routeId) =>
    routeId.startsWith('route-') ? int.tryParse(routeId.substring(6)) : null;

final _routeRepository = RouteRepository();

/// 코스의 스팟(RouteMapSpot)을 MockSpot으로 변환한다. 이미 dbSpotCache에 있으면
/// (찜한 스팟이라 이미 본 적 있는 경우가 대부분) 그대로 쓰고, 없으면 백엔드가 주는
/// 최소 필드(제목/좌표)만으로 채운다.
MockSpot mockSpotFromRouteStop(RouteMapSpot stop) {
  final cached = dbSpotCache['db-${stop.spotId}'];
  if (cached != null) return cached;
  return MockSpot(
    id: 'db-${stop.spotId}',
    name: stop.title,
    category: '',
    subtitle: '',
    address: '',
    description: '',
    dong: '',
    left: _clamp01((stop.lng - _dbLngMin) / (_dbLngMax - _dbLngMin)),
    top: _clamp01((_dbLatMax - stop.lat) / (_dbLatMax - _dbLatMin)),
    lat: stop.lat,
    lng: stop.lng,
    imageUrl: stop.imageUrl ?? '',
  );
}

MockRoute mockRouteFromApi(RouteMap r) => MockRoute(
      id: 'route-${r.id}',
      name: r.name,
      stops: r.spots.map(mockSpotFromRouteStop).toList(),
      isPublic: r.visibility == 'PUBLIC',
      isDraft: r.isDraft,
      likes: r.likeCount,
      saves: r.saveCount,
      shares: r.shareCount,
    );

/// 내가 만든 코스 목록 — MY탭 "내가 만든 코스"가 참조하는 공유 상태.
final List<MockRoute> mockMyRoutes = [];

/// GET /api/routes/mine으로 내가 만든 코스 목록을 가져와 mockMyRoutes를 채운다.
/// 로그인 안 된 상태(401)면 조용히 무시.
Future<void> refreshMyRoutes() async {
  try {
    final routes = await _routeRepository.listMine();
    mockMyRoutes
      ..clear()
      ..addAll(routes.map(mockRouteFromApi));
  } catch (e) {
    debugPrint('[map_mock_data] 내 코스 목록 조회 실패: $e');
  }
}

/// 저장(북마크)한 코스 캐시 — 백엔드에 "내가 저장한 코스 전체 목록"을 한 번에 조회하는
/// API가 없다(좋아요/저장 여부는 코스 상세(getById) 응답에만 로그인 유저 기준으로 담겨
/// 온다). 그래서 코스 상세를 열거나(route_preview_screen) 저장을 토글할 때마다 여기
/// 채워 넣는 세션 한정 캐시로 대신한다 — 이번 세션에서 한 번도 열어보거나 저장하지
/// 않은 코스는 앱을 새로 켜기 전까진 MY탭 "저장한 코스"에 안 잡힌다.
final Map<int, RouteMap> savedRouteCache = {};

List<MockRoute> get savedRoutes => savedRouteCache.values.map(mockRouteFromApi).toList();

/// 코스 저장 토글 실제 API 호출 — 성공하면 savedRouteCache도 함께 갱신한다.
Future<({bool saved, int saveCount})> toggleRouteSave(int numId) async {
  final result = await _routeRepository.toggleSave(numId);
  if (result.saved) {
    try {
      savedRouteCache[numId] = await _routeRepository.getById(numId);
    } catch (e) {
      savedRouteCache.remove(numId);
      debugPrint('[map_mock_data] 저장한 코스 캐시 갱신 실패: $e');
    }
  } else {
    savedRouteCache.remove(numId);
  }
  return result;
}

// Busan 원도심(중구/동구) 대략적인 좌표 범위 — 실제 스팟들이 몰려있는 구간을 0~1로
// 정규화해서 _RouteMiniMap 같은 목업 캔버스 위에 위치를 잡아줄 때 쓴다(장식용이라
// 정밀할 필요는 없음).
const double _dbLatMin = 35.090, _dbLatMax = 35.110;
const double _dbLngMin = 129.020, _dbLngMax = 129.045;

double _clamp01(double v) => v < 0.05 ? 0.05 : (v > 0.95 ? 0.95 : v);

/// 실제 DB 스팟(db.Spot)을 화면들이 공유하는 MockSpot 모양으로 바꿔준다.
/// 스팟 상세/코스 만들기/코스 미리보기가 전부 MockSpot 하나의 모양을 기준으로 짜여
/// 있어서, 이 화면들을 전부 새로 쓰는 대신 실제 데이터를 이 모양에 맞춰 넣는 쪽을
/// 택했다. id 앞에 "db-"를 붙여서 순수 숫자 id와 구분한다(dbSpotNumericId가 그
/// 접두어를 보고 실제 백엔드 정수 id를 뽑아낸다).
/// (설명/부제/동네 이름처럼 백엔드가 아직 안 주는 필드는 최소한의 문구로 채운다.)
MockSpot mockSpotFromDb(db.Spot spot) {
  return MockSpot(
    id: 'db-${spot.id}',
    name: spot.title,
    category: spot.category,
    subtitle: spot.category,
    address: spot.address,
    // TourAPI 소스는 실제 소개글(overview)이 있지만, 카카오 로컬 소스는 API 자체에
    // 소개글 필드가 없어 null로 온다 — 그 경우만 안내 문구로 대체한다.
    description: spot.description?.trim().isNotEmpty == true
        ? spot.description!
        : '아직 등록된 소개글이 없어요.',
    dong: '',
    left: _clamp01((spot.lng - _dbLngMin) / (_dbLngMax - _dbLngMin)),
    top: _clamp01((_dbLatMax - spot.lat) / (_dbLatMax - _dbLatMin)), // 위도가 높을수록(북쪽) top은 작아짐
    lat: spot.lat,
    lng: spot.lng,
    imageUrl: spot.imageUrl,
  );
}

/// 한 번 변환한 DB 스팟을 캐싱해두는 공유 저장소. 코스 저장하기처럼 "지금 화면에
/// 없는 DB 스팟"도 id만으로 다시 찾아야 하는 경우가 있어서, 지도 탭/스팟 상세
/// 화면이 DB 스팟을 불러올 때마다 여기 채워 넣는다(진짜 재조회 없이 가벼운 메모리
/// 캐시로 충분 — 앱 재시작 전까지만 유지돼도 됨).
final Map<String, MockSpot> dbSpotCache = {};

/// 지금까지 찜한 스팟 전체(likedSpotIds를 dbSpotCache에서 찾아 펼친 것) — "나의
/// 골목지도"(MY탭)와 "코스 만들기"의 "+ 스팟 추가"(찜한 스팟 중에서만 고르게)가
/// 함께 쓰는 단일 소스. refreshLikedSpots가 dbSpotCache도 같이 채워주므로 보통
/// 여기서 못 찾는 경우는 없다.
List<MockSpot> get savedSpots =>
    likedSpotIds.map((id) => dbSpotCache['db-$id']).whereType<MockSpot>().toList();

/// 지도 초기 중심 좌표 — 부산 중구 남포동 일대(실제 스팟이 몰려 있는 원도심 구간).
const double mapDefaultCenterLat = 35.0995;
const double mapDefaultCenterLng = 129.0305;

/// 스팟 목록의 평균 좌표를 지도 중심으로 계산한다. 목록이 비어있으면 기본 중심을 반환.
(double, double) spotsCenter(List<MockSpot> spots) {
  if (spots.isEmpty) return (mapDefaultCenterLat, mapDefaultCenterLng);
  final lat = spots.map((s) => s.lat).reduce((a, b) => a + b) / spots.length;
  final lng = spots.map((s) => s.lng).reduce((a, b) => a + b) / spots.length;
  return (lat, lng);
}

/// 코스 상세("지도에서 보기")에서 지도 탭으로 넘어갈 때, 지도 탭에 그 코스의
/// 스팟만 보여달라는 요청을 담아 전달하는 공유 상태.
///
/// MapScreen은 bottom_nav_shell.dart에서 static으로 딱 한 번만 만들어져 탭을
/// 옮겨 다녀도 계속 살아있는 구조라(카카오맵 재초기화 방지), go_router의
/// extra 파라미터로는 값을 전달할 통로가 없다 — 그래서 다른 화면(찜 상태 등)과
/// 동일하게 공유 상태로 승격하되, MapScreen이 안 보이는 동안에도 값이 바뀐 걸
/// 알아채야 해서 ValueNotifier로 만들어 리스너로 반영한다.
class CourseMapFilter {
  final String routeName;
  final List<MockSpot> spots;
  const CourseMapFilter({required this.routeName, required this.spots});
}

final ValueNotifier<CourseMapFilter?> courseMapFilter = ValueNotifier(null);
