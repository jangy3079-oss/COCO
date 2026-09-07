import 'package:flutter/material.dart';

// TODO: 백엔드(feed_posts/feed_comments/feed_post_likes 테이블) 연동 전까지의
// 목업 데이터. FeedItem은 좋아요/저장/댓글이 화면 조작에 따라 바뀌는 값이라
// (map_mock_data.dart의 MockSpot과 달리) 의도적으로 불변(immutable)이 아닌
// 일반 클래스로 만들었다. mockFeedItems는 피드 목록·상세·작성 화면이 함께
// 참조/수정하는 하나의 공유 리스트 — 실제 서버 연동 시 API 클라이언트가 이
// 자리를 대체한다.
enum FeedSource { coco, user }

/// 피드 카드 종류 — 스팟(단일 장소) 게시물인지 골목지도(코스) 게시물인지.
/// 전체/스팟/골목지도 필터가 이 값을 기준으로 나뉜다.
enum FeedPostType { spot, route }

class FeedComment {
  final String id;
  final String author;
  final String text;

  FeedComment({required this.id, required this.author, required this.text});

  String get authorInitial => author.isNotEmpty ? author.substring(0, 1) : '';
}

/// 동네(동) 필터 옵션. 레퍼런스의 필터 바텀시트("동네" 섹션)에서 쓰는
/// 칩 목록 — near가 true인 동네엔 위치 아이콘이 붙는다(현재 위치 기준 가까운 동네).
class FeedDongOption {
  final String id;
  final String label;
  final bool near;
  const FeedDongOption({required this.id, required this.label, this.near = false});
}

const feedDongOptions = [
  FeedDongOption(id: 'nampo', label: '남포동', near: true),
  FeedDongOption(id: 'gwangbok', label: '광복동'),
  FeedDongOption(id: 'yeongju', label: '영주동'),
  FeedDongOption(id: 'all', label: '전체 동네'),
];

String feedDongLabel(String id) =>
    feedDongOptions.firstWhere((d) => d.id == id, orElse: () => feedDongOptions.last).label;

/// 정렬 옵션 — 최신순 / 좋아요 많은 순 / 저장 많은 순 (레퍼런스 기준, 예전 "거리순"은 제외됨).
const feedSortLabels = {'latest': '최신순', 'likes': '좋아요 많은 순', 'saves': '저장 많은 순'};

class FeedItem {
  final String id;
  final FeedSource source; // my_posts_screen.dart("내가 쓴 글")에서 여전히 사용
  final String? author;
  final String category; // 노포 | 골목 | 공원 | 카페 — 상세 화면 배지용, 목록 카드엔 더는 안 씀
  final String place;
  final String title; // 카드 제목 (장소명과 별개의 한 줄 헤드라인)
  final String desc;
  final String neighborhood; // 구 단위 (상세 화면 표기용)
  final String dongId; // 동 단위 필터용 (feedDongOptions의 id)
  final int distanceMin;
  final int likes; // 기본 좋아요 수 (liked 토글과 별개)
  final int saves; // 기본 저장 수 (saved 토글과 별개)
  final int imgCount;
  final int ts; // 정렬용 타임스탬프(클수록 최신)
  final String timeLabel; // 카드에 표시할 상대 시간 텍스트 (예: 방금, 2시간 전)
  final FeedPostType type;
  final int? stopCount; // type == route 일 때만 사용 (골목지도 스팟 개수)

  bool liked;
  bool saved;
  int shares; // 공유 탭할 때마다 누적되는 카운트 (토글 아님)
  bool routeSaved; // type == route 게시물 상세의 "골목지도 저장" 전용 상태(카드의 saved와 별개)
  int imgIndex;
  final List<FeedComment> comments;

  FeedItem({
    required this.id,
    required this.source,
    this.author,
    required this.category,
    required this.place,
    this.title = '',
    required this.desc,
    required this.neighborhood,
    required this.dongId,
    required this.distanceMin,
    required this.likes,
    required this.saves,
    required this.imgCount,
    required this.ts,
    this.timeLabel = '방금',
    this.type = FeedPostType.spot,
    this.stopCount,
    this.liked = false,
    this.saved = false,
    this.shares = 0,
    this.routeSaved = false,
    this.imgIndex = 0,
    List<FeedComment>? comments,
  }) : comments = comments ?? [];

  int get likeCount => likes + (liked ? 1 : 0);
  int get saveCount => saves + (saved ? 1 : 0);
  String get dong => feedDongLabel(dongId);
  String get authorInitial => (author != null && author!.isNotEmpty) ? author!.substring(0, 1) : '';
  String get displayTitle => title.isNotEmpty ? title : place;
  double get distanceKm => (stopCount ?? 0) * 0.3;
  int get durationMin => (stopCount ?? 0) * 10;
}

