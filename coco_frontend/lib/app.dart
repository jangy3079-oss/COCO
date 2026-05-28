import 'package:flutter/material.dart';
import 'presentation/navigation/app_router.dart';

class CocoApp extends StatelessWidget {
  const CocoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'COCO',
      routerConfig: appRouter,
      theme: CocoTheme.light,
      debugShowCheckedModeBanner: false,
    );
  }
}
