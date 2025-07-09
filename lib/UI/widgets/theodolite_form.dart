// lib/ui/widgets/theodolite_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/full_traverse_input.dart'; // Наша новая модель
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class _StationInputRow { // Остается без изменений для строк станций
  final String id;
  final TextEditingController nameController;
  final TextEditingController angleController;
  final TextEditingController distanceController;
  final FocusNode nameFocusNode;
  final FocusNode angleFocusNode;
  final FocusNode distanceFocusNode;

  _StationInputRow()
      : id = _uuid.v4(),
        nameController = TextEditingController(),
        angleController = TextEditingController(),
        distanceController = TextEditingController(),
        nameFocusNode = FocusNode(),
        angleFocusNode = FocusNode(),
        distanceFocusNode = FocusNode();

  void dispose() {
    nameController.dispose();
    angleController.dispose();
    distanceController.dispose();
    nameFocusNode.dispose();
    angleFocusNode.dispose();
    distanceFocusNode.dispose();
  }
}

class TheodoliteForm extends StatefulWidget {
  // onSubmit теперь передает FullTraverseInput
  final Function(FullTraverseInput fullInput) onSubmit;

  const TheodoliteForm({
    super.key,
    required this.onSubmit,
  });

  @override
  // ignore: library_private_types_in_public_api
  TheodoliteFormStateImplementation createState() => TheodoliteFormStateImplementation();
}

class TheodoliteFormStateImplementation extends State<TheodoliteForm> {
  // Ключи для форм
  final _initialDataFormKey = GlobalKey<FormState>(); // Для начальных данных
  final _stationsFormKey = GlobalKey<FormState>();    // Для списка станций

  // Контроллеры для начальных данных
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
    // Значения по умолчанию для начальных данных
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
    // Логика добавления строки станции (без изменений)
    setState(() {
      _stationRows.add(_StationInputRow());
    });
    if (!initialAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
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
    // Логика удаления строки станции (без изменений)
    if (_stationRows.length <= _minStationsForClosedTraverse) {
      _showErrorSnackBar('Необходимо минимум $_minStationsForClosedTraverse станции для расчета.');
      return;
    }
    setState(() {
      _stationRows[index].dispose();
      _stationRows.removeAt(index);
    });
  }

  // Валидатор для начальных числовых полей
  String? _validateInitialNumberInput(String? value, String fieldName, {bool allowZero = false, bool allowNegative = false}) {
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

  // Валидатор для полей станций (углы, расстояния)
  String? _validateStationNumberField(String? value, String fieldName) {
    // ... (без изменений, как в предыдущей версии theodolite_form.dart)
    if (value == null || value.isEmpty) {
      return '$fieldName: введите значение';
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName: некорректное число';
    }
    if (fieldName.toLowerCase().contains("расстоян") && number <= 0) {
      return '$fieldName: должно быть > 0';
    }
    if (fieldName.toLowerCase().contains("угол") && (number < 0 || number >= 360)) {
      return '$fieldName: от 0 до 359.99...';
    }
    return null;
  }


  void _handleSubmit() {
    FocusScope.of(context).unfocus(); // Скрыть клавиатуру

    // 1. Валидация формы начальных данных
    if (!(_initialDataFormKey.currentState?.validate() ?? false)) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в начальных данных.');
      // Прокрутка к форме начальных данных, если она не видна
      // (потребует GlobalKey для виджета _buildInitialDataForm и Scrollable.ensureVisible)
      return;
    }

    // 2. Валидация формы станций
    if (!(_stationsFormKey.currentState?.validate() ?? false)) {
      _showErrorSnackBar('Пожалуйста, исправьте ошибки в данных станций.');
      return;
    }

    // 3. Сбор начальных данных
    final double initialX = double.parse(_initialXController.text.replaceAll(',', '.'));
    final double initialY = double.parse(_initialYController.text.replaceAll(',', '.'));
    final double initialAzimuth = double.parse(_initialAzimuthController.text.replaceAll(',', '.'));
    final String calculationName = _calculationNameController.text.trim();

    // 4. Сбор данных станций
    List<TheodoliteStation> stations = [];
    for (int i = 0; i < _stationRows.length; i++) {
      final row = _stationRows[i];
      // ... (логика сбора данных для одной станции, как раньше)
      final String stationNameText = row.nameController.text.trim();
      final double? angle = double.tryParse(row.angleController.text.replaceAll(',', '.'));
      final double? distanceValue = double.tryParse(row.distanceController.text.replaceAll(',', '.'));

      if (angle == null || distanceValue == null) { // Двойная проверка
        _showErrorSnackBar('Ошибка данных в строке станции ${i+1}.');
        return;
      }
      stations.add(TheodoliteStation(
        id: row.id,
        stationName: stationNameText,
        horizontalAngle: angle,
        distance: distanceValue,
        coordinateX: null, // X, Y здесь не нужны, они есть в initialX, initialY
        coordinateY: null,
      ));
    }

    if (stations.length < _minStationsForClosedTraverse) {
      _showErrorSnackBar('Необходимо минимум $_minStationsForClosedTraverse станции для расчета.');
      return;
    }

    // 5. Создание и передача FullTraverseInput
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
    // ... (без изменений)
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
    // ... (без изменений)
    currentFocus.unfocus();
    if (nextFocus != null && nextFocus.canRequestFocus) {
      FocusScope.of(context).requestFocus(nextFocus);
    }
  }

