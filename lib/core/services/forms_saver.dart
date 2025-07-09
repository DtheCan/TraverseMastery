import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart'; // Убедитесь, что путь к модели верный

// --- Цвета для SnackBar (можно передавать из UI или определить здесь, если сервис сам показывает SnackBar) ---
// const _errorColor = Colors.redAccent; // Если SnackBar показывается из сервиса
// const _successColor = Colors.green;
// const _textOnPrimarySurface = Colors.white;

class FormSaverService {
  Future<String?> _getAppDirectoryPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      print("Ошибка получения директории приложения: $e");
      return null;
    }
  }

  // Возвращает путь к файлу в случае успеха, или null в случае ошибки
  Future<String?> saveCalculationResult({
    required TraverseCalculationResult result,
    String? suggestedFileName,
    // BuildContext? context, // Если хотите показывать SnackBar из сервиса
  }) async {
    String? appDirPath = await _getAppDirectoryPath();

    if (appDirPath == null) {
      // Если context передан, можно показать SnackBar
      // if (context != null && context.mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       backgroundColor: _errorColor,
      //       content: Text('Не удалось определить путь для сохранения.', style: TextStyle(color: _textOnPrimarySurface)),
      //       behavior: SnackBarBehavior.floating,
      //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      //     ),
      //   );
      // }
      return null; // Ошибка определения пути
    }

    try {
      // Путь теперь /data/SavedCalculationResult, как вы просили
      final String saveDirPath = '$appDirPath/data/SavedCalculationResult'; // ИЗМЕНЕНО ИМЯ ПАПКИ
      final Directory saveDir = Directory(saveDirPath);

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
        print('Создана директория: ${saveDir.path}');
      } else {
        print('Директория для сохранения уже существует: ${saveDir.path}');
      }

      String fileName = suggestedFileName?.trim() ?? '';
      if (fileName.isEmpty || fileName.toLowerCase() == '.json') {
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final idPart = result.calculationId.isNotEmpty && result.calculationId.length >= 8
            ? result.calculationId.substring(0, 8)
            : "res";
        fileName = 'calc_${idPart}_$timestamp';
      }

      fileName = fileName
          .replaceAll(RegExp(r'[^\w\s\.-]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll('..', '_');

      if (!fileName.toLowerCase().endsWith('.json')) {
        fileName += '.json';
      }
      if (fileName == '.json') {
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        fileName = 'calc_default_$timestamp.json';
      }

      final String filePath = '${saveDir.path}/$fileName';
      final File file = File(filePath);
      final String jsonString = jsonEncode(result.toJson());
      await file.writeAsString(jsonString);
      print('Файл успешно записан: $filePath');
      return filePath; // Возвращаем путь к файлу
    } catch (e, s) {
      print('Ошибка сохранения JSON: $e');
      print('Stack trace: $s');
      // Если context передан, можно показать SnackBar ошибки
      // if (context != null && context.mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       backgroundColor: _errorColor,
      //       content: Text('Ошибка сохранения файла: ${e.toString().split(':').last.trim()}', style: const TextStyle(color: _textOnPrimarySurface)),
      //       behavior: SnackBarBehavior.floating,
      //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      //     ),
      //   );
      // }
      return null; // Ошибка сохранения
    }
  }
}