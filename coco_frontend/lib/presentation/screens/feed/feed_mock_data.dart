import 'package:flutter/material.dart';
import '../map/map_mock_data.dart' show MockSpot;
import '../../../data/models/feed_post.dart';

// feed_posts 테이블은 실제 연동 완료(FeedRepository) — 이 파일은 이제 목업 데이터가
// 아니라 피드 화면들이 공유하는 FeedItem 모델 + 실제 백엔드 응답(FeedPost/
// FeedCommentDto)을 그 모델로 바꿔주는 변환 함수만 담고 있다. FeedItem은
// 좋아요/저장/댓글이 화면 조작에 따라 바뀌는 값이라 (map_mock_data.dart의 MockSpot과
// 달리) 의도적으로 불변(immutable)이 아닌 일반 클래스로 만들었다.
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
  final int? stopCount; // type == route 일 때만 사용 (코스에 담긴 스팟 개수)
  // type == route 게시물의 "골목지도 보기" → 코스 상세로 이동할 때 쓸 실제 스팟 목록.
  // routeId가 있으면(=내가 mockMyRoutes에 만든 코스를 공유한 경우) 코스 상세에서
  // 편집도 가능하고, 없으면(다른 사람이 올린 코스라는 뜻) 보기 전용이다.
  final List<MockSpot>? routeStops;
  final String? routeId;
  // 이 게시물이 태그한 스팟이 지금 인기(trending) 상태인지 — 피드 카드에 "인기" 배지를
  // 그리는 데 쓴다. 기존 목업 게시물은 전부 false, 실제 게시물만 feedItemFromPost에서
  // FeedPost.trending 값을 그대로 받아온다.
  final bool trending;
  // 실제 업로드된 사진의 상대경로(/uploads/...) — 목업 게시물은 항상 null이라 기존
  // 카테고리 색상 placeholder를 그대로 쓰고, 실제 게시물만 이 값이 있으면 진짜 사진을 그린다.
  final String? imageUrl;

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
    this.routeStops,
    this.routeId,
    this.trending = false,
    this.imageUrl,
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

  // id가 'real-{n}' 형태면 실제 백엔드 게시물이라는 뜻 — 좋아요/댓글을 실제 API로
  // 쏴야 할지(실제 게시물) 로컬에서만 토글할지(목업 시드 데이터) 이 값으로 구분한다.
  int? get realPostId => id.startsWith('real-') ? int.tryParse(id.substring(5)) : null;
}

/// 실제 백엔드 게시물(FeedPost)을 목업 기반 FeedItem 리스트에 합쳐서 보여주기 위한 변환.
/// 스팟의 동/구·카테고리 등 FeedPostResponse가 안 내려주는 값들은 아직 매칭할 방법이
/// 없어 임시값(dongId 'all', category '골목')으로 채운다 — 동네 필터에 안 걸리게 하려면
/// "전체 동네"를 선택해야 보인다는 뜻. ts는 실제 생성 시각(ms)을 그대로 써서 정렬 시
/// 항상 목업 시드 데이터보다 위(최신)로 올라오게 한다.
///
/// FeedItem.likeCount는 "likes(내가 안 눌렀을 때의 기준값) + (liked?1:0)"로 계산되는데,
/// 백엔드 likeCount는 이미 내 좋아요까지 포함된 총합이라 그대로 넣으면 liked=true일 때
/// 1 중복 계산된다. 그래서 이미 눌렀던 상태면 likes를 1 빼서 넣어 getter 계산이 맞게 한다.
FeedItem feedItemFromPost(FeedPost p) {
  return FeedItem(
    id: 'real-${p.id}',
    source: FeedSource.user,
    author: p.userNickname,
    category: '골목',
    place: p.spotName ?? '', // 스팟 태그 없이 쓴 글이면 빈 문자열 — 카드/상세에서 위치 배지 숨김
    desc: p.description ?? '',
    neighborhood: '',
    dongId: 'all',
    distanceMin: 0,
    likes: p.likeCount - (p.liked ? 1 : 0),
    saves: 0,
    imgCount: 1,
    ts: p.createdAt.millisecondsSinceEpoch,
    timeLabel: _relativeTimeLabel(p.createdAt),
    trending: p.trending,
    imageUrl: p.imageUrl,
    liked: p.liked,
    // 코스 공유로 만들어진 게시물이면(routeId 있음) 골목지도 카드로 표시한다.
    // routeStops는 여기서 채우지 않는다 — FeedPostResponse가 스팟 목록까지 안 내려줘서,
    // 실제 코스 상세는 상세 화면에서 routeId로 RouteRepository.getById를 불러 보여준다.
    type: p.routeId != null ? FeedPostType.route : FeedPostType.spot,
    routeId: p.routeId?.toString(),
  );
}

/// 실제 댓글(FeedCommentDto)을 상세 화면이 이미 쓰고 있는 로컬 FeedComment 모양으로 변환.
FeedComment feedCommentFromDto(FeedCommentDto c) =>
    FeedComment(id: 'real-${c.id}', author: c.userNickname, text: c.content);

String _relativeTimeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 2) return '어제';
  return '${diff.inDays}일 전';
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

