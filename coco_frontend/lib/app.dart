import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'l10n/generated/app_localizations.dart';

class CocoApp extends StatelessWidget {
  const CocoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'COCO',
      routerConfig: appRouter,
      theme: CocoTheme.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
