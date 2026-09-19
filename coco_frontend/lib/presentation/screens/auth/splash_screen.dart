import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/coco_mark.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CocoMark(width: 104, height: 92),
                    const SizedBox(height: 12),
                    const Text(
                      'COCO',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: CocoTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        l10n.splashTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CocoTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.push('/signup'),
                      child: Text(l10n.splashGetStartedButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CocoTheme.secondary,
                        side: BorderSide(color: Colors.black.withOpacity(0.1)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.push('/login'),
                      child: Text(l10n.splashHaveAccountButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final currentCode = context.watch<LocaleController>().locale.languageCode;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LangOption(
                          label: '한국어',
                          selected: currentCode == 'ko',
                          onTap: () => context.read<LocaleController>().setLocale(const Locale('ko')),
                        ),
                        const SizedBox(width: 16),
                        _LangOption(
                          label: 'English',
                          selected: currentCode == 'en',
                          onTap: () => context.read<LocaleController>().setLocale(const Locale('en')),
                        ),
                        const SizedBox(width: 16),
                        _LangOption(
                          label: '日本語',
                          selected: currentCode == 'ja',
                          onTap: () => context.read<LocaleController>().setLocale(const Locale('ja')),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? CocoTheme.primary : Colors.grey.shade400,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
