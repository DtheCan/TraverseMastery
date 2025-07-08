import 'package:flutter/material.dart';
import 'package:traversemastery/UI/app_theme.dart';
import 'package:traversemastery/UI/user_profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TestDesc App',
      // Используем нашу тёмную тему по умолчанию
      theme: AppTheme.darkTheme,
      // Если вы захотите добавить логику переключения тем,
      // вам также понадобится свойство darkTheme и themeMode:
      // darkTheme: AppTheme.darkTheme, // Можно явно указать темную тему для darkTheme
      // themeMode: ThemeMode.dark, // или ThemeMode.light, или ThemeMode.system

      home: const UserProfileScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
