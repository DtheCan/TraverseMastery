import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:traversemastery/core/services/check_update.dart';
import 'package:traversemastery/ui/app_theme.dart';
import 'package:traversemastery/ui/screens/data_entry_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);

  runApp(
    // 3. ОБЕРНИТЕ MyApp (или его содержимое) В ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (context) => CheckUpdateService(), // Создаем экземпляр сервиса
      child: const MyApp(), // Ваш существующий MyApp
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TM',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const DataEntryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
