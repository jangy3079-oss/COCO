// Q&A 커뮤니티 게시글 모델
class QnaPost {
  final String id;
  final String question;
  final String locale;       // 질문 언어 (en | ja | ko)
  final List<QnaAnswer> answers;
  final DateTime createdAt;

  const QnaPost({
    required this.id,
    required this.question,
    required this.locale,
    required this.answers,
    required this.createdAt,
  });
}

class QnaAnswer {
  final String id;
  final String authorId;
  final String authorNickname;
  final String content;
  final bool isAdopted;
  final DateTime createdAt;

  const QnaAnswer({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.content,
    required this.isAdopted,
    required this.createdAt,
  });
}
