import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// Убедитесь, что путь к вашей модели TraverseCalculationResult верный
import 'package:traversemastery/models/traverse_calculation_result.dart';

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

  Future<String?> saveCalculationResult({
    required TraverseCalculationResult result,
    String? suggestedFileName,
  }) async {
    String? appDirPath = await _getAppDirectoryPath();

    if (appDirPath == null) {
      print("FormSaverService: Не удалось определить путь для сохранения.");
      return null;
    }

    try {
      final String saveDirPath = '$appDirPath/data/SavedCalculationResult';
      final Directory saveDir = Directory(saveDirPath);

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
        print('FormSaverService: Создана директория: ${saveDir.path}');
      } else {
        print('FormSaverService: Директория для сохранения уже существует: ${saveDir.path}');
      }

      print("FormSaverService: Получено suggestedFileName: '$suggestedFileName'");
      String fileName = suggestedFileName?.trim() ?? '';
      print("FormSaverService: fileName после trim и ?? '': '$fileName'");


      // 1. Если предложенное имя ПУСТОЕ, генерируем имя по умолчанию
      if (fileName.isEmpty) {
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final idPart = result.calculationId.isNotEmpty && result.calculationId.length >= 8
            ? result.calculationId.substring(0, 8)
            : "calc"; // Изменено с "res" на "calc" для большей понятности
        fileName = '${idPart}_$timestamp';
        print("FormSaverService: suggestedFileName был пуст, сгенерировано имя по умолчанию: '$fileName'");
      }

      // 2. Очистка имени файла от недопустимых символов и форматирование
      // Разрешаем: английские буквы, русские буквы, цифры, пробел, точка, дефис, подчеркивание
      // Все остальное заменяем на одно подчеркивание
      fileName = fileName
          .replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9\s\._-]'), '_')
          .trim(); // Убираем пробелы по краям, которые могли образоваться или были изначально

      // Заменяем последовательности пробелов на одно подчеркивание
      fileName = fileName.replaceAll(RegExp(r'\s+'), '_');

      // Заменяем последовательности подчеркиваний (если их больше одного) на одно подчеркивание
      fileName = fileName.replaceAll(RegExp(r'_+'), '_');

      // Удаляем подчеркивание в начале имени файла, если оно есть
      if (fileName.startsWith('_')) {
        fileName = fileName.substring(1);
      }
      // Удаляем подчеркивание в конце имени файла (перед расширением), если оно есть
      if (fileName.endsWith('_')) {
        fileName = fileName.substring(0, fileName.length - 1);
      }
      print("FormSaverService: fileName после основной очистки: '$fileName'");


      // 3. Если после очистки имя файла стало пустым или недопустимым,
      //    снова генерируем имя по умолчанию (с другим префиксом для отладки).
      //    Также проверяем, не состоит ли имя только из точек или дефисов.
      if (fileName.isEmpty ||
          fileName == '_' ||
          fileName.replaceAll('.', '').replaceAll('-', '').isEmpty || // Состоит только из точек/дефисов
          fileName.toLowerCase() == '.json') { // Только расширение

        final now = DateTime.now();
        final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final idPart = result.calculationId.isNotEmpty && result.calculationId.length >= 8
            ? result.calculationId.substring(0, 8)
            : "calc_err";
        fileName = '${idPart}_${timestamp}_cleaned';
        print("FormSaverService: fileName после очистки стал некорректным, сгенерировано новое имя: '$fileName'");
      }

      // 4. Добавляем расширение .json, если его нет
      if (!fileName.toLowerCase().endsWith('.json')) {
        fileName += '.json';
      }
      print("FormSaverService: Конечное имя файла для сохранения: '$fileName'");


      final String filePath = '${saveDir.path}/$fileName';
      final File file = File(filePath);
      final String jsonString = jsonEncode(result.toJson()); // Убедитесь, что toJson() есть в вашей модели

      await file.writeAsString(jsonString);
      print('FormSaverService: Файл успешно записан: $filePath');
      return filePath;

    } catch (e, s) {
      print('FormSaverService: Ошибка сохранения JSON: $e');
      print('FormSaverService: Stack trace: $s');
      return null;
    }
  }
}