Color categoryColor(String category) => switch (category) {
      '공원' => const Color(0xFF4C9A63),
      '노포' => const Color(0xFFE8604C),
      '카페' => const Color(0xFF9C7A4B),
      _ => const Color(0xFF1A1A1A),
    };

IconData categoryIcon(String category) => switch (category) {
      '공원' => Icons.park_rounded,
      '노포' => Icons.storefront_rounded,
      '골목' => Icons.signpost_rounded,
      '카페' => Icons.local_cafe_rounded,
      _ => Icons.place_rounded,
    };

/// 게시물 작성 화면의 "장소 태그" 검색에서 후보로 보여줄 장소명 목록.
const composerLocationCandidates = [
  '깡통시장',
  '젼골목',
  '영도다리공원',
  '흰여울문화마을',
  '보수동책방골목',
  '완월동 벽화골목',
  '할매순대국',
  '옥상카페',
];

final List<FeedItem> mockFeedItems = [
  FeedItem(
    id: 'r1',
    source: FeedSource.user,
    author: '해운',
    category: '골목',
    place: '중구 노포 골목 코스',
    title: '중구 노포 골목 코스 — 밤에 걷기 좋은 4곳',
    desc: '깡통시장부터 젼골목까지, 해 지고 나서 걷기 좋은 순서로 묶어봤어요.',
    neighborhood: '중구',
    dongId: 'nampo',
    distanceMin: 25,
    likes: 64,
    saves: 30,
    shares: 12,
    imgCount: 1,
    ts: 9,
    timeLabel: '2시간 전',
    type: FeedPostType.route,
    stopCount: 4,
  ),
  FeedItem(
    id: 'f1',
    source: FeedSource.coco,
    author: '하늘',
    category: '골목',
    place: '젼골목',
    title: '젼골목 인쇄소 뒷길, 3대째 이어온 간장집',
    desc: '인쇄소 골목 안쪽, 조부모 세대부터 이어온 간장집이 아직 남아있어요.',
    neighborhood: '중구',
    dongId: 'gwangbok',
    distanceMin: 6,
    likes: 342,
    saves: 210,
    shares: 58,
    imgCount: 2,
    ts: 8,
    timeLabel: '3시간 전',
    comments: [
      FeedComment(id: 'c1', author: '민지', text: '저도 다녀왔어요, 진짜 숨겨진 곳이네요!'),
      FeedComment(id: 'c2', author: '하늘', text: '간장 냄새가 아직도 기억나요'),
    ],
  ),
  FeedItem(
    id: 'f2',
    source: FeedSource.user,
    author: '민지',
    category: '노포',
    place: '할매순대국',
    title: '자정 넘어도 줄 서는 순대국집',
    desc: '자정 넘어서도 줄 서서 먹는 순대국집. 국물이 진짜 진해요.',
    neighborhood: '중구',
    dongId: 'nampo',
    distanceMin: 8,
    likes: 56,
    saves: 19,
    shares: 6,
    imgCount: 1,
    ts: 7,
    timeLabel: '10분 전',
    comments: [FeedComment(id: 'c3', author: '철수', text: '저녁에 가야 웨이팅 짧아요')],
  ),
  FeedItem(
    id: 'f3',
    source: FeedSource.coco,
    author: '준호',
    category: '공원',
    place: '영도다리공원',
    title: '해질녘 다리 조명 켜지는 순간',
    desc: '해질녘 다리 조명이 켜지는 시간이 제일 예뻐요.',
    neighborhood: '영도구',
    dongId: 'yeongju',
    distanceMin: 12,
    likes: 198,
    saves: 130,
    shares: 44,
    imgCount: 3,
    ts: 6,
    timeLabel: '5시간 전',
  ),
  FeedItem(
    id: 'f4',
    source: FeedSource.user,
    author: '철수',
    category: '카페',
    place: '옥상카페',
    title: '루프탑에서 보는 반전 야경',
    desc: '루프탑에서 보는 야경이 진짜 반전이에요.',
    neighborhood: '중구',
    dongId: 'nampo',
    distanceMin: 5,
    likes: 41,
    saves: 12,
    shares: 4,
    imgCount: 2,
    ts: 5,
    timeLabel: '6시간 전',
  ),
  FeedItem(
    id: 'f5',
    source: FeedSource.coco,
    author: '민지',
    category: '노포',
    place: '깡통시장',
    title: '깡통시장 새벽 5시, 상인들 아침 국밥',
    desc: '관광객 오기 전 시장이 제일 조용할 때예요. 국밥집 세 곳이 이 시간에만 열어요.',
    neighborhood: '중구',
    dongId: 'nampo',
    distanceMin: 4,
    likes: 42,
    saves: 12,
    shares: 9,
    imgCount: 2,
    ts: 10,
    timeLabel: '방금',
    comments: [
      FeedComment(id: 'c4', author: '하늘', text: '진짜 조용해서 좋아요'),
      FeedComment(id: 'c5', author: '준호', text: '다음에 새벽에 가봐야겠네요'),
    ],
  ),
  FeedItem(
    id: 'f6',
    source: FeedSource.user,
    author: '하늘',
    category: '골목',
    place: '보수동 책방골목',
    title: '헌책방 사이 숨은 사진 스팟',
    desc: '헌책방 사이사이 숨은 사진 스팟이 많아요.',
    neighborhood: '동구',
    dongId: 'gwangbok',
    distanceMin: 15,
    likes: 33,
    saves: 8,
    shares: 2,
    imgCount: 1,
    ts: 4,
    timeLabel: '어제',
  ),
  FeedItem(
    id: 'f7',
    source: FeedSource.user,
    author: '민지',
    category: '공원',
    place: '흰여울문화마을',
    title: '골목 사이로 보이는 바다 뷰',
    desc: '골목 사이로 보이는 바다 뷰가 그림 같아요.',
    neighborhood: '영도구',
    dongId: 'yeongju',
    distanceMin: 20,
    likes: 89,
    saves: 54,
    shares: 17,
    imgCount: 3,
    ts: 3,
    timeLabel: '어제',
  ),
  FeedItem(
    id: 'f8',
    source: FeedSource.coco,
    author: '철수',
    category: '카페',
    place: '흰여울 언덕 카페',
    title: '바다 보이는 창가 자리 노리기',
    desc: '바다가 보이는 창가 자리를 노려보세요.',
    neighborhood: '영도구',
    dongId: 'yeongju',
    distanceMin: 19,
    likes: 150,
    saves: 97,
    shares: 31,
    imgCount: 1,
    ts: 2,
    timeLabel: '2일 전',
  ),
  FeedItem(
    id: 'f9',
    source: FeedSource.user,
    author: '준호',
    category: '골목',
    place: '완월동 벽화골목',
    title: '노을 질 때 사진 잘 나오는 벽화골목',
    desc: '낮보다 노을 질 때가 사진이 훨씬 잘 나와요.',
    neighborhood: '서구',
    dongId: 'gwangbok',
    distanceMin: 11,
    likes: 22,
    saves: 5,
    shares: 1,
    imgCount: 2,
    ts: 1,
    timeLabel: '3일 전',
  ),
  // 골목지도(코스) 게시물 — 골목지도 탭의 랭킹 리스트를 채우기 위해 추가.
  // r1과 마찬가지로 mockFeedItems가 카드 피드/랭킹 리스트 공용 소스.
  FeedItem(
    id: 'r2',
    source: FeedSource.user,
    author: '민지',
    category: '골목',
    place: '영도 한바퀴 산책 코스',
    title: '영도 한바퀴 산책 코스',
    desc: '영도다리부터 흰여울문화마을까지 천천히 걷는 코스예요.',
    neighborhood: '영도구',
    dongId: 'yeongju',
    distanceMin: 30,
    likes: 97,
    saves: 52,
    shares: 21,
    imgCount: 1,
    ts: 0,
    timeLabel: '4일 전',
    type: FeedPostType.route,
    stopCount: 3,
  ),
  FeedItem(
    id: 'r3',
    source: FeedSource.user,
    author: '지우',
    category: '카페',
    place: '남포동 카페 3곳 골목투어',
    title: '남포동 카페 3곳 골목투어',
    desc: '커피 좋아하는 사람이라면 이 순서로 들러보세요.',
    neighborhood: '중구',
    dongId: 'nampo',
    distanceMin: 20,
    likes: 71,
    saves: 38,
    shares: 14,
    imgCount: 1,
    ts: -1,
    timeLabel: '5일 전',
    type: FeedPostType.route,
    stopCount: 3,
  ),
  FeedItem(
    id: 'r4',
    source: FeedSource.user,
    author: '해운',
    category: '노포',
    place: '아침 시장 코스',
    title: '아침 시장 코스',
    desc: '아침 일찍 문 여는 가게들만 골라 묶었어요.',
    neighborhood: '중구',
    dongId: 'gwangbok',
    distanceMin: 35,
    likes: 45,
    saves: 24,
    shares: 6,
    imgCount: 1,
    ts: -2,
    timeLabel: '6일 전',
    type: FeedPostType.route,
    stopCount: 5,
  ),
];
