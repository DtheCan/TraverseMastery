import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Модели
import 'package:traversemastery/models/traverse_calculation_result.dart';
import 'package:traversemastery/models/theodolite_station.dart';
// Сервисы
import 'package:traversemastery/core/services/forms_saver.dart'; // <--- Импорт сервиса сохранения
import 'package:traversemastery/core/services/share_service.dart';   // <--- Импорт сервиса "Поделиться"

// Цвета (можете вынести в app_theme.dart и импортировать оттуда)
const _primaryBlack = Color(0xFF121212);
const _cardBlack = Color(0xFF1E1E1E);
const _accentBlue = Colors.blueAccent;
const _textOnPrimarySurface = Colors.white;
const _textOnSurfaceSubtle = Colors.white70;
const _errorColor = Colors.redAccent;
const _successColor = Colors.greenAccent;


class CalculationResultScreen extends StatefulWidget {
  final TraverseCalculationResult result;
  final String? suggestedFileName; // Это может быть полезно для FormSaverService

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
  // String? _lastSavedFilePath; // Для передачи в ShareService, если нужно

  final FormSaverService _formSaverService = FormSaverService();
  final ShareService _shareService = ShareService();

  Future<void> _handleSaveResult() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final filePath = await _formSaverService.saveCalculationResult(
      result: widget.result,
      suggestedFileName: widget.suggestedFileName,
    );

