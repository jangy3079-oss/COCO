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



/// 등록 폼의 카테고리 옵션. code는 기존 MockSpot.category 체계(노포/골목/공원/카페)에
/// "팝업"을 더한 저장용 값이고, label은 등록 폼에 보여줄 레퍼런스 원문 라벨이다.
class SpotRegisterCategory {
  final String code;
  final String label;
  final bool forcePeriod; // true면 노출 기간이 "기간 한정"으로 강제됨 (예: 팝업스토어)
  const SpotRegisterCategory({required this.code, required this.label, this.forcePeriod = false});
}

const spotRegisterCategories = [
  SpotRegisterCategory(code: '노포', label: '노포식당'),
  SpotRegisterCategory(code: '공원', label: '동네공원'),
  SpotRegisterCategory(code: '카페', label: '카페골목'),
  SpotRegisterCategory(code: '팝업', label: '팝업스토어', forcePeriod: true),
];
