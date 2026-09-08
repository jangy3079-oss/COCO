import '../../../data/models/user_type.dart';
import '../map/map_mock_data.dart';

// TODO: 백엔드(qna_posts/qna_answers 테이블, COMMUNITY_QNA_SPEC.md 참고) 연동
// 전까지의 목업 데이터. FeedItem과 마찬가지로 답변/채택이 화면 조작으로 바뀌므로
// 의도적으로 mutable 클래스 + top-level mutable 공유 리스트로 구성.

class QnaAnswer {
  final String id;
  final String author;
  final bool isLocal; // 답변자가 로컬 주민인지 (배지 표시용)
  final String content;
  final String timeLabel;

  QnaAnswer({
    required this.id,
    required this.author,
    required this.isLocal,
    required this.content,
    required this.timeLabel,
  });

  String get authorInitial => author.isNotEmpty ? author.substring(0, 1) : '';
}

class QnaPost {
  final String id;
  final UserType authorRole; // 질문 작성자 유형 (로컬/관광객 배지)
  final String title;
  final String content;
  final String? spotName; // mockSpots.name과 매칭되면 "지도에서 보기" 연결
  final String timeLabel;
  final int ts; // 정렬용
  final bool mine; // 지금 로그인한 "나"가 쓴 질문인지 (내 질문 필터 + 채택 권한 데모용)

  String? adoptedAnswerId;
  final List<QnaAnswer> answers;

  QnaPost({
    required this.id,
    required this.authorRole,
    required this.title,
    required this.content,
    this.spotName,
    required this.timeLabel,
    required this.ts,
    this.mine = false,
    this.adoptedAnswerId,
    List<QnaAnswer>? answers,
  }) : answers = answers ?? [];

  bool get solved => adoptedAnswerId != null;

  /// spotName과 이름이 같은 지도 탭 스팟 (있으면 상세에서 "지도에서 보기" 딥링크 가능)
  MockSpot? get taggedSpot {
    if (spotName == null) return null;
    for (final s in mockSpots) {
      if (s.name == spotName) return s;
    }
    return null;
  }
}

final List<QnaPost> qnaMockPosts = [
  QnaPost(
    id: 'q1',
    authorRole: UserType.tourist,
    title: '깡통시장 근처에 아침 일찍 여는 노포 있나요?',
    content: '아침 7시쯤 도착하는데 그 시간에 문 여는 데가 있을지 궁금해요. 관광객용 말고 동네분들 가시는 곳이면 더 좋아요.',
    spotName: '깡통시장',
    timeLabel: '12분 전',
    ts: 5,
    answers: [
      QnaAnswer(
        id: 'a1',
        author: '민지',
        isLocal: true,
        timeLabel: '8분 전',
        content: '깡통시장 남쪽 입구 쪽 국밥집들이 6시부터 열어요. 시장 상인분들이 아침 드시러 가는 곳이라 그 시간에도 사람 많습니다.',
      ),
      QnaAnswer(
        id: 'a2',
        author: 'Kenji',
        isLocal: false,
        timeLabel: '5분 전',
        content: '저는 7시 반쯤 갔는데 시장 안쪽은 아직 닫혀있었고 바깥쪽 국밥집만 열려있었어요.',
      ),
      QnaAnswer(
        id: 'a3',
        author: '해운',
        isLocal: true,
        timeLabel: '2분 전',
        content: '시장 안쪽은 9시부터라고 보시면 되고, 아침은 바깥 골목 쪽이 답입니다.',
      ),
    ],
  ),
  QnaPost(
    id: 'q2',
    authorRole: UserType.tourist,
    title: '영도 골목 야경 사진 찍기 좋은 시간대는?',
    content: '해질녘에 가려는데 몇 시쯤이 제일 예쁜지 알려주세요.',
    spotName: '영도다리공원',
    timeLabel: '1시간 전',
    ts: 4,
    adoptedAnswerId: 'a4',
    answers: [
      QnaAnswer(
        id: 'a4',
        author: '하늘',
        isLocal: true,
        timeLabel: '40분 전',
        content: '해 진 후 20분 정도 지나서 가로등이랑 다리 조명이 같이 켜질 때가 제일 예뻐요. 요즘은 7시 반~8시쯤이에요.',
      ),
    ],
  ),
  QnaPost(
    id: 'q3',
    authorRole: UserType.tourist,
    title: '남포동에서 현금만 받는 가게 많나요?',
    content: '카드 안 되는 곳이 많다고 들었는데 어느 정도인지 궁금합니다.',
    timeLabel: '3시간 전',
    ts: 3,
    adoptedAnswerId: 'a5',
    answers: [
      QnaAnswer(
        id: 'a5',
        author: '철수',
        isLocal: true,
        timeLabel: '2시간 전',
        content: '요즘은 카드 되는 곳이 많아졌는데 오래된 노포 몇 곳은 아직 현금만 받아요. 소액은 현금 좀 챙겨가시는 게 편해요.',
      ),
    ],
  ),
  QnaPost(
    id: 'q4',
    authorRole: UserType.local,
    title: '비 오는 날 갈 만한 조용한 동네 카페 추천',
    content: '관광지 말고 주민들이 자주 가는 곳으로요.',
    timeLabel: '어제',
    ts: 2,
    mine: true,
    answers: [
      QnaAnswer(
        id: 'a6',
        author: '민지',
        isLocal: true,
        timeLabel: '어제',
        content: '옥상카페요, 평일 오후엔 사람 별로 없어서 책 읽기 좋아요.',
      ),
      QnaAnswer(
        id: 'a7',
        author: '준호',
        isLocal: true,
        timeLabel: '어제',
        content: '저도 하나 추천하자면 보수동 책방골목 쪽에 작은 카페들 조용해요.',
      ),
    ],
  ),
  QnaPost(
    id: 'q5',
    authorRole: UserType.tourist,
    title: '젼골목 순대국집 아직 영업하나요?',
    content: '작년에 갔던 곳인데 최근 소식 아시는 분 계신가요.',
    spotName: '젼골목',
    timeLabel: '어제',
    ts: 1,
  ),
];
