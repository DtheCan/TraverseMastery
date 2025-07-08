import 'package:flutter/material.dart';
import 'package:traversemastery/UI/user_profile_screen.dart'; // Убедитесь, что путь правильный к вашему проекту

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TestDesc App',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Или ваша тема
        // Для более современного вида можно использовать colorScheme
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme( // Общие стили для полей ввода
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          // filled: true,
          // fillColor: Colors.grey[100],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData( // Общие стили для кнопок
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48), // Кнопка на всю ширину
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ),
      home: const UserProfileScreen(), // Указываем наш новый экран как домашний
      debugShowCheckedModeBanner: false,
    );
  }
}