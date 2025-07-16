// lib/ui/widgets/theodolite_form.dart
import 'dart:async'; // Понадобится, если решим делать сброс по таймеру позже
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/full_traverse_input.dart';
import 'package:uuid/uuid.dart';
import 'package:traversemastery/core/services/forms_saver.dart';

const _uuid = Uuid();

class _StationInputRow {
  final String id;
  final TextEditingController nameController;
  final TextEditingController angleDegreesController;
  final TextEditingController angleMinutesController;
  final TextEditingController angleSecondsController;
  final TextEditingController distanceController;

  final FocusNode nameFocusNode;
  final FocusNode angleDegreesFocusNode;
  final FocusNode angleMinutesFocusNode;
  final FocusNode angleSecondsFocusNode;
  final FocusNode distanceFocusNode;

  _StationInputRow()
      : id = _uuid.v4(),
        nameController = TextEditingController(),
        angleDegreesController = TextEditingController(),
        angleMinutesController = TextEditingController(),
        angleSecondsController = TextEditingController(),
        distanceController = TextEditingController(),
        nameFocusNode = FocusNode(),
        angleDegreesFocusNode = FocusNode(),
        angleMinutesFocusNode = FocusNode(),
        angleSecondsFocusNode = FocusNode(),
        distanceFocusNode = FocusNode();

  void dispose() {
    nameController.dispose();
    angleDegreesController.dispose();
    angleMinutesController.dispose();
    angleSecondsController.dispose();
    distanceController.dispose();

    nameFocusNode.dispose();
    angleDegreesFocusNode.dispose();
    angleMinutesFocusNode.dispose();
    angleSecondsFocusNode.dispose();
    distanceFocusNode.dispose();
  }

  double? getAngleAsDecimalDegrees() {
    final g = int.tryParse(angleDegreesController.text);
    final m = int.tryParse(angleMinutesController.text);
    final s = double.tryParse(angleSecondsController.text.replaceAll(',', '.'));

    if (g == null || m == null || s == null) return null;
    // Валидаторы в TextFormField должны отловить более конкретные ошибки диапазона
    if (g < 0 || g >= 360 || m < 0 || m >= 60 || s < 0 || s >= 60) return null;
    return g + (m / 60.0) + (s / 3600.0);
  }
}

class TheodoliteForm extends StatefulWidget {
  final Function(FullTraverseInput fullInput) onSubmit;

  const TheodoliteForm({
    super.key,
    required this.onSubmit,
  });

  @override
  TheodoliteFormStateImplementation createState() => TheodoliteFormStateImplementation();
}

class TheodoliteFormStateImplementation extends State<TheodoliteForm> {
  final _initialDataFormKey = GlobalKey<FormState>();
  final _stationsFormKey = GlobalKey<FormState>();

  final TextEditingController _calculationNameController = TextEditingController();
  final TextEditingController _initialXController = TextEditingController();
  final TextEditingController _initialYController = TextEditingController();
  final TextEditingController _initialAzimuthController = TextEditingController();

  final List<_StationInputRow> _stationRows = [];
  final ScrollController _scrollController = ScrollController();
  static const int _minStationsForClosedTraverse = 3; // Минимальное количество станций

  // Флаг, указывающий, была ли попытка отправки формы.
  // Используется, чтобы валидаторы знали, когда показывать ошибку "обязательного поля".
  bool _formSubmittedAttempt = false;

  @override
  void initState() {
    super.initState();
    _initialXController.text = "1000.0";
    _initialYController.text = "1000.0";
    _initialAzimuthController.text = "0.0";
    _calculationNameController.text = "Новый расчет ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}";

    for (int i = 0; i < 1; i++) { // Начнем с одной станции для примера
      _addStationRowInternal(initialAdd: true);
    }
  }

  @override
  void dispose() {
    _calculationNameController.dispose();
    _initialXController.dispose();
    _initialYController.dispose();
    _initialAzimuthController.dispose();
    for (var row in _stationRows) {
      row.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addStationRowInternal({bool requestFocus = false, bool initialAdd = false}) {
    setState(() {
      _stationRows.add(_StationInputRow());
    });
    if (!initialAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        if (requestFocus && _stationRows.isNotEmpty && _stationRows.last.nameFocusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(_stationRows.last.nameFocusNode);
        }
      });
    }
  }

