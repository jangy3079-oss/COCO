// Q&A 게시글/답변 모델 — coco_backend QnaPostResponse/QnaAnswerResponse/
// QnaPostDetailResponse와 1:1 매칭.
import '../../core/utils/backend_datetime.dart';

// SOS 질문 마커 — 별도 백엔드 컬럼 없이 title 앞에 이 문자열을 붙여서 저장하고,
// 프론트가 이걸 보고 배지 표시 + 목록 상단 고정을 한다(QnaComposerScreen에서 작성).
const String qnaSosMarker = '[SOS] ';

class QnaPost {
  final int id;
  final String userNickname;
  final String title;
  final String content;
  final int? spotId; // 스팟 태그 없이 쓴 질문이면 null
  final String? spotName;
  final int? adoptedAnswerId;
  final int answerCount;
  final DateTime createdAt;

  const QnaPost({
    required this.id,
    required this.userNickname,
    required this.title,
    required this.content,
    this.spotId,
    this.spotName,
    this.adoptedAnswerId,
    required this.answerCount,
    required this.createdAt,
  });

  bool get solved => adoptedAnswerId != null;

  // SOS 기능 — 백엔드 스키마 변경 없이(별도 컬럼 추가 없이) title 앞에 마커를
  // 붙여서 표시한다. 같은 앱을 쓰는 모든 사용자가 동일하게 파싱하므로, 마커가
  // 실제로 서버에 저장된 title에 들어있는 한 목록/정렬에 일관되게 반영된다.
  bool get isSos => title.startsWith(qnaSosMarker);
  String get displayTitle => isSos ? title.substring(qnaSosMarker.length) : title;

  factory QnaPost.fromJson(Map<String, dynamic> json) => QnaPost(
        id: json['id'] as int,
        userNickname: json['userNickname'] as String? ?? '',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        spotId: json['spotId'] as int?,
        spotName: json['spotName'] as String?,
        adoptedAnswerId: json['adoptedAnswerId'] as int?,
        answerCount: json['answerCount'] as int? ?? 0,
        createdAt: parseBackendDateTime(json['createdAt'] as String),
      );
}

class QnaAnswer {
  final int id;
  final String userNickname;
  final bool isLocal; // 답변자가 로컬 주민인지 (배지 표시용) — 백엔드가 채워서 내려줌
  final String content;
  final bool adopted;
  final DateTime createdAt;

  const QnaAnswer({
    required this.id,
    required this.userNickname,
    required this.isLocal,
    required this.content,
    required this.adopted,
    required this.createdAt,
  });

  String get authorInitial => userNickname.isNotEmpty ? userNickname.substring(0, 1) : '';

  factory QnaAnswer.fromJson(Map<String, dynamic> json) => QnaAnswer(
        id: json['id'] as int,
        userNickname: json['userNickname'] as String? ?? '',
        isLocal: json['isLocal'] as bool? ?? false,
        content: json['content'] as String? ?? '',
        adopted: json['adopted'] as bool? ?? false,
        createdAt: parseBackendDateTime(json['createdAt'] as String),
      );
}

/// GET /api/qna/posts/{id} 응답 — 질문 상세 + 답변 목록을 한 번에 담는다.
class QnaPostDetail {
  final QnaPost post;
  final List<QnaAnswer> answers;

  const QnaPostDetail({required this.post, required this.answers});

  factory QnaPostDetail.fromJson(Map<String, dynamic> json) => QnaPostDetail(
        post: QnaPost.fromJson(json['post'] as Map<String, dynamic>),
        answers: (json['answers'] as List? ?? [])
            .map((e) => QnaAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
