import 'package:flutter/material.dart'; // Для BuildContext и SnackBar, если нужно
import 'package:share_plus/share_plus.dart'; // Добавьте в pubspec.yaml: share_plus: ^latest_version
import 'package:traversemastery/models/traverse_calculation_result.dart';

// --- Цвета для SnackBar ---
// const _cardBlack = Color(0xFF1E1E1E);
// const _accentBlue = Colors.blueAccent;
// const _textOnPrimarySurface = Colors.white;

class ShareService {
  Future<void> shareCalculationResult(
      BuildContext context, // Нужен для SnackBar и потенциально для Share
      TraverseCalculationResult result, {
        String? filePathToShare, // Если хотим поделиться сохраненным файлом
      }) async {
    // TODO: Реализовать логику "Поделиться"
    // Пример: Поделиться текстовым представлением результата
    // Либо, если filePathToShare не null, поделиться файлом

    if (filePathToShare != null) {
      // Если есть путь к файлу, делимся файлом
      // Убедитесь, что файл существует и доступен
      final XFile file = XFile(filePathToShare);
      await Share.shareXFiles([file], text: 'Результаты расчета: ${result.calculationName ?? result.calculationId}');
    } else {
      // Делимся текстовым представлением (простой пример)
      String summary = "Результаты расчета: ${result.calculationName ?? result.calculationId}\n"
          "Дата: ${result.calculationDate.toLocal()}\n"
          "Сумма длин: ${result.sumDistances} м\n"
      // Добавьте другие важные поля
          "Угловая невязка: ${result.angularMisclosure}° (Допустимо: ${result.isAngularOk})\n"
          "Линейная отн. невязка: 1/${(1 / result.linearMisclosureRelative).round()} (Допустимо: ${result.isLinearOk})";

      await Share.share(summary, subject: 'Результаты расчета: ${result.calculationName ?? result.calculationId}');
    }

    // Пример SnackBar, если нужно
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: const Text('Функция "Поделиться" еще не реализована или выполнена', style: TextStyle(color: _textOnPrimarySurface)),
    //     backgroundColor: _cardBlack,
    //     behavior: SnackBarBehavior.floating,
    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    //     action: SnackBarAction(label: 'OK', textColor: _accentBlue, onPressed: () {}),
    //   ),
    // );
  }
}
