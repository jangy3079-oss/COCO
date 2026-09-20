// 스팟 등록 플로우(장소 검색 → 등록 폼 → 심사 대기) 전용 목업 데이터.
// TODO: 백엔드 연동 시 검색은 TourAPI/카카오 로컬 검색으로, 등록 신청은
// spots 테이블에 status='pending'으로 insert하는 API 호출로 교체.

/// 장소 검색 결과 후보.
class SpotSearchCandidate {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  const SpotSearchCandidate({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  /// GET /api/spot/search/external 응답 한 건을 변환한다. 백엔드가 아직 실제 DB row가
  /// 아닌 카카오 검색 결과를 그대로 주므로 id는 백엔드가 안 내려주고, 화면에서 목록
  /// 순서로 부여한다.
  factory SpotSearchCandidate.fromJson(Map<String, dynamic> json, {required String id}) =>
      SpotSearchCandidate(
        id: id,
        name: json['name'] as String,
        address: json['address'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

// searchExternal()로 실시간 카카오 로컬 검색이 연동됐으므로
// 하드코딩 더미 목록(spotRegisterCandidates)은 삭제. spot_register_search_screen.dart 참고.



/// 등록 폼의 카테고리 옵션. label은 등록 폼에 보여줄 레퍼런스 원문 라벨(노포식당/동네공원
/// 등 정감 있는 문구)이고, code는 실제로 저장되는 값이다.
///
/// code는 반드시 백엔드 SpotService.MAP_CATEGORIES(음식점/골목/공원/카페/명소/문화시설)
/// 중 하나여야 한다 — 지도 탭의 카테고리 칩(GET /api/spot/map?category=...)이 이 6개
/// 값으로만 정확히 일치 조회하기 때문에, 여기 안 속하는 값(예전엔 '노포'/'팝업')으로
/// 등록하면 스팟은 실제로 생성돼도 "전체" 탭 외 어떤 카테고리 필터에서도 안 보이는
/// "핀이 안 찍히는" 버그가 생긴다. (예전엔 MockSpot.category 체계인 노포/골목/공원/카페를
/// 그대로 썼는데, 그 체계와 백엔드 지도 필터 체계가 서로 다르다는 걸 놓쳤던 것.)
/// 6개를 전부 옵션으로 두는 게 안전하다 — 하나라도 빠지면 그 카테고리로는 유저가
/// 아예 등록을 못 하게 된다.
class SpotRegisterCategory {
  final String code;
  final String label;
  final bool forcePeriod; // true면 노출 기간이 "기간 한정"으로 강제됨
  const SpotRegisterCategory({required this.code, required this.label, this.forcePeriod = false});
}

const spotRegisterCategories = [
  SpotRegisterCategory(code: '음식점', label: '노포식당'),
  SpotRegisterCategory(code: '골목', label: '동네골목'),
  SpotRegisterCategory(code: '공원', label: '동네공원'),
  SpotRegisterCategory(code: '카페', label: '동네카페'),
  SpotRegisterCategory(code: '명소', label: '로컬명소'),
  SpotRegisterCategory(code: '문화시설', label: '문화공간'),
];
