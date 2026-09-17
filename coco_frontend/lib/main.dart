import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/locale/locale_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true); // .env 없어도 앱은 뜨게(카카오맵 키 미설정 시)
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleController(),
      child: const CocoApp(),
    ),
  );
}
