import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart'; // Убедитесь, что путь верный

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

  // Вспомогательный приватный метод для генерации уникального имени файла
  Future<String> _generateUniqueFileName(Directory saveDir, String baseName, String extension) async {
    String finalName = baseName;
    int counter = 1;

    // Сначала проверим базовое имя без суффикса
    File fileToCheck = File('${saveDir.path}/$finalName$extension');

    if (await fileToCheck.exists()) {
      // Если файл с базовым именем существует, начинаем добавлять суффикс
      String nameWithoutExistingSuffix = baseName;
      // Убираем потенциальный существующий суффикс (число в скобках) для корректной проверки и наращивания
      final RegExp suffixRegex = RegExp(r'\s*\(\d+\)$');
      if (suffixRegex.hasMatch(nameWithoutExistingSuffix)) {
        nameWithoutExistingSuffix = nameWithoutExistingSuffix.replaceAll(suffixRegex, '').trim();
      }

      do {
        finalName = '$nameWithoutExistingSuffix ($counter)';
        fileToCheck = File('${saveDir.path}/$finalName$extension');
        counter++;
      } while (await fileToCheck.exists());
    }
    return finalName; // Возвращаем имя без расширения
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
      }

      String baseFileName = suggestedFileName?.trim() ?? '';
      print("FormSaverService: Получено suggestedFileName: '$baseFileName'");

      if (baseFileName.isEmpty) {
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final idPart = result.calculationId.isNotEmpty && result.calculationId.length >= 8
            ? result.calculationId.substring(0, 8)
            : "calc";
        baseFileName = '${idPart}_$timestamp';
        print("FormSaverService: suggestedFileName был пуст, сгенерировано базовое имя: '$baseFileName'");
      }

      // Очистка базового имени файла (удаление недопустимых символов, замена пробелов)
      // ВАЖНО: скобки () и цифры должны быть разрешены для работы суффикса
      baseFileName = baseFileName
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') // Заменяем стандартные недопустимые символы
          .replaceAll(RegExp(r'\s+'), '_') // Заменяем пробелы на подчеркивания
          .replaceAll(RegExp(r'_+'), '_')   // Схлопываем множественные подчеркивания
          .trim()
          .replaceAll(RegExp(r'^_+|_+$'), ''); // Убираем подчеркивания в начале и конце

      // Если после очистки имя стало пустым или некорректным
      if (baseFileName.isEmpty || baseFileName == '_') {
        final now = DateTime.now();
        final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        baseFileName = "calculation_${timestamp}";
        print("FormSaverService: baseFileName после очистки стал некорректным, сгенерировано новое: '$baseFileName'");
      }

      // --- ЛОГИКА ГЕНЕРАЦИИ УНИКАЛЬНОГО ИМЕНИ ---
      String finalFileNameWithoutExtension = await _generateUniqueFileName(saveDir, baseFileName, '.json');
      // --- КОНЕЦ ЛОГИКИ ---

      String finalFileNameWithExtension = '$finalFileNameWithoutExtension.json';
      print("FormSaverService: Конечное уникальное имя файла для сохранения: '$finalFileNameWithExtension'");

      final String filePath = '${saveDir.path}/$finalFileNameWithExtension';
      final File file = File(filePath);

      final encoder = JsonEncoder.withIndent('  ');
      final String jsonString = encoder.convert(result.toJson());

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
