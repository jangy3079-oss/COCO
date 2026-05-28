class AppConstants {
  // TourAPI
  static const String tourApiBaseUrl = 'https://apis.data.go.kr/B551011';
  static const String tourApiKeyEnv = 'TOUR_API_KEY';

  // 지원 언어
  static const List<String> supportedLocales = ['ko', 'en', 'ja'];

  // 부산 중심 좌표
  static const double busanLat = 35.1796;
  static const double busanLng = 129.0756;

  // 지도 기본 줌
  static const double defaultZoom = 13.0;
}
