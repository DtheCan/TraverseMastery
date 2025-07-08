import 'package:flutter/material.dart';
import 'package:traversemastery/ui/app_theme.dart';
import 'package:traversemastery/ui/screens/data_entry_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Расчет Теодолитного Хода', // Название приложения
      // Убедитесь, что AppTheme.darkTheme (или AppTheme.lightTheme) существует и корректно определен
      theme: AppTheme.lightTheme, // Для примера используем светлую тему по умолчанию
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Можно выбрать system, light, dark
      // Убедитесь, что класс DataEntryScreen определен и импортирован правильно
      home: const DataEntryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
