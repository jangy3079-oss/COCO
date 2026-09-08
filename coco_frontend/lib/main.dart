import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true); // .env 없어도 앱은 뜨게(카카오맵 키 미설정 시)
  runApp(const CocoApp());
}
