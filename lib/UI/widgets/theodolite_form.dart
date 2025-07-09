// lib/ui/widgets/theodolite_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/full_traverse_input.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// 1. Обновляем _StationInputRow
class _StationInputRow {
  final String id;
  final TextEditingController nameController;
  // Контроллеры для Угла (Градусы, Минуты, Секунды)
  final TextEditingController angleDegreesController;
  final TextEditingController angleMinutesController;
  final TextEditingController angleSecondsController;
  final TextEditingController distanceController;

  final FocusNode nameFocusNode;
  // Фокус-ноды для Угла
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

  // Вспомогательный метод для получения угла в десятичных градусах
  double? getAngleAsDecimalDegrees() {
    final g = int.tryParse(angleDegreesController.text);
    final m = int.tryParse(angleMinutesController.text);
    final s = double.tryParse(angleSecondsController.text.replaceAll(',', '.'));

    if (g == null || m == null || s == null) {
      return null;
    }
    if (g < 0 || g >= 360 || m < 0 || m >= 60 || s < 0 || s >= 60) {
      // Базовая проверка диапазона, более детальная валидация будет в TextFormField
      return null;
    }
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
  static const int _minStationsForClosedTraverse = 3;

  @override
  void initState() {
    super.initState();
    _initialXController.text = "1000.0";
    _initialYController.text = "1000.0";
    _initialAzimuthController.text = "0.0";
    _calculationNameController.text = "Новый расчет ${DateTime.now().day}.${DateTime.now().month}";

    for (int i = 0; i < _minStationsForClosedTraverse; i++) {
      _addStationRowInternal(initialAdd: true);
    }
  }

  @override
  void dispose() {
    // ... dispose контроллеров начальных данных ...
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
    // ... (без изменений) ...
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
    // ... (без изменений) ...
    if (_stationRows.length <= _minStationsForClosedTraverse) {
      _showErrorSnackBar('Необходимо минимум $_minStationsForClosedTraverse станции для расчета.');
      return;
    }
    setState(() {
      final row = _stationRows.removeAt(index);
      row.dispose();
    });
  }

  String? _validateInitialNumberInput(String? value, String fieldName, {bool allowZero = false, bool allowNegative = false}) {
    // ... (без изменений) ...
    if (value == null || value.isEmpty) {
      return '$fieldName: введите значение';
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName: некорректное число';
    }
    if (!allowZero && number == 0 && fieldName.toLowerCase().contains("азимут")) {
      // 0 для азимута валидно
    } else if (!allowZero && number == 0) {
      return '$fieldName: не может быть 0';
    }
    if (!allowNegative && number < 0) {
      return '$fieldName: не может быть < 0';
    }
    if (fieldName.toLowerCase().contains("азимут") && (number < 0 || number >= 360)) {
      return '$fieldName: от 0 до 359.99...';
    }
    return null;
  }

  // 2. Обновленные валидаторы для Градусов, Минут, Секунд
  String? _validateDegrees(String? value) {
    if (value == null || value.isEmpty) return 'Введите °';
    final val = int.tryParse(value);
    if (val == null) return 'Не число';
    if (val < 0 || val >= 360) return '0-359';
    return null;
  }

  String? _validateMinutes(String? value) {
    if (value == null || value.isEmpty) return 'Введите ′';
    final val = int.tryParse(value);
    if (val == null) return 'Не число';
    if (val < 0 || val >= 60) return '0-59';
    return null;
  }

  String? _validateSeconds(String? value) {
    if (value == null || value.isEmpty) return 'Введите ″';
    final val = double.tryParse(value.replaceAll(',', '.'));
    if (val == null) return 'Не число';
    if (val < 0 || val >= 60) return '0-59.9..';
    return null;
  }

  String? _validateDistance(String? value) {
    // ... (аналогично старому _validateStationNumberField для расстояния)
    if (value == null || value.isEmpty) {
      return 'Введите расст.';
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return 'Не число';
    }
    if (number <= 0) {
      return '> 0';
    }
    return null;
  }


  void _handleSubmit() {
    FocusScope.of(context).unfocus();

    if (!(_initialDataFormKey.currentState?.validate() ?? false)) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в начальных данных.');
      // Попытка прокрутить к началу, если есть ошибки
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    if (!(_stationsFormKey.currentState?.validate() ?? false)) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в данных станций.');
      // Здесь сложнее прокрутить к конкретной ошибочной станции без GlobalKey для каждой
      return;
    }

    final double initialX = double.parse(_initialXController.text.replaceAll(',', '.'));
    final double initialY = double.parse(_initialYController.text.replaceAll(',', '.'));
    final double initialAzimuth = double.parse(_initialAzimuthController.text.replaceAll(',', '.'));
    final String calculationName = _calculationNameController.text.trim();

    List<TheodoliteStation> stations = [];
    for (int i = 0; i < _stationRows.length; i++) {
      final row = _stationRows[i];
      final String stationNameText = row.nameController.text.trim();
      final double? angleDecimal = row.getAngleAsDecimalDegrees(); // Используем новый метод
      final double? distanceValue = double.tryParse(row.distanceController.text.replaceAll(',', '.'));

      if (angleDecimal == null) {
        _showErrorSnackBar('Некорректный угол для станции ${stationNameText.isNotEmpty ? '"$stationNameText"' : i + 1}. Проверьте градусы, минуты и секунды.');
        return;
      }
      if (distanceValue == null) { // Уже должно быть отловлено валидатором
        _showErrorSnackBar('Некорректное расстояние для станции ${stationNameText.isNotEmpty ? '"$stationNameText"' : i + 1}.');
        return;
      }

      stations.add(TheodoliteStation(
        id: row.id,
        stationName: stationNameText,
        horizontalAngle: angleDecimal, // Передаем десятичные градусы
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
    // ... (без изменений) ...
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

  // Обновляем переходы фокуса
  void _fieldSubmitted(FocusNode currentFocus, FocusNode? nextFocus) {
    currentFocus.unfocus();
    if (nextFocus != null && nextFocus.canRequestFocus) {
      FocusScope.of(context).requestFocus(nextFocus);
    }
  }

  void _onDistanceSubmitted(int index) {
    _stationRows[index].distanceFocusNode.unfocus();
    if (index == _stationRows.length - 1) {
      // Проверяем только форму станций при добавлении новой строки
      if (_stationsFormKey.currentState?.validate() ?? false) {
        _addStationRowInternal(requestFocus: true);
      }
    } else {
      // Переход на имя следующей станции
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
        crossAxisAlignment: CrossAxisAlignment.stretch, // Растягиваем дочерние элементы по ширине
        children: [
          _buildInitialDataSection(),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            "Данные теодолитного хода:", // Изменено для ясности
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildStationsSection(),
          const SizedBox(height: 20),
          ElevatedButton.icon( // Кнопка вынесена из _buildStationsSection и растянута
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Рассчитать ход'),
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 16)
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInitialDataSection() {
    // ... (без изменений, как в предыдущей версии) ...
    return Form(
      key: _initialDataFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Начальные данные:",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _calculationNameController,
            decoration: const InputDecoration(
              labelText: 'Имя/номер расчета',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) { /* Можно сделать необязательным */ return null; },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _initialXController,
                  decoration: const InputDecoration(labelText: 'Начальный X', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]+'))],
                  validator: (v) => _validateInitialNumberInput(v, "Нач. X", allowZero: true, allowNegative: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _initialYController,
                  decoration: const InputDecoration(labelText: 'Начальный Y', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]+'))],
                  validator: (v) => _validateInitialNumberInput(v, "Нач. Y", allowZero: true, allowNegative: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _initialAzimuthController,
            decoration: const InputDecoration(
              labelText: 'Начальный дирекционный угол (°)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+'))],
            validator: (v) => _validateInitialNumberInput(v, "Нач. азимут", allowZero: true),
          ),
        ],
      ),
    );
  }

  // 3. _buildStationsSection и _buildStationInputRow обновлены
  Widget _buildStationsSection() {
    return Form(
      key: _stationsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row не нужен, т.к. каждая станция будет иметь свою структуру
          // _buildHeaderRow(),
          ..._stationRows.asMap().entries.map((entry) {
            int index = entry.key;
            _StationInputRow row = entry.value;
            return _buildStationInputRow(row, index);
          }).toList(),
          const SizedBox(height: 12),
          TextButton.icon( // Кнопка "Добавить станцию"
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Добавить станцию'),
              onPressed: () => _addStationRowInternal(requestFocus: true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              )
          ),
        ],
      ),
    );
  }

  // Не используется больше
  // Widget _buildHeaderRow() { ... }

  Widget _buildStationInputRow(_StationInputRow row, int index) {
    // Определяем, куда переходить после секунд и расстояния
    FocusNode? nextFocusAfterSeconds;
    FocusNode? nextFocusAfterDistance;

    if (index + 1 < _stationRows.length) { // Если есть следующая станция
      nextFocusAfterSeconds = row.distanceFocusNode; // После секунд на расстояние текущей
      nextFocusAfterDistance = _stationRows[index+1].nameFocusNode; // После расстояния на имя следующей
    } else { // Это последняя станция
      nextFocusAfterSeconds = row.distanceFocusNode; // После секунд на расстояние текущей
      // nextFocusAfterDistance - нет явного перехода, обработка в _onDistanceSubmitted
    }


    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row( // Номер станции и кнопка удаления
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Станция ${index + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  onPressed: () => _removeStationRow(index),
                  tooltip: 'Удалить станцию ${index + 1}',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Имя станции
            TextFormField(
              controller: row.nameController,
              focusNode: row.nameFocusNode,
              decoration: const InputDecoration(
                labelText: 'Имя станции',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _fieldSubmitted(row.nameFocusNode, row.angleDegreesFocusNode),
            ),
            const SizedBox(height: 12),
            // Поля для Градусов, Минут, Секунд в одной строке
            Text("Горизонтальный угол:", style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Для выравнивания валидаторов
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.angleDegreesController,
                    focusNode: row.angleDegreesFocusNode,
                    decoration: const InputDecoration(labelText: '°', border: OutlineInputBorder(), helperText: " "), // helperText для высоты
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    validator: _validateDegrees,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fieldSubmitted(row.angleDegreesFocusNode, row.angleMinutesFocusNode),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row.angleMinutesController,
                    focusNode: row.angleMinutesFocusNode,
                    decoration: const InputDecoration(labelText: '′', border: OutlineInputBorder(), helperText: " "),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    validator: _validateMinutes,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fieldSubmitted(row.angleMinutesFocusNode, row.angleSecondsFocusNode),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row.angleSecondsController,
                    focusNode: row.angleSecondsFocusNode,
                    decoration: const InputDecoration(labelText: '″', border: OutlineInputBorder(), helperText: " "),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+')), LengthLimitingTextInputFormatter(5)], // 59.99
                    validator: _validateSeconds,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fieldSubmitted(row.angleSecondsFocusNode, nextFocusAfterSeconds),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10), // Отступ перед расстоянием
            // Расстояние
            TextFormField(
                controller: row.distanceController,
                focusNode: row.distanceFocusNode,
                decoration: const InputDecoration(
                    labelText: 'Расстояние (м)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    helperText: " " // для выравнивания высоты если у углов есть helperText (ошибка)
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+'))],
                validator: _validateDistance,
                textInputAction: nextFocusAfterDistance == null ? TextInputAction.done : TextInputAction.next,
                onFieldSubmitted: (_) {
                  if (nextFocusAfterDistance != null) {
                    _fieldSubmitted(row.distanceFocusNode, nextFocusAfterDistance);
                  } else {
                    _onDistanceSubmitted(index); // Для добавления новой строки или завершения
                  }
                }
            ),
          ],
        ),
      ),
    );
  }
}