    if (mounted) {
      if (filePath != null) {
        // Получаем только имя файла из полного пути
        String fileName = filePath.split('/').last;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min, // Чтобы Column занимал минимально необходимую высоту
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Файл: $fileName', // Первая строка
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _textOnPrimarySurface),
                ),
                const Text(
                  'сохранен в хранилище', // Вторая строка
                  style: TextStyle(fontSize: 13, color: _textOnPrimarySurface), // Можно немного изменить стиль для второй строки
                ),
              ],
            ),
            backgroundColor: Colors.green, // Используйте ваш _successColor, если он определен
            duration: const Duration(seconds: 4), // Длительность можно настроить
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _errorColor, // Используйте ваш _errorColor
            content: Text('Ошибка сохранения файла.', style: TextStyle(color: _textOnPrimarySurface)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  Future<void> _handleShareResult() async {
    // Если вы хотите дать возможность поделиться последним сохраненным файлом:
    // String? filePathToShare = _lastSavedFilePath;
    // if (filePathToShare == null) {
    //   // Если файл не был сохранен, или мы хотим всегда делиться текстовым представлением
    //   // или дать выбор, можно сначала сохранить временный файл и поделиться им.
    //   // Пока что просто делимся текстовым представлением или последним сохраненным.
    // }
    // Для простоты, сначала сохраним (если еще не сохранено), а потом поделимся файлом
    // Либо можно просто делиться текстовым представлением из ShareService

    // Вариант 1: Поделиться текстовым представлением
    // await _shareService.shareCalculationResult(context, widget.result);

    // Вариант 2: Сначала сохранить, потом поделиться файлом (если еще не сохранено)
    // Либо использовать _lastSavedFilePath, если он есть
    // Для этого примера, давайте предположим, что мы хотим иметь возможность
    // поделиться файлом, если он был сохранен.
    // Для простоты, здесь мы можем вызвать сохранение, если это еще не сделано,
    // или использовать уже сохраненный.
    // Пока что вызовем shareCalculationResult без filePathToShare,
    // он сам решит, как делиться.
    // Чтобы поделиться именно файлом, сначала его нужно сохранить и получить путь.
    // Можно сначала сохранить, а потом поделиться, либо делиться только текстом.

    // Пока что просто вызовем, ShareService сам решит как (текстом или файлом, если передан путь)
    await _shareService.shareCalculationResult(context, widget.result /*, filePathToShare: _lastSavedFilePath */);
  }


  // --- Вспомогательные функции форматирования и виджеты отображения (остаются здесь) ---
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
    final result = widget.result;

    return Scaffold(
      backgroundColor: _primaryBlack,
      appBar: AppBar(
        title: Text(
          result.calculationName?.isNotEmpty == true ? result.calculationName! : 'Результаты расчета',
          style: const TextStyle(color: _textOnPrimarySurface, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _cardBlack,
        elevation: 0,
        // Кнопка "назад" будет добавлена автоматически, если экран был открыт через Navigator.push
        // iconTheme: const IconThemeData(color: _accentBlue), // Для кастомизации цвета иконки "назад"
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 30), // Отступ перед кнопками
          ],
        ),
      ),
      // Используем bottomNavigationBar для трех кнопок внизу
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12), // Отступ снизу с учетом safe area
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share, color: _textOnPrimarySurface),
                label: const Text('Поделиться', style: TextStyle(color: _textOnPrimarySurface)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                onPressed: _handleShareResult,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _textOnPrimarySurface))
                    : const Icon(Icons.save_alt_outlined, color: _textOnPrimarySurface),
                label: Text(_isSaving ? 'Сохр...' : 'Сохранить', style: const TextStyle(color: _textOnPrimarySurface)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Другой цвет для кнопки Сохранить
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                onPressed: _isSaving ? null : _handleSaveResult,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (виджеты _buildResultHeader, _buildAngularMisclosureCard, _buildLinearMisclosureCard, _buildInfoRow, _buildStationsDataTable остаются здесь без изменений) ...
  // Копипаст этих виджетов из вашего предыдущего кода calculation_results_screen.dart
  Widget _buildResultHeader(TraverseCalculationResult result) {
    return Card(
      color: _cardBlack, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Сумма длин: ${_formatDouble(result.sumDistances)} м', style: const TextStyle(color: _textOnPrimarySurface)),
              Text('Σβ теор.: ${_formatAngle(result.sumTheoreticalAngles)}°', style: const TextStyle(color: _textOnPrimarySurface)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Σβ изм.: ${_formatAngle(result.sumMeasuredAngles)}°', style: const TextStyle(color: _textOnPrimarySurface)),
              Text('Σβ испр.: ${_formatAngle(result.sumCorrectedAngles)}°', style: const TextStyle(color: _textOnPrimarySurface)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildAngularMisclosureCard(TraverseCalculationResult result) {
    final statusColor = result.isAngularOk ? _successColor : _errorColor;
    final statusText = result.isAngularOk ? 'ДОПУСТИМО' : 'НЕ ДОПУСТИМО';
    return Card(
      color: _cardBlack, elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: statusColor.withOpacity(0.7), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Угловая невязка (fβ)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textOnPrimarySurface)),
          const SizedBox(height: 10),
          _buildInfoRow('Факт.:', '${_formatAngle(result.angularMisclosure)}°'),
          _buildInfoRow('Допуст.:', '±${_formatAngle(result.permissibleAngularMisclosure)}°'),
          const SizedBox(height: 8),
          Text('Статус: $statusText', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15)),
        ]),
      ),
    );
  }

  Widget _buildLinearMisclosureCard(TraverseCalculationResult result) {
    final statusColor = result.isLinearOk ? _successColor : _errorColor;
    final statusText = result.isLinearOk ? 'ДОПУСТИМО' : 'НЕ ДОПУСТИМО';
    return Card(
      color: _cardBlack, elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: statusColor.withOpacity(0.7), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Линейная невязка', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textOnPrimarySurface)),
          const SizedBox(height: 10),
          _buildInfoRow('ΣΔX:', '${_formatDouble(result.sumDeltaX, fractionDigits: 3)} м'),
          _buildInfoRow('ΣΔY:', '${_formatDouble(result.sumDeltaY, fractionDigits: 3)} м'),
          const Divider(height: 15, color: _textOnSurfaceSubtle),
          _buildInfoRow('f абс.:', '${_formatDouble(result.linearMisclosureAbsolute, fractionDigits: 3)} м'),
          _buildInfoRow('f отн.:', _formatRelativeError(result.linearMisclosureRelative)),
          Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Допуст. отн.: ${_formatRelativeError(result.permissibleLinearMisclosureRelative)}', style: const TextStyle(color: _textOnSurfaceSubtle, fontSize: 15))),
          const SizedBox(height: 8),
          Text('Статус: $statusText', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15)),
        ]),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 15, color: _textOnSurfaceSubtle)),
        const SizedBox(width: 16),
        Expanded(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: valueColor ?? _textOnPrimarySurface))),
      ]),
    );
  }

  Widget _buildStationsDataTable(List<TheodoliteStation> stations) {
    if (stations.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("Нет данных по станциям.", style: TextStyle(color: _textOnSurfaceSubtle))));
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
    if (hasDeltas) { columns.add(DataColumn(label: Text('ΔX\nм', textAlign: TextAlign.center, style: headerStyle))); columns.add(DataColumn(label: Text('ΔY\nм', textAlign: TextAlign.center, style: headerStyle))); }
    if (hasCoords) { columns.add(DataColumn(label: Text('X\nм', textAlign: TextAlign.center, style: headerStyle))); columns.add(DataColumn(label: Text('Y\nм', textAlign: TextAlign.center, style: headerStyle))); }
    return Card(
      color: _cardBlack, elevation: 1.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), margin: const EdgeInsets.symmetric(vertical: 8.0), clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12.0, headingRowHeight: 48.0, dataRowMinHeight: 40.0, dataRowMaxHeight: 44.0, border: TableBorder.all(width: 0.5, color: _textOnSurfaceSubtle.withOpacity(0.3)), headingTextStyle: headerStyle,
          columns: columns,
          rows: stations.map((station) {
            List<DataCell> cells = [
              DataCell(Text(station.stationName, style: cellStyle.copyWith(color: _textOnPrimarySurface, fontWeight: FontWeight.w500))),
              DataCell(Text(_formatAngle(station.horizontalAngle), style: cellStyle)),
              DataCell(Text(_formatDouble(station.distance), style: cellStyle)),
            ];
            if (hasDirAngles) cells.add(DataCell(Text(_formatAngle(station.directionAngle), style: cellStyle)));
            if (hasDeltas) { cells.add(DataCell(Text(_formatDouble(station.deltaX, fractionDigits: 3), style: cellStyle))); cells.add(DataCell(Text(_formatDouble(station.deltaY, fractionDigits: 3), style: cellStyle))); }
            if (hasCoords) { cells.add(DataCell(Text(_formatDouble(station.coordinateX, fractionDigits: 3), style: cellStyle))); cells.add(DataCell(Text(_formatDouble(station.coordinateY, fractionDigits: 3), style: cellStyle))); }
            return DataRow(cells: cells);
          }).toList(),
        ),
      ),
    );
  }
}

