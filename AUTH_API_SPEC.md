# 로그인/회원가입 API 명세 (프론트 → 백엔드)

프론트(Flutter) 로그인/회원가입 화면이 필요로 하는 API 스펙 정리. 현재 백엔드(`AuthController`)는 스텁 상태라, 아래 내용대로 구현해주면 프론트 TODO 자리에 바로 연결할 수 있음.

## 현재 백엔드 상태 점검
- `AuthController` — 미구현 (`// TODO: 기능 구현 예정`)
- `LoginRequest` — `email`, `password` 있음, 그대로 써도 됨
- `SignupRequest` — `email`, `password`, `nickname`, `locale` 있음. **`role` 필드가 없음 → 추가 필요** (아래 2번 참고)
- 응답 DTO(`AuthResponse` 등) 없음 → 새로 만들어야 함
- `User` 엔티티의 `role` 컬럼 주석은 `USER | LOCAL`로 되어있는데, 프론트는 "로컬 주민/관광객" 구분을 `LOCAL`/`TOURIST` 값으로 만들어놨음. **값 컨벤션을 맞춰야 함** — `LOCAL` / `TOURIST` 로 통일하는 걸 제안 (아래 참고, 상의 후 확정 필요)

---

## 1. POST `/api/auth/login` — 로그인

### Request
```json
{
  "email": "test@example.com",
  "password": "password123"
}
```
`LoginRequest` 그대로 사용 가능.

### Response — 200 OK
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "userId": 1,
  "email": "test@example.com",
  "nickname": "부산토박이",
  "role": "LOCAL",
  "locale": "ko"
}
```
(새 DTO `AuthResponse` 필요 — `dto/response/AuthResponse.java`)

### Error
| 상황 | 상태 코드 | 예시 body |
|---|---|---|
| 이메일/비밀번호 불일치 | 401 | `{ "message": "이메일 또는 비밀번호가 올바르지 않습니다." }` |
| 입력값 검증 실패 (`@Email @NotBlank`) | 400 | `{ "message": "이메일 형식이 올바르지 않습니다." }` |

---

## 2. POST `/api/auth/signup` — 회원가입

### Request
```json
{
  "email": "test@example.com",
  "password": "password123",
  "nickname": "부산토박이",
  "locale": "ko",
  "role": "LOCAL"
}
```
| 필드 | 타입 | 필수 | 비고 |
|---|---|---|---|
| email | String | O | 형식 검증 |
| password | String | O | 프론트에서 8자 이상만 클라이언트 검증, 서버에서도 재검증 권장 |
| nickname | String | O | |
| locale | String | X | `ko`/`en`/`ja` — 앱 UI 언어, 사용자가 입력하는 게 아니라 프론트에서 기기 로케일 기준으로 자동 전송 예정 |
| **role** | String | O | **`LOCAL`(로컬 주민) / `TOURIST`(관광객)** — `SignupRequest`에 새로 추가 필요 |

`SignupRequest`에 `role` 필드 추가하고, `User` 엔티티 `role` 컬럼에 넣을 값도 `LOCAL`/`TOURIST` 컨벤션으로 맞춰줘야 함 (현재 엔티티 주석엔 `USER | LOCAL`로 되어있어서 값이 다름 — 어떤 값으로 갈지 확정해서 알려주면 프론트 `UserType.apiValue`도 맞춰서 고칠게).

### Response — 201 Created
로그인과 동일한 `AuthResponse` 형태. 프론트는 회원가입 성공 시 바로 홈 화면으로 넘어가는 자동 로그인 흐름이라, 회원가입 응답에도 `accessToken`이 같이 와야 함.
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "userId": 2,
  "email": "test@example.com",
  "nickname": "부산토박이",
  "role": "LOCAL",
  "locale": "ko"
}
```

### Error
| 상황 | 상태 코드 | 예시 body |
|---|---|---|
| 이메일 중복 (`uq_users_email`) | 409 | `{ "message": "이미 가입된 이메일입니다." }` |
| 입력값 검증 실패 | 400 | `{ "message": "닉네임을 입력해주세요." }` |

---

## 공통 사항
- 에러 응답은 위 예시처럼 `{ "message": "..." }` 한 가지 형태로 통일해줘 — 프론트에서 스낵바로 그대로 띄우기 쉬움.
- 비밀번호는 반드시 해시(BCrypt 등)해서 저장, 응답 body에는 절대 포함하지 않기.
- 이후 Q&A/피드 등 로그인 필요한 API들은 `Authorization: Bearer {accessToken}` 헤더로 사용자 식별하는 방식 권장 (JWT 기준).

## 프론트 연결 지점
- `lib/presentation/screens/auth/login_screen.dart` → `_handleLogin()` 안 `TODO(backend)` 주석 자리
- `lib/presentation/screens/auth/signup_screen.dart` → `_handleSignup()` 안 `TODO(backend)` 주석 자리
- 현재는 실제 호출 없이 0.4초 대기 후 성공 처리하는 스텁 상태. API 준비되면 `dio`로 실제 호출 + 토큰 저장(예: `flutter_secure_storage`, 아직 미설치) 로직으로 교체 예정.

## 아직 안 정해진 것 (상의 필요)
- `role` 값 컨벤션: `LOCAL`/`TOURIST` vs 엔티티 주석의 `USER`/`LOCAL` — 확정 필요
- 회원가입 시 자동 로그인(토큰 즉시 발급) vs 가입 후 로그인 화면으로 돌아가기 — 지금 프론트는 자동 로그인 기준으로 만들어둠, 바뀌면 프론트도 같이 수정
