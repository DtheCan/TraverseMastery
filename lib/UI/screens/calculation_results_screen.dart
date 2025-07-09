import 'dart:convert'; // Для jsonEncode
import 'dart:io';     // Для File, Directory
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // Для getApplicationDocumentsDirectory
// import 'package:permission_handler/permission_handler.dart'; // Если решите использовать для общих папок
// Убедитесь, что пути импорта ВЕРНЫ для вашей структуры проекта
import 'package:traversemastery/models/traverse_calculation_result.dart';
import 'package:traversemastery/models/theodolite_station.dart';

class CalculationResultScreen extends StatefulWidget {
  final TraverseCalculationResult result;
  final String? suggestedFileName; // Имя файла, предложенное с DataEntryScreen

  const CalculationResultScreen({
    super.key,
    required this.result,
    this.suggestedFileName,
  });

  @override
  State<CalculationResultScreen> createState() => _CalculationResultScreenState();
}

class _CalculationResultScreenState extends State<CalculationResultScreen> {
  bool _isSaving = false;

  // Запрос разрешений можно убрать, если сохраняем только в директорию приложения
  // (как это делается сейчас)
  /*
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Для API 30+ и записи в общие папки требуются другие подходы (SAF или All Files Access)
      // Для директории приложения разрешения обычно не нужны.
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
           print("Разрешение на доступ к хранилищу не предоставлено");
           // Можно показать пользователю сообщение о необходимости разрешения
        }
      }
    }
  }
  */

