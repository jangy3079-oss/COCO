import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 설정 화면. 언어 선택은 LocaleController를 통해 앱 전체 로케일을 실제로
/// 바꾼다(app.dart의 MaterialApp.router가 이 값을 구독).
/// 알림은 아직 목업(로컬 state만 토글).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notify = true;

  static const _languages = [('ko', '한국어'), ('en', 'English'), ('ja', '日本語')];

  Future<void> _confirmLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsLogoutConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.feedRouteComposeCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.settingsLogoutButton)),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 6),
                  Text(l10n.myPageMenuSettings, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _SectionLabel(l10n.settingsSectionLanguage),
                  // 현재 앱 로케일 — LocaleController를 구독해서, 다른 화면(예: 여러
                  // 탭에 설정 화면이 동시에 살아있는 경우는 없지만)에서 바뀌어도 항상
                  // 최신 선택 상태를 보여준다.
                  Builder(builder: (context) {
                    final currentCode = context.watch<LocaleController>().locale.languageCode;
                    return Column(
                      children: [
                        for (final l in _languages)
                          InkWell(
                            onTap: () => context.read<LocaleController>().setLocale(Locale(l.$1)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l.$2, style: const TextStyle(fontSize: 15, color: CocoTheme.secondary)),
                                  if (currentCode == l.$1) const Icon(Icons.check_rounded, color: CocoTheme.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  _SectionLabel(l10n.settingsSectionNotifications),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.settingsPushNotificationLabel, style: const TextStyle(fontSize: 15, color: CocoTheme.secondary)),
                        Switch(
                          value: _notify,
                          activeColor: CocoTheme.primary,
                          onChanged: (v) => setState(() => _notify = v),
                        ),
                      ],
                    ),
                  ),
                  _SectionLabel(l10n.settingsSectionAccount),
                  InkWell(
                    onTap: _confirmLogout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.settingsLogoutButton, style: const TextStyle(fontSize: 15, color: CocoTheme.secondary)),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.settingsDeleteAccountLabel, style: TextStyle(fontSize: 15, color: Colors.grey.shade400)),
                        Text(l10n.settingsDeleteAccountDisabledHint, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
    );
  }
}