  void _removeStationRow(int index) {
    if (_stationRows.length <= 1 && _minStationsForClosedTraverse > 1) { // Не даем удалить последнюю, если нужна хотя бы одна
      _showErrorSnackBar('Требуется хотя бы одна станция.');
      return;
    }
    if (_stationRows.length <= _minStationsForClosedTraverse && index < _minStationsForClosedTraverse) {
      _showErrorSnackBar('Необходимо минимум $_minStationsForClosedTraverse станции для расчета.');
      return;
    }

    setState(() {
      final row = _stationRows.removeAt(index);
      row.dispose();
      // Если форма была отправлена, и мы удаляем строку, которая могла быть ошибочной,
      // стоит перевалидировать форму станций, чтобы убрать возможные общие ошибки.
      if(_formSubmittedAttempt) {
        _stationsFormKey.currentState?.validate();
      }
    });
  }

  // --- Валидаторы ---
  // Общий принцип:
  // - Если _formSubmittedAttempt == true, то пустое значение это ошибка "Введите...".
  // - Иначе, пустое значение это не ошибка (null).
  // - Непустое значение валидируется на формат/диапазон как обычно.

  String? _validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return _formSubmittedAttempt ? '$fieldName: введите значение' : null;
    }
    return null; // Дополнительные проверки имени, если нужны
  }


  String? _validateInitialNumberInput(String? value, String fieldName, {bool allowZero = false, bool allowNegative = false}) {
    if (value == null || value.isEmpty) {
      return _formSubmittedAttempt ? '$fieldName: введите значение' : null;
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) return '$fieldName: некорректное число';
    if (!allowZero && number == 0 && !fieldName.toLowerCase().contains("азимут")) return '$fieldName: не может быть 0';
    if (!allowNegative && number < 0) return '$fieldName: не может быть < 0';
    if (fieldName.toLowerCase().contains("азимут") && (number < 0 || number >= 360)) return '$fieldName: от 0 до 359.99...';
    return null;
  }

  String? _validateDegrees(String? value) {
    if (value == null || value.isEmpty) return _formSubmittedAttempt ? 'Введите °' : null;
    final val = int.tryParse(value);
    if (val == null) return 'Не число';
    if (val < 0 || val >= 360) return '0-359';
    return null;
  }

  String? _validateMinutes(String? value) {
    if (value == null || value.isEmpty) return _formSubmittedAttempt ? 'Введите ′' : null;
    final val = int.tryParse(value);
    if (val == null) return 'Не число';
    if (val < 0 || val >= 60) return '0-59';
    return null;
  }

  String? _validateSeconds(String? value) {
    if (value == null || value.isEmpty) return _formSubmittedAttempt ? 'Введите ″' : null;
    final val = double.tryParse(value.replaceAll(',', '.'));
    if (val == null) return 'Не число';
    if (val < 0 || val >= 60) return '0-59.9..';
    return null;
  }

  String? _validateDistance(String? value) {
    if (value == null || value.isEmpty) return _formSubmittedAttempt ? 'Введите расст.' : null;
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) return 'Не число';
    if (number <= 0) return '> 0';
    return null;
  }
  // --- Конец Валидаторов ---

  void _handleSubmit() {
    FocusScope.of(context).unfocus();
    setState(() {
      _formSubmittedAttempt = true; // Устанавливаем флаг перед валидацией
    });

    bool initialDataValid = _initialDataFormKey.currentState?.validate() ?? false;
    bool stationsDataValid = _stationsFormKey.currentState?.validate() ?? false;

    if (!initialDataValid) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в начальных данных.');
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    if (!stationsDataValid) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в данных станций.');
      // Может потребоваться прокрутка к первой ошибочной станции, если это возможно определить
      return;
    }

    // Сброс флага после успешной валидации (или если не хотим, чтобы он влиял на AutovalidateMode после сабмита)
    // setState(() { _formSubmittedAttempt = false; }); // Раскомментировать, если нужно сбрасывать

    final double initialX = double.parse(_initialXController.text.replaceAll(',', '.'));
    final double initialY = double.parse(_initialYController.text.replaceAll(',', '.'));
    final double initialAzimuth = double.parse(_initialAzimuthController.text.replaceAll(',', '.'));
    final String calculationName = _calculationNameController.text.trim();

    List<TheodoliteStation> stations = [];
    for (int i = 0; i < _stationRows.length; i++) {
      final row = _stationRows[i];
      final String stationNameText = row.nameController.text.trim();
      final double? angleDecimal = row.getAngleAsDecimalDegrees();
      final double? distanceValue = double.tryParse(row.distanceController.text.replaceAll(',', '.'));

      // Дополнительная проверка, хотя валидаторы формы должны были это отловить
      if (stationNameText.isEmpty || angleDecimal == null || distanceValue == null) {
        _showErrorSnackBar('Обнаружены незаполненные или некорректные поля в станции ${i + 1}.');
        return;
      }

      stations.add(TheodoliteStation(
        id: row.id,
        stationName: stationNameText,
        horizontalAngle: angleDecimal,
        distance: distanceValue,
      ));
    }

    if (stations.length < _minStationsForClosedTraverse) {
      _showErrorSnackBar('Необходимо минимум $_minStationsForClosedTraverse станции для расчета.');
      return;
    }

    final fullInput = FullTraverseInput(
      calculationName: calculationName.isNotEmpty ? calculationName : "Расчет от ${DateTime.now().toIso8601String()}",
      initialX: initialX,
      initialY: initialY,
      initialAzimuth: initialAzimuth,
      stations: stations,
    );
    widget.onSubmit(fullInput);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _fieldSubmitted(FocusNode currentFocus, FocusNode? nextFocus) {
    currentFocus.unfocus();
    if (nextFocus != null && nextFocus.canRequestFocus) {
      FocusScope.of(context).requestFocus(nextFocus);
    }
  }

  void _onDistanceSubmitted(int index) {
    _stationRows[index].distanceFocusNode.unfocus();
    // Валидируем текущую строку перед добавлением новой или переходом
    // Это больше для UX, основная валидация при _handleSubmit
    // bool currentRowValid = true; // Логика для валидации одной строки (может быть сложной)
    // if (currentRowValid) { ... }


    if (index == _stationRows.length - 1) {
      // Если _formSubmittedAttempt = true, то и новая строка будет сразу валидироваться на пустоту,
      // что может быть нежелательно. Поэтому здесь просто добавляем.
      _addStationRowInternal(requestFocus: true);
    } else {
      if (_stationRows[index + 1].nameFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_stationRows[index + 1].nameFocusNode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInitialDataSection(),
          const SizedBox(height: 16),
          const SizedBox(height: 10),
          Text(
            "Данные теодолитного хода:",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildStationsSection(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Рассчитать ход'),
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInitialDataSection() {
    return Form(
      key: _initialDataFormKey,
      // autovalidateMode: AutovalidateMode.onUserInteraction, // Можно включить, если нужно для всех полей секции
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Начальные данные:", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _calculationNameController,
            decoration: const InputDecoration(
                labelText: 'Имя Файла', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
            textCapitalization: TextCapitalization.sentences,
            // validator: (val) => _validateName(val, "Имя расчета"), // Имя расчета обычно опционально
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: _initialXController,
                    decoration: const InputDecoration(
                        labelText: 'Начальный X', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]+'))],
                    validator: (v) => _validateInitialNumberInput(v, "Нач. X", allowZero: true, allowNegative: true),
                    autovalidateMode: AutovalidateMode.onUserInteraction)),
            const SizedBox(width: 12),
            Expanded(
                child: TextFormField(
                    controller: _initialYController,
                    decoration: const InputDecoration(
                        labelText: 'Начальный Y', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]+'))],
                    validator: (v) => _validateInitialNumberInput(v, "Нач. Y", allowZero: true, allowNegative: true),
                    autovalidateMode: AutovalidateMode.onUserInteraction)),
          ]),
          const SizedBox(height: 12),
          TextFormField(
              controller: _initialAzimuthController,
              decoration: const InputDecoration(
                  labelText: 'Начальный дирекционный угол (°)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+'))],
              validator: (v) => _validateInitialNumberInput(v, "Нач. азимут", allowZero: true),
              autovalidateMode: AutovalidateMode.onUserInteraction),
        ],
      ),
    );
  }

  Widget _buildStationsSection() {
    return Form(
      key: _stationsFormKey,
      // autovalidateMode: AutovalidateMode.onUserInteraction, // Включаем для всех полей в этой форме
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._stationRows.asMap().entries.map((entry) {
            int index = entry.key;
            _StationInputRow row = entry.value;
            return _buildStationInputRow(row, index);
          }).toList(),
          const SizedBox(height: 12),
          TextButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Добавить станцию'),
              onPressed: () => _addStationRowInternal(requestFocus: true),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10))),
        ],
      ),
    );
  }

  Widget _buildStationInputRow(_StationInputRow row, int index) {
    FocusNode? nextFocusAfterSeconds = row.distanceFocusNode;
    FocusNode? nextFocusAfterDistance;
    if (index + 1 < _stationRows.length) {
      nextFocusAfterDistance = _stationRows[index + 1].nameFocusNode;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Станция ${index + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              // Кнопка удаления активна только если станций больше минимально разрешенного ИЛИ если это не "обязательная" по счету станция
              if (_stationRows.length > _minStationsForClosedTraverse || index >= _minStationsForClosedTraverse)
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () => _removeStationRow(index),
                    tooltip: 'Удалить станцию ${index + 1}',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20)
              else if (_stationRows.length > 1) // Позволяем удалить, если станций > 1, даже если < min, но не первую из min
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () => _removeStationRow(index),
                    tooltip: 'Удалить станцию ${index + 1}',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              controller: row.nameController,
              focusNode: row.nameFocusNode,
              decoration: const InputDecoration(
                  labelText: 'Имя станции', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (val) => _validateName(val, "Имя станции"), // Используем общий валидатор имени
              onFieldSubmitted: (_) => _fieldSubmitted(row.nameFocusNode, row.angleDegreesFocusNode),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 12),
            Text("Горизонтальный угол:", style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: TextFormField(
                      controller: row.angleDegreesController,
                      focusNode: row.angleDegreesFocusNode,
                      decoration: const InputDecoration(labelText: 'Градусы°', border: OutlineInputBorder(), helperText: " "),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                      validator: _validateDegrees,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _fieldSubmitted(row.angleDegreesFocusNode, row.angleMinutesFocusNode),
                      autovalidateMode: AutovalidateMode.onUserInteraction)),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                      controller: row.angleMinutesController,
                      focusNode: row.angleMinutesFocusNode,
                      decoration: const InputDecoration(labelText: 'Минуты′', border: OutlineInputBorder(), helperText: " "),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                      validator: _validateMinutes,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _fieldSubmitted(row.angleMinutesFocusNode, row.angleSecondsFocusNode),
                      autovalidateMode: AutovalidateMode.onUserInteraction)),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                      controller: row.angleSecondsController,
                      focusNode: row.angleSecondsFocusNode,
                      decoration: const InputDecoration(labelText: 'Секунды″', border: OutlineInputBorder(), helperText: " "),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+')), LengthLimitingTextInputFormatter(5)],
                      validator: _validateSeconds,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _fieldSubmitted(row.angleSecondsFocusNode, nextFocusAfterSeconds),
                      autovalidateMode: AutovalidateMode.onUserInteraction)),
            ]),
            const SizedBox(height: 10),
            TextFormField(
                controller: row.distanceController,
                focusNode: row.distanceFocusNode,
                decoration: const InputDecoration(
                    labelText: 'Расстояние (м)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), helperText: " "),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+'))],
                validator: _validateDistance,
                textInputAction: nextFocusAfterDistance == null ? TextInputAction.done : TextInputAction.next,
                onFieldSubmitted: (_) {
                  if (nextFocusAfterDistance != null) {
                    _fieldSubmitted(row.distanceFocusNode, nextFocusAfterDistance);
                  } else {
                    _onDistanceSubmitted(index);
                  }
                },
                autovalidateMode: AutovalidateMode.onUserInteraction),
          ],
        ),
      ),
    );
  }
}