  Future<String?> _getAppDirectoryPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      print("Ошибка получения директории приложения: $e");
      // Можно показать SnackBar с ошибкой, если это критично для других функций
      return null;
    }
  }

  Future<void> _saveResultAsJson() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    // await _requestPermissions(); // Раскомментируйте, если будете сохранять в общие папки

    String? appDirPath;
    try {
      appDirPath = await _getAppDirectoryPath();
    } catch (e) {
      // Ошибка уже залогирована в _getAppDirectoryPath
    }

    if (appDirPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Не удалось определить путь для сохранения.')),
        );
      }
      if (mounted) {
        setState(() => _isSaving = false);
      }
      return;
    }

    try {
      final String saveDirPath = '$appDirPath/data/SavedCalculationResults';
      final Directory saveDir = Directory(saveDirPath);

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
        print('Создана директория: ${saveDir.path}');
      } else {
        print('Директория для сохранения уже существует: ${saveDir.path}');
      }

      String fileName = widget.suggestedFileName?.trim() ?? '';
      if (fileName.isEmpty || fileName.toLowerCase() == '.json') { // Проверка, что имя не пустое и не просто ".json"
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        // Используем calculationId, если он есть и не пустой, иначе - общий префикс
        final idPart = widget.result.calculationId.isNotEmpty && widget.result.calculationId.length >=8
            ? widget.result.calculationId.substring(0, 8)
            : "res";
        fileName = 'calc_${idPart}_$timestamp';
      }

      // Очистка имени файла от недопустимых символов и добавление расширения
      fileName = fileName
          .replaceAll(RegExp(r'[^\w\s\.-]'), '_') // Заменяем все, что не буква, цифра, пробел, точка или дефис на '_'
          .replaceAll(RegExp(r'\s+'), '_') // Заменяем пробелы на '_'
          .replaceAll('..', '_'); // Предотвращаем двойные точки

      if (!fileName.toLowerCase().endsWith('.json')) {
        fileName += '.json';
      }
      // Дополнительная проверка, если имя файла стало пустым после очистки
      if (fileName == '.json') {
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        fileName = 'calc_default_$timestamp.json';
      }


      final String filePath = '${saveDir.path}/$fileName';
      final File file = File(filePath);

      print('Попытка сохранения в файл: $filePath');

      final String jsonString = jsonEncode(widget.result.toJson());
      await file.writeAsString(jsonString);

      print('Файл успешно записан.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Результат сохранен: $fileName', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Путь: ${file.path}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, s) { // Добавил stackTrace для более детальной отладки
      print('Ошибка сохранения JSON: $e');
      print('Stack trace: $s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Ошибка сохранения файла: ${e.toString().split(':').last.trim()}')), // Более короткое сообщение об ошибке
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result; // Для краткости

    return Scaffold(
      appBar: AppBar(
        title: Text(result.calculationName?.isNotEmpty == true ? result.calculationName! : 'Результаты расчета'),
        centerTitle: true,
        actions: [
          _isSaving
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Отступы как в [1]
            child: SizedBox(
              width: 24, // Размеры как в [1]
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white), // strokeWidth как в [1]
            ),
          )
              : IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            onPressed: _saveResultAsJson,
            tooltip: 'Сохранить результаты в JSON',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildResultHeader(result),
            const SizedBox(height: 16),
            _buildAngularMisclosureCard(result),
            const SizedBox(height: 16),
            _buildLinearMisclosureCard(result),
            const SizedBox(height: 20),
            Text(
              'Данные по станциям (${result.stations.length} шт.):',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _buildStationsDataTable(result.stations),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(TraverseCalculationResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID расчета: ${result.calculationId}', style: Theme.of(context).textTheme.bodySmall),
            Text('Дата расчета: ${result.calculationDate.toLocal().toString().substring(0, 19)}', style: Theme.of(context).textTheme.bodySmall),
            if (result.calculationName != null && result.calculationName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Имя: ${result.calculationName}', style: Theme.of(context).textTheme.titleMedium),
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Сумма длин: ${result.sumDistances.toStringAsFixed(2)} м'),
                Text('Σβ теор.: ${result.sumTheoreticalAngles.toStringAsFixed(4)}°'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Σβ изм.: ${result.sumMeasuredAngles.toStringAsFixed(4)}°'),
                Text('Σβ испр.: ${result.sumCorrectedAngles.toStringAsFixed(4)}°'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngularMisclosureCard(TraverseCalculationResult result) {
    return Card(
      elevation: 2,
      color: result.isAngularOk ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Угловая невязка (fβ)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Факт.: ${result.angularMisclosure.toStringAsFixed(4)}°'),
                Text('Допуст.: ±${result.permissibleAngularMisclosure.toStringAsFixed(4)}°'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.isAngularOk ? 'Статус: ДОПУСТИМО' : 'Статус: НЕ ДОПУСТИМО',
              style: TextStyle(fontWeight: FontWeight.bold, color: result.isAngularOk ? Colors.green.shade700 : Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinearMisclosureCard(TraverseCalculationResult result) {
    return Card(
      elevation: 2,
      color: result.isLinearOk ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Линейная невязка', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ΣΔX: ${result.sumDeltaX.toStringAsFixed(3)} м'), // Точность из [1]
                Text('ΣΔY: ${result.sumDeltaY.toStringAsFixed(3)} м'), // Точность из [1]
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('f_абс.: ${result.linearMisclosureAbsolute.toStringAsFixed(3)} м'), // Точность из [1]
                // Более надежное округление для относительной невязки
                Text('f_отн.: 1/${result.linearMisclosureRelative != 0 ? (1 / result.linearMisclosureRelative).round() : "∞"}'),
              ],
            ),
            const SizedBox(height: 4),
            Text('Допуст. отн.: 1/${result.permissibleLinearMisclosureRelative != 0 ? (1 / result.permissibleLinearMisclosureRelative).round() : "∞"}'),
            const SizedBox(height: 4),
            Text(
              result.isLinearOk ? 'Статус: ДОПУСТИМО' : 'Статус: НЕ ДОПУСТИМО',
              style: TextStyle(fontWeight: FontWeight.bold, color: result.isLinearOk ? Colors.green.shade700 : Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsDataTable(List<TheodoliteStation> stations) {
    if (stations.isEmpty) {
      return const Text("Нет данных по станциям для отображения.");
    }
    // Определяем, какие колонки показывать на основе наличия данных хотя бы у одной станции
    bool hasDirAngles = stations.any((s) => s.directionAngle != null);
    bool hasDeltas = stations.any((s) => s.deltaX != null && s.deltaY != null);
    bool hasCoords = stations.any((s) => s.coordinateX != null && s.coordinateY != null);

    List<DataColumn> columns = [
      const DataColumn(label: Text('Станция', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Гор.угол\n(испр.) °', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Расст.\nм', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
    ];
    if (hasDirAngles) columns.add(const DataColumn(label: Text('Дир.угол\nα °', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))));
    if (hasDeltas) {
      columns.add(const DataColumn(label: Text('ΔX\nм', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))));
      columns.add(const DataColumn(label: Text('ΔY\nм', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))));
    }
    if (hasCoords) {
      columns.add(const DataColumn(label: Text('X\nм', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))));
      columns.add(const DataColumn(label: Text('Y\nм', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12.0, // Из [1]
        headingRowHeight: 40.0, // Из [1]
        dataRowMinHeight: 38.0, // Из [1]
        dataRowMaxHeight: 42.0, // Из [1]
        border: TableBorder.all(width: 1.0, color: Colors.grey.shade300), // Из [1]
        columns: columns,
        rows: stations.map((station) {
          List<DataCell> cells = [
            DataCell(Text(station.stationName)),
            DataCell(Text(station.horizontalAngle?.toStringAsFixed(4) ?? '—')), // Точность из [1]
            DataCell(Text(station.distance?.toStringAsFixed(2) ?? '—')),      // Точность из [1]
          ];
          if (hasDirAngles) cells.add(DataCell(Text(station.directionAngle?.toStringAsFixed(4) ?? '—'))); // Точность из [1]
          if (hasDeltas) {
            cells.add(DataCell(Text(station.deltaX?.toStringAsFixed(3) ?? '—'))); // Точность из [1]
            cells.add(DataCell(Text(station.deltaY?.toStringAsFixed(3) ?? '—'))); // Точность из [1]
          }
          if (hasCoords) {
            cells.add(DataCell(Text(station.coordinateX?.toStringAsFixed(3) ?? '—'))); // Точность из [1]
            cells.add(DataCell(Text(station.coordinateY?.toStringAsFixed(3) ?? '—'))); // Точность из [1]
          }
          return DataRow(cells: cells);
        }).toList(),
      ),
    );
  }
}
