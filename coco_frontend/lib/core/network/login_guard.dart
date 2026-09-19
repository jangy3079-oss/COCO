// 로그인이 필요한 액션(찜/코스생성/QnA작성/스팟등록 등) 공통 처리.
// 백엔드가 미로그인 요청에 401을 주므로, 두 군데서 같은 안내를 띄운다:
// - requireLogin: API를 호출하기 전에 먼저 로그인 여부를 확인해 불필요한 401 호출을 피한다.
// - isUnauthorized: 그래도(토큰 만료 등으로) 401이 오면 잡아서 똑같은 안내를 보여줄 때 쓴다.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'auth_token_store.dart';

/// 로그인 안 됐으면 스낵바를 띄우고 false를 반환한다 — 호출부는 이때 API 호출 없이 바로 return.
bool requireLogin(BuildContext context) {
  if (AuthTokenStore.token != null) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context)!.commonLoginRequiredMessage)),
  );
  return false;
}

/// DioException이 401(미인증)인지 판별 — 토큰이 있었는데도 뒤늦게 거부된 경우 잡아낸다.
bool isUnauthorized(Object error) => error is DioException && error.response?.statusCode == 401;
