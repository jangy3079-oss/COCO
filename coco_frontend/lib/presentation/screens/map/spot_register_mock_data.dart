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
}

const spotRegisterCandidates = [
  SpotSearchCandidate(id: 'reg-1', name: '젼골목', address: '부산 중구 젼길 12', lat: 35.1005, lng: 129.0296),
  SpotSearchCandidate(id: 'reg-2', name: '젼골목 인쇄소거리', address: '부산 중구 젼길 20-3', lat: 35.1013, lng: 129.0284),
  SpotSearchCandidate(id: 'reg-3', name: '젼골목 팝업 스페이스', address: '부산 중구 젼길 8, 2층', lat: 35.0999, lng: 129.0301),
  SpotSearchCandidate(id: 'reg-4', name: '영주동 계단길', address: '부산 중구 영주동 산복도로', lat: 35.0975, lng: 129.0305),
  SpotSearchCandidate(id: 'reg-5', name: '깡통시장', address: '부산 중구 부평1길 48', lat: 35.0995, lng: 129.0308),
];

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