  void _onDistanceSubmitted(int index) {
    // ... (без изменений)
    _stationRows[index].distanceFocusNode.unfocus();
    if (index == _stationRows.length - 1) {
      if (_stationsFormKey.currentState?.validate() ?? false) { // Проверяем только форму станций
        _addStationRowInternal(requestFocus: true);
      }
    } else {
      if (_stationRows[index + 1].nameFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_stationRows[index + 1].nameFocusNode);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Весь контент формы теперь внутри одного ScrollView, чтобы все было доступно
    return SingleChildScrollView(
      controller: _scrollController, // Используем общий ScrollController
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInitialDataSection(), // Секция для начальных данных
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            "Данные станций:",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildStationsSection(),     // Секция для списка станций
          const SizedBox(height: 20),
          Center( // Кнопка Рассчитать теперь внизу общего скролла
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Рассчитать ход'),
              onPressed: _handleSubmit,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16)
              ),
            ),
          ),
          const SizedBox(height: 16), // Отступ снизу
        ],
      ),
    );
  }

  Widget _buildInitialDataSection() {
    return Form(
      key: _initialDataFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Начальные данные хода:",
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

  Widget _buildStationsSection() {
    // ListView.builder не очень хорошо работает внутри SingleChildScrollView без ограничений высоты.
    // Если станций может быть МНОГО, то лучше использовать Column с .map().
    // Для умеренного количества ListView.builder с shrinkWrap=true и physics=NeverScrollableScrollPhysics может сработать.
    // Здесь оставляем Column с .map() для простоты и надежности внутри SingleChildScrollView.
    return Form(
      key: _stationsFormKey,
      child: Column( // Используем Column вместо ListView.builder
        children: [
          _buildHeaderRow(), // Заголовок для станций
          ..._stationRows.asMap().entries.map((entry) { // Используем asMap().entries для получения индекса
            int index = entry.key;
            _StationInputRow row = entry.value;
            return _buildStationInputRow(row, index);
          }).toList(),
          const SizedBox(height: 8),
          Align( // Кнопка "Добавить станцию"
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Добавить станцию'),
                onPressed: () => _addStationRowInternal(requestFocus: true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                )
            ),
          ),
        ],
      ),
    );
  }

  // _buildHeaderRow и _buildStationInputRow остаются такими же, как в предыдущей версии theodolite_form.dart
  Widget _buildHeaderRow() {
    // ... (код из предыдущей версии)
    return Padding(
      padding: const EdgeInsets.only(left: 45.0, right: 50.0, top: 0.0, bottom: 4.0),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Имя станции', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Гор. угол (°)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Расст. (м)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildStationInputRow(_StationInputRow row, int index) {
    // ... (код из предыдущей версии, только валидатор изменен на _validateStationNumberField)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 14.0),
            width: 35,
            alignment: Alignment.topCenter,
            child: Text('${index + 1}.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: row.nameController,
              focusNode: row.nameFocusNode,
              decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _fieldSubmitted(row.nameFocusNode, row.angleFocusNode),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.angleController,
              focusNode: row.angleFocusNode,
              decoration: const InputDecoration(labelText: 'Угол', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+'))],
              validator: (value) => _validateStationNumberField(value, 'Угол'), // Изменен валидатор
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _fieldSubmitted(row.angleFocusNode, row.distanceFocusNode),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.distanceController,
              focusNode: row.distanceFocusNode,
              decoration: const InputDecoration(labelText: 'Расст.', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+'))],
              validator: (value) => _validateStationNumberField(value, 'Расстоян.'), // Изменен валидатор
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _onDistanceSubmitted(index),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.redAccent.withOpacity(0.8),
            onPressed: () => _removeStationRow(index),
            tooltip: 'Удалить станцию',
            padding: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
