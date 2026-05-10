# 🥥 COCO (코코)

> 관광지도의 바깥, 골목의 안쪽으로 — 부산 로컬 골목 탐험 앱

2026 한국관광공사 관광데이터 활용 공모전 출품작

## 기술 스택

| 영역 | 기술 |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Java 17 + Spring Boot 3 |
| Database | PostgreSQL |
| API | 한국관광공사 TourAPI |

## 주요 기능

| 탭 | 기능 |
|---|---|
| 🏠 홈 | 큐레이션 로컬 추천 피드 |
| 🗺️ 지도 | 부산 로컬 맵 (마커 기반) |
| 📸 피드 | 유저 UGC — 사진 + 위치태그 |
| 💬 Q&A | 실시간 로컬-관광객 커뮤니티 |
| 👤 MY | 마이페이지 |

## 프로젝트 구조

```
COCO/
├── frontend/                        # Flutter 앱
│   └── lib/
│       ├── core/                    # 상수, 테마, 유틸
│       ├── data/                    # 모델, 레포지토리, API 서비스
│       └── presentation/            # 화면, 위젯, 네비게이션
│
└── backend/                         # Spring Boot API 서버
    └── src/main/java/com/coco/
        ├── controller/              # REST API 엔드포인트
        ├── service/                 # 비즈니스 로직
        ├── repository/              # DB 접근 (JPA)
        ├── entity/                  # DB 테이블 매핑
        ├── dto/                     # 요청/응답 객체
        ├── config/                  # Security, CORS 설정
        └── exception/               # 전역 예외 처리
```

## 실행 방법

### Backend
```bash
cd backend
# .env 파일에 DB_USERNAME, DB_PASSWORD, TOUR_API_KEY 설정 후
./mvnw spring-boot:run
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

## API 엔드포인트 (예정)

| Method | URL | 설명 |
|---|---|---|
| POST | /api/auth/signup | 회원가입 |
| POST | /api/auth/login | 로그인 |
| GET | /api/spot | 스팟 목록 조회 |
| GET | /api/spot/nearby | 주변 스팟 조회 |
| GET | /api/feed | 피드 목록 |
| POST | /api/feed | 피드 게시글 작성 |
| GET | /api/qna | Q&A 목록 |
| POST | /api/qna | 질문 등록 |
