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
      // 모바일 화면 기준으로 짠 UI라, 웹에서 넓은 창 그대로 늘어나지 않도록
      // 폰 폭 정도로 제한하고 나머지는 배경색으로 채운다(네이티브 모바일에서는
      // 화면이 이미 이 폭보다 좁으니 사실상 아무 영향 없음).
      builder: (context, child) {
        return ColoredBox(
          color: const Color(0xFFE9E9EC),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
