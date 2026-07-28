# COCO 개발 환경 사전준비 체크리스트 (Android 우선 개발)

데모·심사 편의를 위해 Android를 우선 개발 플랫폼으로 정했다 (에뮬레이터 세팅이 간단하고 APK로 바로 배포·설치 가능, 위치 기반 지도 기능은 실기기 테스트가 유리함). 아래는 macOS 기준 Flutter + Android 개발 환경 준비 순서.

## 1. Android Studio 설치
- [ ] https://developer.android.com/studio 에서 macOS용 Android Studio 다운로드 및 설치
- [ ] 최초 실행 시 Setup Wizard에서 **Standard** 설치 선택 → Android SDK, Platform-Tools, Android Virtual Device(AVD) 자동 설치
- [ ] SDK Manager에서 최신 Android SDK Platform (API 34 이상) 설치 확인

## 2. Flutter SDK 설치
- [ ] `brew install --cask flutter` (Homebrew 사용 시, 없으면 https://docs.flutter.dev/get-started/install/macos 에서 직접 다운로드)
- [ ] 압축 해제 시 zip으로 받았다면 `~/.zshrc` (또는 `~/.bash_profile`)에 PATH 추가
      ```
      export PATH="$PATH:[flutter 설치 경로]/bin"
      ```
- [ ] 터미널 재시작 후 `flutter --version` 으로 설치 확인

## 3. Android Studio ↔ Flutter 연동
- [ ] Android Studio → Settings(Preferences) → Plugins → **Flutter** 검색 후 설치 (Dart 플러그인 자동 포함)
- [ ] Android Studio 재시작

## 4. flutter doctor로 환경 점검
- [ ] 터미널에서 `flutter doctor` 실행 → 부족한 항목 확인
- [ ] Android 라이선스 미동의 항목이 있으면 `flutter doctor --android-licenses` 실행 후 전부 `y` 입력
- [ ] `flutter doctor`의 모든 체크가 ✓ (iOS/Xcode 항목은 Android 우선 개발이라 지금은 무시해도 됨)

## 5. 에뮬레이터(AVD) 생성
- [ ] Android Studio → Device Manager → **Create Device**
- [ ] Pixel 6/7 계열 + API 34(Android 14) 이미지 권장 (Google Play 이미지 선택 시 위치 서비스 정상 동작)
- [ ] 생성한 에뮬레이터 실행해서 정상 부팅 확인

## 6. 프로젝트 실행
- [ ] 프로젝트 클론 후 `cd COCO/frontend`
- [ ] `flutter pub get` 실행 — **다국어(l10n) 코드 자동 생성을 위해 필수** (오늘 추가한 로그인/회원가입 화면이 `AppLocalizations`를 사용하므로 이 명령을 실행해야 빌드됨)
- [ ] `flutter run` → 에뮬레이터 선택 후 앱 실행 확인 (로그인 화면이 첫 화면으로 뜨는지 확인)

## 7. 협업 관련
- [ ] Git 브랜치 전략 합의 (예: `main` / `feature/*`)
- [ ] 프론트(Flutter)·백엔드(Spring Boot + Java) 담당 분리 확인 — 백엔드는 아직 API 미구현 상태이므로 프론트는 당분간 화면(UI) 위주로 진행

## 참고 — 나중에 필요한 것 (지금은 생략 가능)
- iOS 개발 시: Xcode + CocoaPods 설치, Apple 개발자 계정 필요 (Flutter 특성상 코드베이스는 공유되므로 서비스화 단계에서 진행)
- 실기기 테스트 시: 안드로이드 기기에서 USB 디버깅 활성화 후 케이블 연결
