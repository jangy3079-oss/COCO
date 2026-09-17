import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/spot.dart' as db;
import '../../../data/repositories/spot_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/map/kakao_map_view.dart';
import 'map_mock_data.dart';

// 카테고리 필터의 내부 키(_categories/_selectedCategory, 백엔드 category 파라미터·
// spot.category 비교에 그대로 쓰임)는 한국어 문자열을 그대로 유지하고, 칩에 보여줄
// 라벨만 다국어로 바꾼다 — 필터링 로직/백엔드 쿼리 값은 건드리지 않기 위함.
String _categoryLabel(String category, AppLocalizations l10n) {
  switch (category) {
    case '전체':
      return l10n.mapCategoryAll;
    case '노포':
      return l10n.mapCategoryOldStore;
    case '골목':
      return l10n.mapCategoryAlley;
    case '공원':
      return l10n.mapCategoryPark;
    case '카페':
      return l10n.mapCategoryCafe;
    default:
      return category;
  }
}

// 하단 "주변 스팟" 시트의 스냅 지점(화면 높이 대비 비율) — 시트 자신과, 그 위에 떠
// 있는 플로팅 버튼(스팟등록/현재위치) 둘 다 이 값을 기준으로 위치를 맞춰야 하므로
// 파일 상단에 공유 상수로 뺐다.
const double kSheetCollapsedExtent = 0.09; // 아예 내리기 — 핸들+제목만 살짝 보임
const double kSheetMidExtent = 0.32; // 기본 상태
const double kSheetExpandedExtent = 0.92; // 아예 올리기 — 거의 전체화면

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 실제 스팟 category 값(spots.category: 노포|공원|카페|골목)에 맞춘 필터
  static const _categories = ['전체', '노포', '골목', '공원', '카페'];
  String _selectedCategory = '전체';

  // 지도 중심 좌표 — 진입 시 현재 위치로 재설정을 시도하고, 권한 거부/실패 시
  // mapDefaultCenterLat/Lng(부산 남포동)를 그대로 쓴다.
  double _centerLat = mapDefaultCenterLat;
  double _centerLng = mapDefaultCenterLng;
  // 실제 GPS 위치 — 카메라 중심(_centerLat/_centerLng)과 별개로 "내 위치" 파란 점
  // 표시에만 쓴다. 예전엔 이 둘을 같이 썼는데, 그러면 검색 등으로 카메라만 옮겨도
  // 파란 점이 실제로 있지도 않은 곳으로 같이 끌려가는 버그가 생겨서 분리했다.
  double? _myLat, _myLng;
  // GPS로 실제 위치를 구했을 때만 true — 지도 위 "내 위치" 파란 점은 이 값이
  // true일 때만 표시한다(기본 좌표로 조용히 폴백한 경우에는 점을 띄우지 않음).
  bool _locationAvailable = false;
  // 검색 결과 탭 등으로 특정 스팟에 확대+이동+말풍선을 한 번에 요청할 때 쓴다.
  // _openSearchResult에서 매번 새 인스턴스를 만들어 넣는다.
  MapFocusTarget? _focusTarget;

  // 지도 화면(뷰포트) 범위 — 드래그/줌이 끝날 때마다 갱신되며, 이 범위 안에 있는
  // 스팟만 지도/하단 시트에 표시한다(핀 밀집 방지). null이면 아직 한 번도 idle
  // 이벤트가 안 온 것이므로 전체를 보여준다. 실제 서버 연동 시에는 이 콜백에서
  // `/api/spot?swLat=...&neLat=...` 뷰포트 쿼리를 호출하도록 교체하면 된다.
  double? _swLat, _swLng, _neLat, _neLng;

  // 실제 DB(TourAPI/카카오 로컬로 수집된) 스팟 — 뷰포트가 바뀔 때마다 새로 조회한다.
  // 탭하면 spot_detail_screen이 db- 접두어를 보고 실제 데이터를 불러온다(mockSpotFromDb 어댑터).
  // 지도 마커뿐 아니라 하단 "주변 스팟" 시트(_nearbySheetSpots)도 이 값을 함께 참조한다.
  final _spotRepository = SpotRepository();
  List<db.Spot> _dbSpots = [];
  int _dbSpotsRequestSeq = 0; // 마지막으로 보낸 뷰포트 조회 순번 — 응답이 늦게 와도 최신 것만 반영하기 위함

  void _onBoundsChanged(double swLat, double swLng, double neLat, double neLng) {
    // 카카오맵 idle 이벤트가 (예: setCenter 직후) 동기적으로 곧바로 발생하면, 이 콜백이
    // Flutter의 build/didUpdateWidget 처리 도중에 재진입해서 "setState() called during
    // build" 예외가 난다 — 검색 결과 탭 시 지도 recenter는 되는데 핀이 안 갱신되던 원인.
    //
    // 처음엔 addPostFrameCallback으로 다음 프레임까지 미뤘는데, 이건 "다음 프레임이
    // 실제로 그려질 때"에만 실행된다 — 줌만 하고 화면을 더 안 건드리면 Flutter가
    // 새 프레임을 그릴 이유가 없어서(순수 카카오맵 쪽 네이티브 줌이라 Flutter 위젯
    // 트리엔 변화가 없음) 콜백이 계속 대기만 하다가, 나중에 아무 데나 터치해서
    // 프레임이 그려질 때야 뒤늦게 실행되는 버그가 있었다. Future.microtask는 Flutter의
    // 프레임 스케줄링과 무관하게 현재 실행 스택이 끝나자마자 실행되므로, build 도중
    // 재진입은 여전히 피하면서 줌만 해도 바로 반영된다.
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _swLat = swLat;
        _swLng = swLng;
        _neLat = neLat;
        _neLng = neLng;
      });
      _fetchDbSpots();
    });
  }

  Future<void> _fetchDbSpots() async {
    final swLat = _swLat, swLng = _swLng, neLat = _neLat, neLng = _neLng;
    if (swLat == null || swLng == null || neLat == null || neLng == null) return;
    // 지도가 빠르게 여러 번 움직이면(검색 결과 탭 → panTo 등) 이전 요청의 응답이
    // 나중에 도착할 수 있어, 그 순간의 요청 번호를 찍어두고 응답 시점에 비교한다.
    final requestSeq = ++_dbSpotsRequestSeq;
    // "골목"은 category 태그뿐 아니라 이름에 "골목"이 들어간 곳도 잡아야 해서, 서버에는
    // 카테고리 필터 없이 전체를 요청한 뒤 클라이언트에서 한 번 더 걸러낸다. 그 외
    // 카테고리는 지금처럼 서버 쪽 category 파라미터로 정확히 걸러진다.
    final isAlleyFilter = _selectedCategory == '골목';
    try {
      final spots = await _spotRepository.fetchSpotsInViewport(
        swLat: swLat,
        neLat: neLat,
        swLng: swLng,
        neLng: neLng,
        category: (_selectedCategory == '전체' || isAlleyFilter) ? null : _selectedCategory,
      );
      if (!mounted) return;
      // 그 사이 더 최신 요청이 나갔다면 이 응답은 오래된 뷰포트 것이므로 버린다.
      if (requestSeq != _dbSpotsRequestSeq) return;
      final filtered = isAlleyFilter
          ? spots.where((s) => s.category == '골목' || s.title.contains('골목')).toList()
          : spots;
      setState(() => _dbSpots = filtered);
      // 코스 저장 등 다른 화면에서도 id만으로 이 스팟들을 다시 찾을 수 있게 캐싱.
      for (final spot in spots) {
        dbSpotCache['db-${spot.id}'] = mockSpotFromDb(spot);
      }
    } catch (e) {
      debugPrint('[MapScreen] 실제 스팟 조회 실패: $e');
    }
  }

  // 하단 시트가 지금 화면의 몇 %를 차지하고 있는지 — Stack 전체를 setState로
  // 다시 그리지 않고 시트/버튼 위치만 가볍게 갱신하기 위해 ValueNotifier로 공유한다.
  final ValueNotifier<double> _sheetExtent = ValueNotifier(kSheetMidExtent);

  // 검색창 상태 — 목업 스팟은 즉시(클라이언트 필터), DB 스팟은 route_builder_screen의
  // "+ 스팟 추가"와 동일하게 300ms 디바운스 후 백엔드 검색(SpotRepository.search)으로 조회한다.
  // 뷰포트에 안 걸려도 결과가 나와야 해서(예: 지금 안 보이는 동네의 스팟 이름 검색)
  // 클라이언트 필터가 아니라 전체 DB 대상 검색 API를 그대로 재사용했다.
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  List<db.Spot> _searchDbResults = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _sheetExtent.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _searchDbResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _spotRepository.search(trimmed);
        if (!mounted) return;
        // 상세 화면으로 바로 진입할 수 있게 다른 화면들과 동일하게 미리 캐싱.
        for (final spot in results) {
          dbSpotCache['db-${spot.id}'] = mockSpotFromDb(spot);
        }
        setState(() => _searchDbResults = results);
      } catch (e) {
        debugPrint('[MapScreen] 스팟 검색 실패: $e');
      }
    });
  }

  // 목업 스팟은 API 호출 없이 이름/카테고리/주소로 즉시 필터링.
  List<MockSpot> get _searchMockResults {
    final q = _searchQuery.trim();
    if (q.isEmpty) return const [];
    return mockSpots
        .where((s) =>
            s.name.contains(q) || s.category.contains(q) || s.address.contains(q))
        .toList();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = '';
      _searchDbResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  // 검색 결과를 탭하면 그 스팟 쪽으로 살짝 확대 + 부드럽게 이동한 뒤, 핀을 직접
  // 탭했을 때와 같은 말풍선(뿅 애니메이션 포함)을 띄운다 — "자세히 보기"까지
  // 눌러야 상세로 이동하는 흐름은 핀 탭과 동일하게 유지.
  void _openSearchResult(MockSpot spot) {
    _clearSearch();
    setState(() {
      _focusTarget = MapFocusTarget(
        id: spot.id,
        lat: spot.lat,
        lng: spot.lng,
        name: spot.name,
        subtitle: _categoryLabel(spot.category, AppLocalizations.of(context)!),
      );
    });
  }

  // 검색창 드롭다운에 보여줄 결과 — 목업(즉시) + DB(디바운스) 결과를 합친다.
  List<MockSpot> get _searchResults => [
        ..._searchMockResults,
        ..._searchDbResults.map(mockSpotFromDb),
      ];

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _centerLat = position.latitude;
        _centerLng = position.longitude;
        _myLat = position.latitude;
        _myLng = position.longitude;
        _locationAvailable = true;
      });
    } catch (_) {
      // 위치 조회 실패 시 기본 좌표(부산 남포동) 유지 — 지도 자체는 정상 동작해야 하므로 조용히 무시.
    }
  }

  List<MockSpot> get _filteredSpots {
    // "골목"은 category 태그가 붙은 곳뿐 아니라, 이름에 "골목"이라는 단어가 들어간
    // 곳도 같이 잡는다 — 다른 카테고리는 태그만으로 정확히 걸러진다.
    final byCategory = _selectedCategory == '전체'
        ? mockSpots
        : _selectedCategory == '골목'
            ? mockSpots.where((s) => s.category == '골목' || s.name.contains('골목')).toList()
            : mockSpots.where((s) => s.category == _selectedCategory).toList();
    final swLat = _swLat, swLng = _swLng, neLat = _neLat, neLng = _neLng;
    if (swLat == null || swLng == null || neLat == null || neLng == null) {
      return byCategory;
    }
    return byCategory
        .where((s) => s.lat >= swLat && s.lat <= neLat && s.lng >= swLng && s.lng <= neLng)
        .toList();
  }

  // 하단 "주변 스팟" 시트용 — 지도 마커와 동일하게 목업 + 실제 DB 스팟을 합쳐서 보여준다.
  // (마커는 이미 _filteredSpots + _dbSpots를 합쳐서 그리고 있었는데, 시트만 목업만 보고 있던
  // 게 버그였음 — 데이터 소스는 같으니 마커 쪽과 동일하게 합친다.)
  List<MockSpot> get _nearbySheetSpots => [
        ..._filteredSpots,
        ..._dbSpots.map(mockSpotFromDb),
      ];

  // 찜(저장) 상태는 map_mock_data.dart의 공유 savedSpotIds를 그대로 사용한다
  // (스팟 상세 화면·MY탭과 동일한 상태를 공유해야 하므로 화면 로컬 State가 아님).
  void _toggleSaved(String spotId) {
    setState(() {
      if (savedSpotIds.contains(spotId)) {
        savedSpotIds.remove(spotId);
      } else {
        savedSpotIds.add(spotId);
      }
    });
  }

  void _openSpotDetail(MockSpot spot) {
    context.push('/map/spot/${spot.id}');
  }

  void _handleSaveCourse() {
    if (savedSpotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.mapSaveCourseEmptyWarning)),
      );
      return;
    }
    // 찜한 id 순서대로 목업/DB 스팟을 각자의 출처에서 찾아 합친다.
    // (DB 스팟은 dbSpotCache에서 — 지금 지도 화면에 안 보이는 곳이어도
    // 예전에 한 번이라도 불러온 적 있으면 여기서 찾을 수 있다.)
    final selectedStops = <MockSpot>[];
    for (final id in savedSpotIds) {
      if (id.startsWith('db-')) {
        final dbSpot = dbSpotCache[id];
        if (dbSpot != null) selectedStops.add(dbSpot);
      } else {
        for (final s in mockSpots) {
          if (s.id == id) {
            selectedStops.add(s);
            break;
          }
        }
      }
    }
    context.push('/map/route/new', extra: selectedStops);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: CocoTheme.surface,
      // 검색창 포커스로 키보드가 뜰 때 지도 레이아웃 전체가 눌려서 바텀시트가
      // 찌그러지는 걸 방지 (지도 화면은 키보드가 위에 떠 있는 형태가 자연스러움)
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 지도 영역 — 좌우/여백 없이 화면 전체를 채움
              Positioned.fill(
                child: KakaoMapView(
                  centerLat: _centerLat,
                  centerLng: _centerLng,
                  markers: [
                    for (final spot in _filteredSpots)
                      KakaoMapMarker(
                        id: spot.id,
                        lat: spot.lat,
                        lng: spot.lng,
                        name: spot.name,
                        subtitle: _categoryLabel(spot.category, l10n),
                      ),
                    // 실제 DB 스팟은 "db-" 접두어로 구분해서, 탭했을 때 목업 상세 화면이 아니라
                    // 별도 미리보기 시트로 보내준다 (mockSpotById가 실제 id를 못 찾아 터지는 것 방지).
                    for (final spot in _dbSpots)
                      KakaoMapMarker(
                        id: 'db-${spot.id}',
                        lat: spot.lat,
                        lng: spot.lng,
                        name: spot.title,
                        subtitle: _categoryLabel(spot.category, l10n),
                        isLocalPick: spot.isLocalPick,
                        trending: spot.trending,
                      ),
                  ],
                  onMarkerTap: (spotId) => spotId.startsWith('db-')
                      ? context.push('/map/spot/$spotId')
                      : _openSpotDetail(mockSpotById(spotId)),
                  myLocationLat: _locationAvailable ? _myLat : null,
                  myLocationLng: _locationAvailable ? _myLng : null,
                  onBoundsChanged: _onBoundsChanged,
                  focusTarget: _focusTarget,
                ),
              ),
              // 타이틀 + 검색창 + 카테고리 필터 (지도 위에 블러 그라데이션과 함께 떠 있는 형태.
              // 피드/커뮤니티 탭과 동일한 타이틀 스타일 적용)
              // ShaderMask(dstIn)로 블러 레이어 자체의 알파를 아래쪽으로 갈수록 서서히 줄여서,
              // 블러가 있다가 갑자기 뚝 끊기지 않고 점점 옅어지며 사라지도록 처리.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.68, 1.0],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.6, 1.0],
                            colors: [
                              Colors.white.withOpacity(0.96),
                              Colors.white.withOpacity(0.78),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.mapPageTitle,
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CocoTheme.secondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.mapPageSubtitle,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MapSearchBar(
                                        controller: _searchController,
                                        onChanged: _onSearchChanged,
                                        onClear: _clearSearch,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _MyRoutesButton(onTap: () => context.push('/mypage/routes')),
                                  ],
                                ),
                                // 검색어가 있을 때만 결과 드롭다운을 보여준다 — 목업은 즉시,
                                // DB는 300ms 디바운스 후 반영되므로 검색 도중 결과가 순간적으로
                                // 늘어나는 건 자연스러운 동작.
                                // 카카오맵(HtmlElementView)이 바로 아래 깔려 있어서, PointerInterceptor
                                // 없이는 탭 이벤트가 그 밑 실제 DOM(지도)으로 새어나가 "가끔씩만 동작"하는
                                // 문제가 생긴다 — 하단 시트(_NearbySpotsSheet)와 동일한 처리.
                                if (_searchQuery.trim().isNotEmpty)
                                  PointerInterceptor(
                                    child: _SearchResultsDropdown(
                                      results: _searchResults,
                                      onTap: _openSearchResult,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                _CategoryChipsRow(
                                  categories: _categories,
                                  selected: _selectedCategory,
                                  onSelected: (c) {
                                    setState(() => _selectedCategory = c);
                                    _fetchDbSpots(); // 카테고리는 뷰포트 변경이 아니라서 따로 다시 조회
                                  },
                                ),
                                // 블러가 서서히 사라질 여백(페이드 테일) — 이 구간에서
                                // ShaderMask 알파가 1→0으로 떨어지며 블러도 함께 옅어진다.
                                const SizedBox(height: 44),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 우측 하단 버튼 묶음 — 스팟 등록 + 현재 위치로 재중심을 같은 줄에 나란히 배치.
              // 시트를 내릴 때(_sheetExtent < kSheetMidExtent)는 같이 내려가지만,
              // 올릴 때는 기본 위치(kSheetMidExtent)에 고정되어 따라가지 않는다.
              // 상태 없이 매번 min()으로 계산하니 이전처럼 "멈춘 채 안 올라오는" 버그가
              // 생길 여지가 없다.
              ValueListenableBuilder<double>(
                valueListenable: _sheetExtent,
                builder: (context, extent, child) => Positioned(
                  left: 16,
                  right: 16,
                  bottom: constraints.maxHeight * (extent < kSheetMidExtent ? extent : kSheetMidExtent) + 16,
                  child: child!,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _RegisterSpotButton(onTap: () => context.push('/map/register/search')),
                    const SizedBox(width: 10),
                    _RecenterButton(onTap: _loadCurrentLocation),
                  ],
                ),
              ),
              // 하단 "주변 스팟" 바텀시트 (드래그로 확장 가능)
              _NearbySpotsSheet(
                extentNotifier: _sheetExtent,
                spots: _nearbySheetSpots,
                savedSpotIds: savedSpotIds,
                onToggleSaved: _toggleSaved,
                onSpotTap: _openSpotDetail,
                onSaveCourse: _handleSaveCourse,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 검색창 우측의 원형 버튼 — 탭하면 "내가 만든 코스" 화면(MY탭)으로 이동한다.
class _MyRoutesButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MyRoutesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context)!.mapMyRoutesTooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Color(0x0F000000))),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.route_outlined, color: CocoTheme.primary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _MapSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                  onPressed: onClear,
                ),
          hintText: AppLocalizations.of(context)!.mapSearchHint,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// 검색창 바로 아래 뜨는 결과 드롭다운 — 목업/DB 스팟을 가리지 않고 한 목록으로 보여준다.
