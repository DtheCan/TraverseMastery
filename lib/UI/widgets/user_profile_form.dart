import 'package:flutter/material.dart';
import  'package:traversemastery/UI/widgets/custom_text_field.dart';

class UserProfileForm extends StatefulWidget {
  const UserProfileForm({super.key});

  @override
  State<UserProfileForm> createState() => _UserProfileFormState();
}

class _UserProfileFormState extends State<UserProfileForm> {
  final _formKey = GlobalKey<FormState>(); // Ключ для валидации формы

  // Контроллеры для получения значений из полей
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    // Не забываем очищать контроллеры
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Форма валидна, можно обрабатывать данные
      String firstName = _firstNameController.text;
      String lastName = _lastNameController.text;
      String email = _emailController.text;

      // Здесь ваша логика обработки данных (например, отправка на сервер, сохранение локально)
      print('Имя: $firstName');
      print('Фамилия: $lastName');
      print('Email: $email');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные отправлены!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, исправьте ошибки в форме.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView( // Используем ListView для прокрутки, если полей много
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          CustomTextField( // или TextFormField, если не используете кастомный
            controller: _firstNameController,
            labelText: 'Имя',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите имя';
              }
              return null;
            },
          ),
          CustomTextField(
            controller: _lastNameController,
            labelText: 'Фамилия',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите фамилию';
              }
              return null;
            },
          ),
          CustomTextField(
            controller: _emailController,
            labelText: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Пожалуйста, введите корректный email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24.0),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0)
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}