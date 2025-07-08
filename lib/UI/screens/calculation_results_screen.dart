import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart';
import 'package:traversemastery/ui/widgets/result_display_widgets.dart';
import 'package:traversemastery/core/utils/angle_utils.dart';

class CalculationResultScreen extends StatelessWidget {
  final TraverseCalculationResult result;

  const CalculationResultScreen({super.key, required this.result});

  String _formatDouble(double? value, int fractionDigits, {String defaultValue = "-"}) {
    if (value == null || value.isNaN) return defaultValue;
    if (value.isInfinite) return "∞";
    return value.toStringAsFixed(fractionDigits);
  }

  // Новая функция для форматирования угла в ГГ°ММ'СС"
  String _formatAngleDMS(double? decimalDegrees) {
    if (decimalDegrees == null) return "-";
    return AngleDMS.fromDecimalDegrees(decimalDegrees).toString();
  }


  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormatter = DateFormat('dd.MM.yyyy HH:mm:ss');
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты расчета'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Поделиться результатом (в разработке)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Функция "Поделиться" в разработке!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Сохранить результат (в разработке)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Функция сохранения в разработке!')),
              );
            },
          ),
        ],
      ),
      body: Column(
          children: [
      Expanded(
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0).copyWith(bottom: 0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
      Center(
      child: Text(
          'Расчет выполнен: ${dateFormatter.format(result.calculationDate)}',
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    ),
    ),
    const SizedBox(height: 16),

    // Угловые невязки
    ResultSectionTitle(title: 'Угловые невязки'),
    ResultDataRow(label: 'Сумма измеренных углов (Σβ_изм):', value: _formatAngleDMS(result.sumMeasuredAngles)), // Используем _formatAngleDMS
    ResultDataRow(label: 'Теоретическая сумма углов (Σβ_теор):', value: _formatAngleDMS(result.theoreticalSumAngles)), // Используем _formatAngleDMS
    ResultDataRow(
    label: 'Угловая невязка (fβ):',
    value: _formatAngleDMS(result.angularMisclosure), // Используем _formatAngleDMS
    isGood: result.isAngularMisclosureAcceptable,
    ),
    ResultDataRow(label: 'Допустимая угловая невязка (fβ_доп):', value: '±${_formatAngleDMS(result.permissibleAngularMisclosure)}'), // Используем _formatAngleDMS
    ResultDataRow(
    label: 'Статус:',
    value: result.isAngularMisclosureAcceptable ? 'Допустима' : 'Недопустима',
    isGood: result.isAngularMisclosureAcceptable,
    icon: result.isAngularMisclosureAcceptable ? Icons.check_circle_outline : Icons.error_outline,
    ),
    const Divider(height: 24, thickness: 0.5),

    // Исправленные и дирекционные углы
    ResultSectionTitle(title: 'Исправленные и дирекционные углы'),
    if (result.inputStations.length == result.correctedAngles.length &&
    result.inputStations.length == result.directionAngles.length)
    DataTableWidget(
    columns: const ['Станция', 'β испр.', 'α дирекц.'], // Убрали градусы из заголовка, т.к. формат полный
    rows: List.generate(result.inputStations.length, (index) {
    return [
    result.inputStations[index].stationName.isEmpty ? 'Тчк. ${index + 1}' : result.inputStations[index].stationName,
    _formatAngleDMS(result.correctedAngles[index]), // Используем _formatAngleDMS
    _formatAngleDMS(result.directionAngles[index]),  // Используем _formatAngleDMS
    ];
    }),
    )
    else
    const Text("Ошибка: Несоответствие данных для отображения углов.", style: TextStyle(color: Colors.red)),
    const Divider(height: 24, thickness: 0.5),

    // Приращения координат и линейные невязки (остаются как есть)
    ResultSectionTitle(title: 'Приращения координат и линейные невязки'),
    ResultDataRow(label: 'Сумма ΔX (ΣΔx):', value: _formatDouble(result.sumDeltaX, 3)),
    ResultDataRow(label: 'Сумма ΔY (ΣΔy):', value: _formatDouble(result.sumDeltaY, 3)),
    ResultDataRow(label: 'Невязка по X (fx):', value: _formatDouble(result.linearMisclosureX, 3)),
    ResultDataRow(label: 'Невязка по Y (fy):', value: _formatDouble(result.linearMisclosureY, 3)),
    ResultDataRow(label: 'Абсолютная лин. невязка (f_абс):', value: _formatDouble(result.absoluteLinearMisclosure, 3)),
    ResultDataRow(
    label: 'Относительная лин. невязка (1:M):',
    value: (result.relativeLinearMisclosure.isInfinite || result.relativeLinearMisclosure.isNaN)
    ? '1 : ∞'
        : '1 : ${_formatDouble(result.relativeLinearMisclosure, 0)}',
    isGood: result.isLinearMisclosureAcceptable,
    ),
    ResultDataRow(
    label: 'Статус:',
    value: result.isLinearMisclosureAcceptable ? 'Допустима' : 'Недопустима',
    isGood: result.isLinearMisclosureAcceptable,
    icon: result.isLinearMisclosureAcceptable ? Icons.check_circle_outline : Icons.error_outline,
    ),
    const Divider(height: 24, thickness: 0.5),

    // Исправленные приращения и координаты точек (остаются как есть)
    ResultSectionTitle(title: 'Исправленные приращения и координаты точек'),
    if (result.calculatedCoordinates.isNotEmpty)
    DataTableWidget(
    columns: const ['Точка', 'ΔX испр. (м)', 'ΔY испр. (м)', 'Коорд. X (м)', 'Коорд. Y (м)'],
      rows: List.generate(result.calculatedCoordinates.length, (index) {
        String dx = "-";
        String dy = "-";
        if (index < result.correctedDeltaX.length) {
          dx = _formatDouble(result.correctedDeltaX[index], 3);
        }
        if (index < result.correctedDeltaY.length) {
          dy = _formatDouble(result.correctedDeltaY[index], 3);
        }
        return [
          result.calculatedCoordinates[index].stationName,
          dx,
          dy,
          _formatDouble(result.calculatedCoordinates[index].x, 3),
          _formatDouble(result.calculatedCoordinates[index].y, 3),
        ];
      }),
    )
    else
      const Text("Ошибка: Несоответствие данных для отображения координат.", style: TextStyle(color: Colors.red)),
          ],
      ),
      ),
      ),
            _buildBottomButton(context, theme),
          ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 12.0,
        bottom: MediaQuery.of(context).padding.bottom + 12.0,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.arrow_back),
        label: const Text('Новый расчет'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: theme.colorScheme.onSecondary,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
