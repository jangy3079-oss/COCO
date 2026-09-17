import 'package:flutter/material.dart';

/// 앱 전체 언어(로케일)를 들고 있는 컨트롤러. 설정 화면에서 언어를 바꾸면
/// 여기 값을 바꾸고, app.dart의 MaterialApp.router가 이 값을 구독해서
/// 전체 화면의 로케일을 즉시 반영한다.
/// (AuthTokenStore와 동일하게 메모리에만 보관 — 앱 재실행 시 기본값(한국어)로
/// 돌아간다. 재실행 후에도 유지가 필요해지면 shared_preferences 등으로 교체.)
class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('ko');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
