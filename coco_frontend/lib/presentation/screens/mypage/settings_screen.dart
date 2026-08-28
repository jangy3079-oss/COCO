import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// 설정 화면. 언어/알림은 화면 로컬 상태만 토글하는 목업이다.
/// TODO: 언어는 lib/l10n/app_{ko,en,ja}.arb 인프라는 이미 있지만 실제 화면들이
/// AppLocalizations를 아직 참조하지 않아서, 여기서 고른 값이 앱 전체 언어를
/// 바꾸진 않는다 — 실제 로케일 전환 연동은 별도 작업 필요.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _lang = 'ko';
  bool _notify = true;

  static const _languages = [('ko', '한국어'), ('en', 'English'), ('ja', '日本語')];

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text('설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _SectionLabel('언어'),
                  for (final l in _languages)
                    InkWell(
                      onTap: () => setState(() => _lang = l.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l.$2, style: const TextStyle(fontSize: 15, color: CocoTheme.secondary)),
                            if (_lang == l.$1) const Icon(Icons.check_rounded, color: CocoTheme.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  _SectionLabel('알림'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('푸시 알림 받기', style: TextStyle(fontSize: 15, color: CocoTheme.secondary)),
                        Switch(
                          value: _notify,
                          activeColor: CocoTheme.primary,
                          onChanged: (v) => setState(() => _notify = v),
                        ),
                      ],
                    ),
                  ),
                  _SectionLabel('계정'),
                  InkWell(
                    onTap: _confirmLogout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('로그아웃', style: TextStyle(fontSize: 15, color: CocoTheme.secondary)),
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
                        Text('회원 탈퇴', style: TextStyle(fontSize: 15, color: Colors.grey.shade400)),
                        Text('데모에서 비활성화', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
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
