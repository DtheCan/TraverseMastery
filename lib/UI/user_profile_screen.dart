import 'package:flutter/material.dart';
import 'widgets/theodolite_form.dart'; // Импортируем нашу форму

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль пользователя'),
        centerTitle: true, // Для центрирования заголовка
      ),
      body: const TheodoliteForm(), // Вставляем нашу форму
    );
  }
}