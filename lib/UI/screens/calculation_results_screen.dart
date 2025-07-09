import 'dart:convert'; // Для jsonEncode
import 'dart:io';     // Для File, Directory
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Для форматирования даты
import 'package:path_provider/path_provider.dart'; // Для getApplicationDocumentsDirectory
// Убедитесь, что пути импорта ВЕРНЫ для вашей структуры проекта
// Если модели в папке /models, то:
import 'package:traversemastery/models/traverse_calculation_result.dart';
import 'package:traversemastery/models/theodolite_station.dart';
// Если AppTheme определен и вы хотите его использовать для получения цветов:
// import 'package:traversemastery/themes/app_theme.dart'; // Пример

// --- Цвета из вашего app_theme.dart (предполагаемые значения) ---
// Лучше получать их из Theme.of(context).colorScheme, если AppTheme применен глобально.
// Но для прямого применения, как вы просили, используем константы:
const _primaryBlack = Color(0xFF121212); // scaffoldBackgroundColor, background
const _cardBlack = Color(0xFF1E1E1E);    // cardColor, appBar background
const _accentBlue = Colors.blueAccent;   // primary, accent
const _textOnPrimarySurface = Colors.white; // Для текста на _cardBlack или _accentBlue
const _textOnSurfaceSubtle = Colors.white70; // Для менее важного текста на _cardBlack
const _errorColor = Colors.redAccent;
const _successColor = Colors.greenAccent; // или Colors.green для лучшей читаемости
// const _secondaryAccent = Colors.tealAccent; // Если нужна вторая акцентная кнопка

class CalculationResultScreen extends StatefulWidget {
  final TraverseCalculationResult result;
  final String? suggestedFileName;

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

