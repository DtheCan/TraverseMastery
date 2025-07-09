import 'package:flutter/material.dart';
import 'package:traversemastery/ui/app_theme.dart';
import 'package:traversemastery/ui/screens/data_entry_screen.dart';
// Удаляем дублирующийся импорт 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // <--- ДОБАВЛЕН ИМПОРТ для intl

Future<void> main() async { // <--- ИЗМЕНЕНО: main теперь async
  // Гарантируем, что Flutter Binding инициализирован перед асинхронными операциями
  // или использованием плагинов (хорошая практика, если main асинхронный).
  WidgetsFlutterBinding.ensureInitialized(); // <--- ДОБАВЛЕНО

  // Инициализация данных для форматирования дат для русской локали
  await initializeDateFormatting('ru_RU', null); // <--- ДОБАВЛЕНО

  // Если вы планируете поддерживать другие локали или хотите загрузить данные для текущей
  // локали устройства по умолчанию, вы можете сделать:
  // await initializeDateFormatting(null, null); // Загрузит все доступные
  // ИЛИ
  // final String? deviceLocale = Platform.localeName; // Потребует import 'dart:io';
  // if (deviceLocale != null) {
  //   await initializeDateFormatting(deviceLocale, null);
  // }


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TM', // Название приложения
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

