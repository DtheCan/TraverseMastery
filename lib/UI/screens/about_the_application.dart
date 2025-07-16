import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Для получения версии приложения

class AboutTheApplicationScreen extends StatefulWidget {
  const AboutTheApplicationScreen({super.key});

  @override
  State<AboutTheApplicationScreen> createState() => _AboutTheApplicationScreenState();
}

class _AboutTheApplicationScreenState extends State<AboutTheApplicationScreen> {
  String _appVersion = 'Загрузка...';
  final String _developerName = 'Бородулин Денис Алексеевич / DL';
  final String _appPurpose =
      'Это приложение предназначено для выполнения расчетов теодолитных ходов, '
      'помогая геодезистам и студентам в их профессиональной и учебной деятельности. '
      'Оно позволяет вводить данные измерений, производить вычисления с учетом невязок, '
      'сохранять результаты и делиться ими.';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          if (packageInfo.buildNumber.isNotEmpty) {
            _appVersion += ' (сборка ${packageInfo.buildNumber})';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Не удалось загрузить версию';
        });
      }
      print('Ошибка загрузки информации о пакете: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Стиль для заголовков секций
    final TextStyle sectionTitleStyle = Theme.of(context)
        .textTheme
        .titleMedium!
        .copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary);
    // Стиль для обычного текста
    final TextStyle contentTextStyle = Theme.of(context).textTheme.bodyLarge!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('О приложении'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Image.asset('assets/images/play_store_512.png', height: 100), // Пример пути
            ),
            const SizedBox(height: 20),

            Text(
              'TraverseMastery',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            _buildInfoSection(
              title: 'Версия приложения',
              content: _appVersion,
              icon: Icons.info_outline,
              titleTextStyle: sectionTitleStyle,
              contentTextStyle: contentTextStyle,
            ),
            _buildInfoSection(
              title: 'Разработчик',
              content: _developerName,
              icon: Icons.person_outline,
              titleTextStyle: sectionTitleStyle,
              contentTextStyle: contentTextStyle,
            ),
            _buildInfoSection(
              title: 'Назначение приложения',
              content: _appPurpose,
              icon: Icons.description_outlined,
              titleTextStyle: sectionTitleStyle,
              contentTextStyle: contentTextStyle,
            ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                '© ${DateTime.now().year} $_developerName. Все права защищены.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
    required IconData icon,
    required TextStyle titleTextStyle,
    required TextStyle contentTextStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: titleTextStyle.color),
              const SizedBox(width: 8),
              Text(title, style: titleTextStyle),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30.0), // Небольшой отступ для контента
            child: Text(
              content,
              style: contentTextStyle,
              textAlign: TextAlign.justify, // Для лучшего вида длинного текста
            ),
          ),
        ],
      ),
    );
  }
}