  Future<String?> _getAppDirectoryPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      print("Ошибка получения директории приложения: $e");
      return null;
    }
  }

  Future<void> _saveResultAsJson() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    String? appDirPath = await _getAppDirectoryPath();

    if (appDirPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _errorColor,
            content: Text('Не удалось определить путь для сохранения.', style: TextStyle(color: _textOnPrimarySurface)),
            behavior: SnackBarBehavior.floating, // Стиль для темной темы
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        );
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
      if (fileName.isEmpty || fileName.toLowerCase() == '.json') {
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final idPart = widget.result.calculationId.isNotEmpty && widget.result.calculationId.length >=8
            ? widget.result.calculationId.substring(0, 8)
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
      final String jsonString = jsonEncode(widget.result.toJson()); // Используем toJson из модели
      await file.writeAsString(jsonString);
      print('Файл успешно записан: $filePath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Результат сохранен: $fileName', style: const TextStyle(fontWeight: FontWeight.bold, color: _textOnPrimarySurface)),
                Text('Путь: ${file.path}', style: const TextStyle(fontSize: 12, color: _textOnPrimarySurface)),
              ],
            ),
            backgroundColor: Colors.green, // Для успеха
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        );
      }
    } catch (e, s) {
      print('Ошибка сохранения JSON: $e');
      print('Stack trace: $s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _errorColor,
            content: Text('Ошибка сохранения файла: ${e.toString().split(':').last.trim()}', style: const TextStyle(color: _textOnPrimarySurface)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // --- Вспомогательные функции форматирования (можно вынести, если используются еще где-то) ---
  String _formatDouble(double? value, {int fractionDigits = 2, String fallback = '—'}) {
    if (value == null) return fallback;
    return value.toStringAsFixed(fractionDigits);
  }

  String _formatAngle(double? value, {int fractionDigits = 4, String fallback = '—'}) {
    if (value == null) return fallback;
    return value.toStringAsFixed(fractionDigits);
  }

  String _formatRelativeError(double? value, {String fallback = "1/∞"}) {
    if (value == null || value == 0 || value.isInfinite || value.isNaN) return fallback;
    return '1/${(1 / value).round()}';
  }

  @override
  Widget build(BuildContext context) {
    // Если AppTheme применен в MaterialApp, можно использовать:
    // final theme = Theme.of(context);
    // final colorScheme = theme.colorScheme;
    // final textTheme = theme.textTheme;
    // И далее colorScheme.background, colorScheme.surface, colorScheme.primary и т.д.
    // Но для прямого соответствия запросу "подогнать под цвета" используем константы.

    final result = widget.result; // Для краткости

    return Scaffold(
      backgroundColor: _primaryBlack, // Фон страницы
      appBar: AppBar(
        title: Text(
          result.calculationName?.isNotEmpty == true ? result.calculationName! : 'Результаты расчета',
          // Стиль из AppTheme.darkTheme.appBarTheme.titleTextStyle или явно:
          style: const TextStyle(color: _textOnPrimarySurface, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _cardBlack, // Фон AppBar из вашей темы
        elevation: 0, // Как в вашей теме
        iconTheme: const IconThemeData(color: _accentBlue), // Цвет иконки "назад"
        actions: [
          _isSaving
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _textOnPrimarySurface),
            ),
          )
              : IconButton(
            icon: const Icon(Icons.save_alt_outlined, color: _accentBlue), // Акцентный цвет для иконки
            onPressed: _saveResultAsJson,
            tooltip: 'Сохранить результаты в JSON',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Растягиваем карточки по ширине
          children: <Widget>[
            _buildResultHeader(result),
            const SizedBox(height: 16),
            _buildAngularMisclosureCard(result),
            const SizedBox(height: 16),
            _buildLinearMisclosureCard(result),
            const SizedBox(height: 24),
            Text(
              'Данные по станциям (${result.stations.length} шт.):',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textOnPrimarySurface),
            ),
            const SizedBox(height: 8),
            _buildStationsDataTable(result.stations),
            const SizedBox(height: 24),
            // Пример кнопки "Поделиться", если нужна
            ElevatedButton.icon(
              icon: const Icon(Icons.share, color: _textOnPrimarySurface),
              label: const Text('Поделиться', style: TextStyle(color: _textOnPrimarySurface, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue, // Акцентный цвет для кнопки
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              onPressed: () {
                // TODO: Implement share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Функция "Поделиться" еще не реализована', style: TextStyle(color: _textOnPrimarySurface)),
                    backgroundColor: _cardBlack, // Фон SnackBar
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    action: SnackBarAction(label: 'OK', textColor: _accentBlue, onPressed: () {}),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(TraverseCalculationResult result) {
    return Card(
      color: _cardBlack, // Цвет фона карточки
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), // Скругление
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Внутренние отступы
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID расчета: ${result.calculationId}', style: const TextStyle(fontSize: 12, color: _textOnSurfaceSubtle)),
            Text('Дата расчета: ${DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(result.calculationDate)}', style: const TextStyle(fontSize: 12, color: _textOnSurfaceSubtle)),
            if (result.calculationName != null && result.calculationName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Имя: ${result.calculationName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textOnPrimarySurface)),
              ),
            const Divider(height: 20, color: _textOnSurfaceSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Сумма длин: ${_formatDouble(result.sumDistances)} м', style: const TextStyle(color: _textOnPrimarySurface)),
                Text('Σβ теор.: ${_formatAngle(result.sumTheoreticalAngles)}°', style: const TextStyle(color: _textOnPrimarySurface)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Σβ изм.: ${_formatAngle(result.sumMeasuredAngles)}°', style: const TextStyle(color: _textOnPrimarySurface)),
                Text('Σβ испр.: ${_formatAngle(result.sumCorrectedAngles)}°', style: const TextStyle(color: _textOnPrimarySurface)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngularMisclosureCard(TraverseCalculationResult result) {
    final statusColor = result.isAngularOk ? _successColor : _errorColor;
    final statusText = result.isAngularOk ? 'ДОПУСТИМО' : 'НЕ ДОПУСТИМО';

    return Card(
      color: _cardBlack,
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: statusColor.withOpacity(0.7), width: 1) // Обводка цветом статуса
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Угловая невязка (fβ)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textOnPrimarySurface)),
            const SizedBox(height: 10),
            _buildInfoRow('Факт.:', '${_formatAngle(result.angularMisclosure)}°'),
            _buildInfoRow('Допуст.:', '±${_formatAngle(result.permissibleAngularMisclosure)}°'),
            const SizedBox(height: 8),
            Text(
              'Статус: $statusText',
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinearMisclosureCard(TraverseCalculationResult result) {
    final statusColor = result.isLinearOk ? _successColor : _errorColor;
    final statusText = result.isLinearOk ? 'ДОПУСТИМО' : 'НЕ ДОПУСТИМО';

    return Card(
      color: _cardBlack,
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: statusColor.withOpacity(0.7), width: 1)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Линейная невязка', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textOnPrimarySurface)),
            const SizedBox(height: 10),
            _buildInfoRow('ΣΔX:', '${_formatDouble(result.sumDeltaX, fractionDigits: 3)} м'),
            _buildInfoRow('ΣΔY:', '${_formatDouble(result.sumDeltaY, fractionDigits: 3)} м'),
            const Divider(height: 15, color: _textOnSurfaceSubtle),
            _buildInfoRow('f абс.:', '${_formatDouble(result.linearMisclosureAbsolute, fractionDigits: 3)} м'),
            _buildInfoRow('f отн.:', _formatRelativeError(result.linearMisclosureRelative)),
            Padding( // Добавил отступ для "Допуст. отн."
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('Допуст. отн.: ${_formatRelativeError(result.permissibleLinearMisclosureRelative)}', style: const TextStyle(color: _textOnSurfaceSubtle, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            Text(
              'Статус: $statusText',
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный виджет для строк в карточках (label: value)
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: _textOnSurfaceSubtle),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15, // Немного уменьшил для консистентности
                fontWeight: FontWeight.w500, // Сделал чуть менее жирным, чем заголовки
                color: valueColor ?? _textOnPrimarySurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsDataTable(List<TheodoliteStation> stations) {
    if (stations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("Нет данных по станциям.", style: TextStyle(color: _textOnSurfaceSubtle))),
      );
    }

    final headerStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textOnPrimarySurface);
    final cellStyle = const TextStyle(fontSize: 13, color: _textOnSurfaceSubtle);

    bool hasDirAngles = stations.any((s) => s.directionAngle != null);
    bool hasDeltas = stations.any((s) => s.deltaX != null && s.deltaY != null);
    bool hasCoords = stations.any((s) => s.coordinateX != null && s.coordinateY != null);

    List<DataColumn> columns = [
      DataColumn(label: Text('Станция', style: headerStyle)),
      DataColumn(label: Text('Гор.угол\n(испр.) °', textAlign: TextAlign.center, style: headerStyle)),
      DataColumn(label: Text('Расст.\nм', textAlign: TextAlign.center, style: headerStyle)),
    ];
    if (hasDirAngles) columns.add(DataColumn(label: Text('Дир.угол\nα °', textAlign: TextAlign.center, style: headerStyle)));
    if (hasDeltas) {
      columns.add(DataColumn(label: Text('ΔX\nм', textAlign: TextAlign.center, style: headerStyle)));
      columns.add(DataColumn(label: Text('ΔY\nм', textAlign: TextAlign.center, style: headerStyle)));
    }
    if (hasCoords) {
      columns.add(DataColumn(label: Text('X\nм', textAlign: TextAlign.center, style: headerStyle)));
      columns.add(DataColumn(label: Text('Y\nм', textAlign: TextAlign.center, style: headerStyle)));
    }

    return Card(
      color: _cardBlack,
      elevation: 1.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias, // Чтобы DataTable не вылезал за скругленные углы
      child: SingleChildScrollView( // Для горизонтальной прокрутки, если колонок много
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12.0,
          headingRowHeight: 48.0,
          dataRowMinHeight: 40.0,
          dataRowMaxHeight: 44.0,
          border: TableBorder.all(width: 0.5, color: _textOnSurfaceSubtle.withOpacity(0.3)),
          headingTextStyle: headerStyle,
          columns: columns,
          rows: stations.map((station) {
            List<DataCell> cells = [
              DataCell(Text(station.stationName, style: cellStyle.copyWith(color: _textOnPrimarySurface, fontWeight: FontWeight.w500))),
              DataCell(Text(_formatAngle(station.horizontalAngle), style: cellStyle)),
              DataCell(Text(_formatDouble(station.distance), style: cellStyle)),
            ];
            if (hasDirAngles) cells.add(DataCell(Text(_formatAngle(station.directionAngle), style: cellStyle)));
            if (hasDeltas) {
              cells.add(DataCell(Text(_formatDouble(station.deltaX, fractionDigits: 3), style: cellStyle)));
              cells.add(DataCell(Text(_formatDouble(station.deltaY, fractionDigits: 3), style: cellStyle)));
            }
            if (hasCoords) {
              cells.add(DataCell(Text(_formatDouble(station.coordinateX, fractionDigits: 3), style: cellStyle)));
              cells.add(DataCell(Text(_formatDouble(station.coordinateY, fractionDigits: 3), style: cellStyle)));
            }
            return DataRow(cells: cells);
          }).toList(),
        ),
      ),
    );
  }
}

