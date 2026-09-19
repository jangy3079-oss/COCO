package com.coco.backend.service;

import com.coco.backend.dto.request.QnaAdoptRequest;
import com.coco.backend.dto.request.QnaAnswerRequest;
import com.coco.backend.dto.request.QnaPostRequest;
import com.coco.backend.dto.response.QnaAnswerResponse;
import com.coco.backend.dto.response.QnaPostDetailResponse;
import com.coco.backend.dto.response.QnaPostResponse;
import com.coco.backend.entity.QnaAnswer;
import com.coco.backend.entity.QnaPost;
import com.coco.backend.entity.Role;
import com.coco.backend.entity.Spot;
import com.coco.backend.entity.User;
import com.coco.backend.exception.ForbiddenException;
import com.coco.backend.repository.QnaAnswerRepository;
import com.coco.backend.repository.QnaPostRepository;
import com.coco.backend.repository.SpotRepository;
import com.coco.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class QnaService {

    private final QnaPostRepository qnaPostRepository;
    private final QnaAnswerRepository qnaAnswerRepository;
    private final SpotRepository spotRepository;
    private final UserRepository userRepository;

    /**
     * 질문 목록. filter=all/unanswered/mine, sort=latest/unanswered_first 조합을 지원한다.
     * filter=mine일 때 userId는 컨트롤러에서 이미 로그인 여부를 검증한 뒤 넘어온다.
     */
    public List<QnaPostResponse> listPosts(String filter, String sort, Long userId) {
        List<QnaPost> posts = "mine".equals(filter)
                ? qnaPostRepository.findByUser_IdOrderByCreatedAtDesc(userId)
                : qnaPostRepository.findAllByOrderByCreatedAtDesc();

        Map<Long, Integer> answerCountByPostId = fetchAnswerCounts(posts);

        List<QnaPost> filtered = "unanswered".equals(filter)
                ? posts.stream().filter(p -> answerCountByPostId.getOrDefault(p.getId(), 0) == 0).toList()
                : posts;

        // Stream.sorted는 안정 정렬이라 createdAt desc로 이미 정렬된 순서가 같은 그룹 안에서는 유지된다.
        List<QnaPost> sorted = "unanswered_first".equals(sort)
                ? filtered.stream()
                        .sorted(Comparator.comparingInt(p -> answerCountByPostId.getOrDefault(p.getId(), 0) == 0 ? 0 : 1))
                        .toList()
                : filtered;

        return sorted.stream()
                .map(p -> toResponse(p, answerCountByPostId.getOrDefault(p.getId(), 0)))
                .toList();
    }

    /** 로그인한 사용자가 (선택적으로 스팟을 태그해서) 질문을 올린다. */
    public QnaPostResponse createPost(Long userId, QnaPostRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
        Spot spot = request.getSpotId() != null
                ? spotRepository.findById(request.getSpotId())
                        .orElseThrow(() -> new IllegalArgumentException("스팟을 찾을 수 없습니다."))
                : null;

        QnaPost saved = qnaPostRepository.save(QnaPost.builder()
                .user(user)
                .title(request.getTitle())
                .content(request.getContent())
                .spot(spot)
                .locale(request.getLocale())
                .build());
        return toResponse(saved, 0);
    }

    /** 질문 상세 — 질문 본문 + 답변 목록(오래된 순)을 함께 반환. */
    public QnaPostDetailResponse getPostDetail(Long postId) {
        QnaPost post = qnaPostRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("질문을 찾을 수 없습니다."));
        List<QnaAnswer> answers = qnaAnswerRepository.findByQnaPost_IdOrderByCreatedAtAsc(postId);

        return QnaPostDetailResponse.builder()
                .post(toResponse(post, answers.size()))
                .answers(answers.stream().map(this::toAnswerResponse).toList())
                .build();
    }

    /** 로그인한 사용자가 질문에 답변을 단다. */
    public QnaAnswerResponse createAnswer(Long userId, Long postId, QnaAnswerRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
        QnaPost post = qnaPostRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("질문을 찾을 수 없습니다."));

        QnaAnswer saved = qnaAnswerRepository.save(QnaAnswer.builder()
                .qnaPost(post)
                .user(user)
                .content(request.getContent())
                .build());
        return toAnswerResponse(saved);
    }

    /** 답변 채택 — 질문 작성자만 가능. QnaPost.adoptedAnswerId와 QnaAnswer.adopted를 함께 갱신한다. */
    @Transactional
    public void adopt(Long userId, Long postId, QnaAdoptRequest request) {
        QnaPost post = qnaPostRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("질문을 찾을 수 없습니다."));
        if (!post.getUser().getId().equals(userId)) {
            throw new ForbiddenException("질문 작성자만 답변을 채택할 수 있습니다.");
        }

        QnaAnswer answer = qnaAnswerRepository.findById(request.getAnswerId())
                .orElseThrow(() -> new IllegalArgumentException("답변을 찾을 수 없습니다."));
        if (!answer.getQnaPost().getId().equals(postId)) {
            throw new IllegalArgumentException("해당 질문에 달린 답변이 아닙니다.");
        }

        answer.markAdopted();
        post.adopt(answer.getId());
    }

    /** 질문 목록의 질문별 답변 개수를 한 번에 집계. 반환값: qnaPostId -> answerCount. */
    private Map<Long, Integer> fetchAnswerCounts(List<QnaPost> posts) {
        if (posts.isEmpty()) return Map.of();
        List<Long> postIds = posts.stream().map(QnaPost::getId).toList();
        Map<Long, Integer> result = new HashMap<>();
        for (Object[] row : qnaAnswerRepository.countByQnaPostIds(postIds)) {
            Long postId = (Long) row[0];
            int count = ((Number) row[1]).intValue();
            result.put(postId, count);
        }
        return result;
    }

    private QnaPostResponse toResponse(QnaPost p, int answerCount) {
        Spot spot = p.getSpot();
        return QnaPostResponse.builder()
                .id(p.getId())
                .userNickname(p.getUser().getNickname())
                .title(p.getTitle())
                .content(p.getContent())
                .spotId(spot != null ? spot.getId() : null)
                .spotName(spot != null ? spot.getTitleKo() : null)
                .adoptedAnswerId(p.getAdoptedAnswerId())
                .answerCount(answerCount)
                .createdAt(p.getCreatedAt())
                .build();
    }

    private QnaAnswerResponse toAnswerResponse(QnaAnswer a) {
        return QnaAnswerResponse.builder()
                .id(a.getId())
                .userNickname(a.getUser().getNickname())
                .isLocal(a.getUser().getRole() == Role.LOCAL)
                .content(a.getContent())
                .adopted(Boolean.TRUE.equals(a.getAdopted()))
                .createdAt(a.getCreatedAt())
                .build();
    }
}
