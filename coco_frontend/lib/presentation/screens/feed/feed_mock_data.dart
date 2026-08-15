import 'package:flutter/material.dart';

// TODO: 백엔드(feed_posts/feed_comments/feed_post_likes 테이블) 연동 전까지의
// 목업 데이터. FeedItem은 좋아요/저장/댓글이 화면 조작에 따라 바뀌는 값이라
// (map_mock_data.dart의 MockSpot과 달리) 의도적으로 불변(immutable)이 아닌
// 일반 클래스로 만들었다. mockFeedItems는 피드 목록·상세·작성 화면이 함께
// 참조/수정하는 하나의 공유 리스트 — 실제 서버 연동 시 API 클라이언트가 이
// 자리를 대체한다.
enum FeedSource { coco, user }

class FeedComment {
  final String id;
  final String author;
  final String text;

  FeedComment({required this.id, required this.author, required this.text});

  String get authorInitial => author.isNotEmpty ? author.substring(0, 1) : '';
}

class FeedItem {
  final String id;
  final FeedSource source;
  final String? author; // source == user 일 때만 사용
  final String category; // 노포 | 골목 | 공원 | 카페
  final String place;
  final String desc;
  final String neighborhood;
  final int distanceMin;
  final int likes; // 기본 좋아요 수 (liked 토글과 별개)
  final int saves; // 기본 저장 수 (saved 토글과 별개)
  final int imgCount;
  final int ts; // 정렬용 타임스탬프(클수록 최신)

  bool liked;
  bool saved;
  int imgIndex;
  final List<FeedComment> comments;

  FeedItem({
    required this.id,
    required this.source,
    this.author,
    required this.category,
    required this.place,
    required this.desc,
    required this.neighborhood,
    required this.distanceMin,
    required this.likes,
    required this.saves,
    required this.imgCount,
    required this.ts,
    this.liked = false,
    this.saved = false,
    this.imgIndex = 0,
    List<FeedComment>? comments,
  }) : comments = comments ?? [];

  int get likeCount => likes + (liked ? 1 : 0);
  int get saveCount => saves + (saved ? 1 : 0);
  String get authorInitial => (author != null && author!.isNotEmpty) ? author!.substring(0, 1) : '';
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
    id: 'f1',
    source: FeedSource.coco,
    category: '골목',
    place: '젼골목',
    desc: '인쇄소 골목 안쪽, 조부모 세대부터 이어온 간장집이 아직 남아있어요.',
    neighborhood: '중구',
    distanceMin: 6,
    likes: 342,
    saves: 210,
    imgCount: 2,
    ts: 9,
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
    desc: '자정 넘어서도 줄 서서 먹는 순대국집. 국물이 진짜 진해요.',
    neighborhood: '중구',
    distanceMin: 8,
    likes: 56,
    saves: 19,
    imgCount: 1,
    ts: 8,
    comments: [FeedComment(id: 'c3', author: '철수', text: '저녁에 가야 웨이팅 짧아요')],
  ),
  FeedItem(
    id: 'f3',
    source: FeedSource.coco,
    category: '공원',
    place: '영도다리공원',
    desc: '해질녘 다리 조명이 켜지는 시간이 제일 예뻐요.',
    neighborhood: '영도구',
    distanceMin: 12,
    likes: 198,
    saves: 130,
    imgCount: 3,
    ts: 7,
  ),
  FeedItem(
    id: 'f4',
    source: FeedSource.user,
    author: '철수',
    category: '카페',
    place: '옥상카페',
    desc: '루프탑에서 보는 야경이 진짜 반전이에요.',
    neighborhood: '중구',
    distanceMin: 5,
    likes: 41,
    saves: 12,
    imgCount: 2,
    ts: 6,
  ),
  FeedItem(
    id: 'f5',
    source: FeedSource.coco,
    category: '노포',
    place: '깡통시장',
    desc: '저녁이면 포장마차가 하나둘 켜지는 야시장이에요.',
    neighborhood: '중구',
    distanceMin: 4,
    likes: 275,
    saves: 190,
    imgCount: 2,
    ts: 5,
  ),
  FeedItem(
    id: 'f6',
    source: FeedSource.user,
    author: '하늘',
    category: '골목',
    place: '보수동 책방골목',
    desc: '헌책방 사이사이 숨은 사진 스팟이 많아요.',
    neighborhood: '동구',
    distanceMin: 15,
    likes: 33,
    saves: 8,
    imgCount: 1,
    ts: 4,
  ),
  FeedItem(
    id: 'f7',
    source: FeedSource.user,
    author: '민지',
    category: '공원',
    place: '흰여울문화마을',
    desc: '골목 사이로 보이는 바다 뷰가 그림 같아요.',
    neighborhood: '영도구',
    distanceMin: 20,
    likes: 89,
    saves: 54,
    imgCount: 3,
    ts: 3,
  ),
  FeedItem(
    id: 'f8',
    source: FeedSource.coco,
    category: '카페',
    place: '흰여울 언덕 카페',
    desc: '바다가 보이는 창가 자리를 노려보세요.',
    neighborhood: '영도구',
    distanceMin: 19,
    likes: 150,
    saves: 97,
    imgCount: 1,
    ts: 2,
  ),
  FeedItem(
    id: 'f9',
    source: FeedSource.user,
    author: '준호',
    category: '골목',
    place: '완월동 벽화골목',
    desc: '낮보다 노을 질 때가 사진이 훨씬 잘 나와요.',
    neighborhood: '서구',
    distanceMin: 11,
    likes: 22,
    saves: 5,
    imgCount: 2,
    ts: 1,
  ),
];