class _SearchResultsDropdown extends StatelessWidget {
  final List<MockSpot> results;
  final ValueChanged<MockSpot> onTap;

  const _SearchResultsDropdown({required this.results, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // ListTile은 잉크 스플래시를 가장 가까운 Material 조상에 그리는데, 바로 위가
      // 배경색 있는 DecoratedBox(Container)라서 Material이 없다는 프레임워크 경고가
      // 떴었다 — Flutter가 안내한 대로 투명 Material로 감싸서 해결.
      child: Material(
        color: Colors.transparent,
        child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(AppLocalizations.of(context)!.mapSearchNoResults, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: results.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
              itemBuilder: (context, i) {
                final spot = results[i];
                return ListTile(
                  dense: true,
                  leading: Icon(spot.icon, color: spot.pinColor, size: 20),
                  title: Text(spot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(spot.address, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  onTap: () => onTap(spot),
                );
              },
            ),
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChipsRow({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in categories) ...[
            _CategoryChip(
              label: _categoryLabel(category, l10n),
              selected: category == selected,
              onTap: () => onSelected(category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? CocoTheme.primary : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : CocoTheme.secondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// 목업 지도 배경(건물/도로 블록 + 스팟 핀). 지도 탭 본문뿐 아니라
/// MY탭의 "내가 만든 코스" 화면(my_routes_screen.dart)의 지도 탭에서도 재사용한다.
class MockMapBackground extends StatelessWidget {
  final List<MockSpot> spots;
  final ValueChanged<MockSpot> onSpotTap;
  const MockMapBackground({super.key, required this.spots, required this.onSpotTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Container(
          color: const Color(0xFFE8E2D8),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 건물 블록
              _block(left: w * 0.05, top: h * 0.08, width: w * 0.22, height: h * 0.16, color: const Color(0xFFE0D5C8)),
              _block(left: w * 0.62, top: h * 0.06, width: w * 0.22, height: h * 0.12, color: const Color(0xFFE0D5C8)),
              _block(left: w * 0.05, top: h * 0.56, width: w * 0.22, height: h * 0.20, color: const Color(0xFFE0D5C8)),
              _block(left: w * 0.62, top: h * 0.62, width: w * 0.16, height: h * 0.14, color: const Color(0xFFE0D5C8)),
              // 공원 블록
              _block(left: w * 0.46, top: h * 0.30, width: w * 0.28, height: h * 0.22, color: const Color(0xFFA8C9A8)),
              // 강/수변 블록
              _block(left: w * 0.76, top: h * 0.78, width: w * 0.32, height: h * 0.32, color: const Color(0xFFB8D4E3)),
              // 도로 (세로)
              _road(left: w * 0.35, top: 0, width: 2, height: h),
              _road(left: w * 0.62, top: 0, width: 2, height: h),
              _road(left: w * 0.86, top: 0, width: 2, height: h),
              // 도로 (가로)
              _road(left: 0, top: h * 0.55, width: w, height: 2),
              // 동네 이름
              Positioned(left: w * 0.06, top: h * 0.40, child: _neighborhoodLabel('중구')),
              Positioned(left: w * 0.48, top: h * 0.66, child: _neighborhoodLabel('남포동')),
              // 스팟 핀
              for (final spot in spots)
                Positioned(
                  left: w * spot.left - 60,
                  top: h * spot.top,
                  width: 120,
                  child: _SpotPin(spot: spot, onTap: () => onSpotTap(spot)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _block({
    required double left,
    required double top,
    required double width,
    required double height,
    required Color color,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _road({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(color: Colors.white.withOpacity(0.85)),
    );
  }

  Widget _neighborhoodLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: CocoTheme.secondary.withOpacity(0.28),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SpotPin extends StatelessWidget {
  final MockSpot spot;
  final VoidCallback onTap;
  const _SpotPin({required this.spot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              spot.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CocoTheme.secondary),
            ),
          ),
          const SizedBox(height: 2),
          Icon(Icons.location_on, color: spot.pinColor, size: 30),
        ],
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.my_location_rounded, color: CocoTheme.primary, size: 20),
        ),
      ),
    );
  }
}

/// 지도 위 "스팟 등록" 플로팅 버튼 — 탭하면 장소 검색(스팟 등록 ①)으로 이동.
class _RegisterSpotButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterSpotButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CocoTheme.primary,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: CocoTheme.primary.withOpacity(0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context)!.mapRegisterSpotButton, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// DraggableScrollableSheet는 리스트 항목 수가 적어서 스크롤할 내용이 시트 안에
// 다 들어차지 않으면(=오버스크롤 여유가 없으면), 살짝 흔들리는 탭 제스처까지도
// "리사이즈 드래그"로 가로채 버려서 탭이 잘 안 먹는 문제가 있다(Flutter의 알려진 동작).
// 그래서 리사이즈 제스처는 핸들 영역에서만 받고, 리스트는 별도 스크롤뷰로 분리해서
// 탭이 항상 정상 동작하도록 직접 구현한다. 핸들을 드래그하면 완전히 접힘/기본/거의
// 전체화면 세 지점 중 가까운 곳으로 스냅된다.
class _NearbySpotsSheet extends StatefulWidget {
  final ValueNotifier<double> extentNotifier;
  final List<MockSpot> spots;
  final Set<String> savedSpotIds;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<MockSpot> onSpotTap;
  final VoidCallback onSaveCourse;

  const _NearbySpotsSheet({
    required this.extentNotifier,
    required this.spots,
    required this.savedSpotIds,
    required this.onToggleSaved,
    required this.onSpotTap,
    required this.onSaveCourse,
  });

  @override
  State<_NearbySpotsSheet> createState() => _NearbySpotsSheetState();
}

class _NearbySpotsSheetState extends State<_NearbySpotsSheet> {
  // 핸들+제목 줄만 있을 때 필요한 최소 높이(px) — 완전히 접힌 상태에서도 이 정도는
  // 있어야 오버플로우가 안 난다.
  static const double _headerMinPx = 74;
  // 리스트/버튼까지 같이 보이려면 필요한 최소 높이(px). 이보다 낮아지면 리스트/버튼을
  // 안 그려서, 줄어드는 도중에 고정 크기 위젯들이 공간을 못 찾아 오버플로우
  // 나는 걸 막는다. extent(비율) 기준이 아니라 실제 픽셀 기준으로 판단해야
  // 화면 크기가 달라도 항상 안전하다.
  static const double _bodyMinPx = 190;

  bool _dragging = false;

  void _snapToNearest(double current, double maxHeight) {
    final points = [_collapsedFloor(maxHeight), kSheetMidExtent, kSheetExpandedExtent];
    var nearest = points.first;
    var best = (points.first - current).abs();
    for (final p in points) {
      final d = (p - current).abs();
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    widget.extentNotifier.value = nearest;
    setState(() => _dragging = false);
  }

  // 화면이 아주 낮을 때(가로모드 등)는 0.09 비율만으로는 핸들 영역조차 다 못
  // 그릴 수 있어서, "핀 영역에 필요한 최소 픽셀"을 비율로 환산해 둘 중 더 큰
  // 쪽을 완전히 접힌 상태의 실제 하한으로 쓴다.
  double _collapsedFloor(double maxHeight) =>
      kSheetCollapsedExtent > _headerMinPx / maxHeight ? kSheetCollapsedExtent : _headerMinPx / maxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final collapsedFloor = _collapsedFloor(maxHeight);
        return ValueListenableBuilder<double>(
          valueListenable: widget.extentNotifier,
          builder: (context, extent, _) {
            final sheetHeight = maxHeight * extent;
            // 접힘 지점에 가까울 때는 리스트/버튼을 아예 안 그려서 좁은 공간에서
            // 내용이 눌리거나 넘치지 않게 한다(픽셀 기준이라 화면 크기와 무관하게 안전).
            final showBody = sheetHeight > _bodyMinPx;
            // 시트를 얼마나 올렸든(=지도가 얼마나 가려졌든) 목록 자체는 항상 전체
            // "주변 스팟"을 보여준다 — 시트를 올리는 건 목록을 더 많이/편하게 보려는
            // 동작인데, 예전엔 시트가 덮은 면적만큼 목록에서도 스팟을 빼버려서 오히려
            // 올릴수록 목록이 줄어드는 버그가 있었다.
            final visibleSpots = widget.spots;

            // Stack의 non-positioned 자식은 기본적으로 위쪽 정렬이라, 바닥에 붙는
            // 바텀시트처럼 보이려면 직접 Align(bottomCenter)로 감싸야 한다.
            return Align(
              alignment: Alignment.bottomCenter,
              // 시트 전체(핸들+리스트+버튼)를 PointerInterceptor로 감싸서, 드래그/탭
              // 제스처가 바로 아래 깔린 카카오맵(HtmlElementView)으로 새어나가 지도가
              // 같이 팬 되는 걸 막는다 — Flutter Web 플랫폼뷰 위에 겹친 위젯의 공식
              // 우회 방법(pointer_interceptor 패키지).
              child: PointerInterceptor(
                child: AnimatedContainer(
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: sheetHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16),
                  ],
                ),
                child: Column(
                  children: [
                    // 핸들 영역 — 리사이즈 드래그는 여기서만 받아서 아래 리스트의 탭 제스처와
                    // 서로 뺏어가지 않게 분리한다. 탭하면 기본↔거의 전체화면을 토글한다.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) => setState(() => _dragging = true),
                      onVerticalDragUpdate: (details) {
                        widget.extentNotifier.value = (widget.extentNotifier.value - details.delta.dy / maxHeight)
                            .clamp(collapsedFloor, kSheetExpandedExtent);
                      },
                      onVerticalDragEnd: (_) => _snapToNearest(widget.extentNotifier.value, maxHeight),
                      onTap: () => widget.extentNotifier.value =
                          extent >= kSheetExpandedExtent - 0.05 ? kSheetMidExtent : kSheetExpandedExtent,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.mapNearbySpotsTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                Text(l10n.mapNearbySpotsCount(visibleSpots.length),
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showBody) ...[
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: visibleSpots.length,
                          separatorBuilder: (_, __) => const Divider(height: 24),
                          itemBuilder: (context, i) => _SpotListTile(
                            spot: visibleSpots[i],
                            saved: widget.savedSpotIds.contains(visibleSpots[i].id),
                            onToggleSaved: () => widget.onToggleSaved(visibleSpots[i].id),
                            onTap: () => widget.onSpotTap(visibleSpots[i]),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: CocoTheme.primary,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: widget.onSaveCourse,
                          child: Text(l10n.mapSaveCourseButton),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SpotListTile extends StatelessWidget {
  final MockSpot spot;
  final bool saved;
  final VoidCallback onToggleSaved;
  final VoidCallback onTap;

  const _SpotListTile({
    required this.spot,
    required this.saved,
    required this.onToggleSaved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: spot.pinColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(spot.icon, color: spot.pinColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(spot.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggleSaved,
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            color: saved ? CocoTheme.primary : Colors.grey.shade500,
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_rounded),
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}
