import 'dart:io'; // Для File, если понадобится проверка существования, хотя XFile это абстрагирует
import 'package:share_plus/share_plus.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart'; // Убедитесь, что путь правильный

class ShareService {
  /// Делится результатом расчета.
  ///
  /// Если [filePathToShare] предоставлен, делится указанным файлом.
  /// В противном случае, если [result] предоставлен, делится текстовым представлением результата.
  ///
  /// [defaultFileName] используется для формирования текста по умолчанию, если [result] недоступен,
  /// но [filePathToShare] есть (например, имя файла).
  Future<ShareResultStatus?> shareSingleCalculationResult({
    TraverseCalculationResult? result,
    String? filePathToShare,
    String? defaultFileName, // Используется, если result == null, но есть filePathToShare
  }) async {
    String shareText;
    String? subjectText;

    if (result != null) {
      shareText = 'Результаты расчета: ${result.calculationName ?? result.calculationId}';
      subjectText = 'Результаты расчета: ${result.calculationName ?? result.calculationId}';
    } else if (defaultFileName != null) {
      shareText = 'Файл расчета: $defaultFileName';
      subjectText = 'Файл расчета: $defaultFileName';
    } else {
      shareText = 'Результаты расчета'; // Общий текст по умолчанию
      subjectText = 'Результаты расчета';
    }

    if (filePathToShare != null) {
      // Проверяем, существует ли файл (опционально, но хорошая практика)
      final file = File(filePathToShare);
      if (!await file.exists()) {
        print('ShareService: Файл не найден по пути $filePathToShare');
        // Можно вернуть специальный статус или выбросить исключение,
        // чтобы UI мог это обработать
        return ShareResultStatus.unavailable; // Пример
      }
      final xFile = XFile(filePathToShare);
      final shareResult = await Share.shareXFiles([xFile], text: shareText, subject: subjectText);
      print('ShareService: shareXFiles result: ${shareResult.status}, raw: ${shareResult.raw}');
      return shareResult.status;
    } else if (result != null) {
      // Делимся текстовым представлением
      String summary = "Результаты расчета: ${result.calculationName ?? result.calculationId}\n"
          "Дата: ${result.calculationDate.toLocal().toString().split(' ')[0]}\n" // Только дата
          "Сумма длин: ${result.sumDistances} м\n"
          "Угловая невязка: ${result.angularMisclosure}° (Допустимо: ${result.isAngularOk ? 'Да' : 'Нет'})\n"
          "Линейная отн. невязка: 1/${(1 / result.linearMisclosureRelative).round()} (Допустимо: ${result.isLinearOk ? 'Да' : 'Нет'})";
      // Можно добавить еще деталей, если нужно

      final shareResult = await Share.share(summary, subject: subjectText);
      print('ShareService: share text result: ${shareResult.status}, raw: ${shareResult.raw}');
      return shareResult.status;
    } else {
      print('ShareService: Недостаточно данных для отправки (ни файла, ни результата).');
      return ShareResultStatus.unavailable; // Или другой подходящий статус
    }
  }

  /// Делится списком файлов.
  ///
  /// [filePaths] - список путей к файлам.
  /// [text] - опциональный сопроводительный текст.
  /// [subject] - опциональная тема (например, для email).
  Future<ShareResultStatus?> shareMultipleFiles({
    required List<String> filePaths,
    String? text,
    String? subject,
  }) async {
    if (filePaths.isEmpty) {
      print("ShareService: Нет файлов для отправки.");
      return ShareResultStatus.unavailable;
    }

    final List<XFile> filesToShare = [];
    for (String path in filePaths) {
      final file = File(path);
      if (await file.exists()) {
        filesToShare.add(XFile(path));
      } else {
        print('ShareService: Файл не найден и будет пропущен: $path');
      }
    }

    if (filesToShare.isEmpty) {
      print("ShareService: После проверки ни одного доступного файла для отправки не осталось.");
      return ShareResultStatus.unavailable;
    }

    final String defaultText = text ?? 'Выбранные файлы (${filesToShare.length} шт.)';
    final String defaultSubject = subject ?? 'Выбранные файлы';

    final shareResult = await Share.shareXFiles(
      filesToShare,
      text: defaultText,
      subject: defaultSubject,
    );
    print('ShareService: shareMultipleFiles result: ${shareResult.status}, raw: ${shareResult.raw}');
    return shareResult.status;
  }
}

