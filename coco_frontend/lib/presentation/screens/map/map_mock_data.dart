import 'package:flutter/material.dart';

// TODO: 실제 지도 SDK(flutter_naver_map) + TourAPI 연동 전까지의 목업 데이터.
// 현재 flutter_naver_map은 jni/Gradle 툴체인 충돌로 pubspec에서 비활성화된 상태
// (pubspec.yaml 주석 참고). 연동되면 left/top(지도 영역 대비 상대 위치)은 실제
// 위경도 기반 좌표 변환으로, MockSpot 목업 리스트는 spots 테이블 조회 결과로 교체.
//
// 지도 탭(map_screen), 스팟 상세(spot_detail_screen), 골목지도 만들기
// (route_builder_screen), 골목지도 미리보기(route_preview_screen)가 이 파일의
// mockSpots를 공유해서 참조한다.
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
// 예전엔 각 화면이 자기만의 로컬 State로 들고 있어서 화면을 벗어나면
// 사라졌는데, MY탭에서 "찜한 스팟"을 보여주려면 공유 상태가 필요해서 승격함.
final Set<String> savedSpotIds = {'spot-1', 'spot-2', 'spot-4'};

/// 골목지도(코스). 지도 탭에서 "코스 저장하기"로 만든 코스가 여기 쌓이고,
/// 마이(MY) 탭의 "내가 만든 골목지도"/"저장한 코스"에서 보여준다.
/// TODO: 백엔드 연동 시 routes/route_stops 테이블 조회 결과로 교체 (신규 테이블 필요, MY_TAB_SPEC.md 참고).
class MockRoute {
  final String id;
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

final List<MockRoute> mockMyRoutes = [
  MockRoute(
    id: 'route-1',
    name: '겨울밤 노포 투어',
    stops: [mockSpotById('spot-1'), mockSpotById('spot-2'), mockSpotById('spot-3'), mockSpotById('spot-4')],
    isPublic: true,
    likes: 128,
    saves: 64,
    shares: 33,
  ),
  MockRoute(
    id: 'route-2',
    name: '영도 한바퀴 산책',
    stops: [mockSpotById('spot-4'), mockSpotById('spot-1'), mockSpotById('spot-2')],
  ),
  MockRoute(
    id: 'route-3',
    name: '아직 이름 없는 코스',
    stops: [mockSpotById('spot-5')],
    isDraft: true,
  ),
];

MockSpot mockSpotById(String id) => mockSpots.firstWhere((s) => s.id == id);

const mockSpots = [
  MockSpot(
    id: 'spot-1',
    name: '깡통시장',
    category: '노포',
    subtitle: '야시장 · 도보 4분',
    address: '부산 중구 부평2길 3',
    description: '부평시장의 밤 버전. 좁은 골목 사이로 야시장 포차가 늘어서 있고, '
        '몇십 년째 같은 자리를 지킨 노포들이 관광객보다 동네 사람들로 더 붐빈다.',
    dong: '남포동',
    left: 0.18,
    top: 0.30,
    lat: 35.1005,
    lng: 129.0296,
  ),
  MockSpot(
    id: 'spot-2',
    name: '젠골목',
    category: '골목',
    subtitle: '감성 골목 · 도보 6분',
    address: '부산 중구 젼골목',
    description: '국제시장 뒤편, 오래된 인쇄소와 작은 밥집이 늘어선 좁은 골목. '
        '동네 사람들은 아직도 할머니 때부터 다니던 같은 간장집에 들른다.',
    dong: '광복동',
    left: 0.55,
    top: 0.18,
    lat: 35.1013,
    lng: 129.0284,
  ),
  MockSpot(
    id: 'spot-3',
    name: '할머니 순대',
    category: '노포',
    subtitle: '노포 맛집 · 도보 3분',
    address: '부산 중구 남포동 5가',
    description: '자정이 넘어도 불이 꺼지지 않는 순대국밥집. 삼대째 같은 레시피로 '
        '끓여내는 국물이 이 동네 밤을 지켜온 맛이다.',
    dong: '남포동',
    left: 0.72,
    top: 0.28,
    lat: 35.0975,
    lng: 129.0305,
  ),
  MockSpot(
    id: 'spot-4',
    name: '영도다리공원',
    category: '공원',
    subtitle: '동네 공원 · 도보 8분',
    address: '부산 영도구 대교동',
    description: '영도다리가 한눈에 보이는 작은 수변 공원. 노을 질 때 다리 조명이 '
        '켜지는 순간을 보러 오는 동네 주민들의 산책 코스.',
    dong: '영도',
    left: 0.26,
    top: 0.48,
    lat: 35.0965,
    lng: 129.0349,
  ),
  MockSpot(
    id: 'spot-5',
    name: '옥상카페',
    category: '카페',
    subtitle: '로컬 카페 · 도보 5분',
    address: '부산 중구 광복로 15',
    description: '오래된 상가 건물 옥상에 자리한 작은 카페. 간판도 없지만 원도심 '
        '지붕들이 내려다보이는 뷰 때문에 로컬들 사이에서만 알려진 곳.',
    dong: '광복동',
    left: 0.40,
    top: 0.62,
    lat: 35.0995,
    lng: 129.0308,
  ),
];

/// 지도 초기 중심 좌표 — 목업 스팟들이 몰려 있는 부산 중구 남포동 일대.
const double mapDefaultCenterLat = 35.0995;
const double mapDefaultCenterLng = 129.0305;

/// 스팟 목록의 평균 좌표를 지도 중심으로 계산한다. 목록이 비어있으면 기본 중심을 반환.
(double, double) spotsCenter(List<MockSpot> spots) {
  if (spots.isEmpty) return (mapDefaultCenterLat, mapDefaultCenterLng);
  final lat = spots.map((s) => s.lat).reduce((a, b) => a + b) / spots.length;
  final lng = spots.map((s) => s.lng).reduce((a, b) => a + b) / spots.length;
  return (lat, lng);
}
