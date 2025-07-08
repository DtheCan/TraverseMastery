import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для InputFormatters
import 'package:uuid/uuid.dart';
import 'package:traversemastery/models/theodolite_station.dart';
// Предполагается, что AngleDMS находится в utils/angle_utils.dart
import 'package:traversemastery/core/utils/angle_utils.dart'; // ЗАМЕНИТЕ testdesc на имя вашего проекта

class TheodoliteForm extends StatefulWidget {
  final Function(List<TheodoliteStation> stations) onSubmit;

  const TheodoliteForm({super.key, required this.onSubmit});

  @override
  State<TheodoliteForm> createState() => _TheodoliteFormState();
}

class _TheodoliteFormState extends State<TheodoliteForm> {
  final _formKey = GlobalKey<FormState>();
  List<TheodoliteStation> _stations = [];
  final Uuid _uuid = const Uuid();

  final Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _addStation(name: "Т1"); // По умолчанию углы будут null, поля будут пустыми
    _addStation(name: "Т2");
    _addStation(name: "Т3");
  }

  void _initializeControllersForStation(String stationId, {
    String name = '',
    AngleDMS? angleDMS, // Приходит уже сконвертированный AngleDMS
    String? distance,
  }) {
    // Если angleDMS не предоставлен или все его поля нули (что произойдет если decimalDegrees был null или 0),
    // то поля должны быть пустыми.
    final effectiveAngle = angleDMS ?? AngleDMS(); // Гарантируем, что не null для доступа к полям

    _controllers[stationId] = {
      'name': TextEditingController(text: name),
      'angle_deg': TextEditingController(text: effectiveAngle.degrees == 0 && effectiveAngle.minutes == 0 && effectiveAngle.seconds == 0.0 && (_stations.firstWhere((s) => s.id == stationId).horizontalAngle == null || _stations.firstWhere((s) => s.id == stationId).horizontalAngle == 0.0) ? '' : effectiveAngle.degrees.toString()),
      'angle_min': TextEditingController(text: effectiveAngle.minutes == 0 && effectiveAngle.degrees == 0 && effectiveAngle.seconds == 0.0 && (_stations.firstWhere((s) => s.id == stationId).horizontalAngle == null || _stations.firstWhere((s) => s.id == stationId).horizontalAngle == 0.0) ? '' : effectiveAngle.minutes.toString()),
      'angle_sec': TextEditingController(text: effectiveAngle.seconds == 0.0 && effectiveAngle.degrees == 0 && effectiveAngle.minutes == 0 && (_stations.firstWhere((s) => s.id == stationId).horizontalAngle == null || _stations.firstWhere((s) => s.id == stationId).horizontalAngle == 0.0) ? '' : effectiveAngle.seconds.toStringAsFixed(2)),
      'distance': TextEditingController(text: distance ?? ''), // Используем ?? '' для distance тоже
    };
  }

  void _disposeControllersForStation(String stationId) {
    _controllers[stationId]?.forEach((_, controller) => controller.dispose());
    _controllers.remove(stationId);
  }

  @override
  void dispose() {
    for (var stationControllers in _controllers.values) {
      stationControllers.forEach((_, controller) => controller.dispose());
    }
    _controllers.clear();
    super.dispose();
  }

  void _addStation({String name = '', double? initialAngleDecimal}) {
    setState(() {
      final stationId = _uuid.v4();
      // Если initialAngleDecimal не задан (null), то AngleDMS.fromDecimalDegrees вернет AngleDMS(0,0,0)
      // и _initializeControllersForStation сделает поля пустыми.
      final newStation = TheodoliteStation(id: stationId, stationName: name, horizontalAngle: initialAngleDecimal);
      _stations.add(newStation);
      _initializeControllersForStation(
        stationId,
        name: newStation.stationName,
        angleDMS: AngleDMS.fromDecimalDegrees(newStation.horizontalAngle), // Передаем результат конвертации
        distance: newStation.distance?.toString(),
      );
    });
  }

  void _removeStation(int index) {
    if (_stations.length > 1) {
      setState(() {
        final stationId = _stations[index].id;
        _disposeControllersForStation(stationId);
        _stations.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Минимальное количество станций для удаления: 1')),
      );
    }
  }

  void _submitForm() {
    bool allAngleFieldsValid = true;
    for (int i = 0; i < _stations.length; i++) {
      final stationId = _stations[i].id;
      if (_controllers.containsKey(stationId)) {
        _stations[i].stationName = _controllers[stationId]!['name']!.text;
        _stations[i].distance = _controllers[stationId]!['distance']!.text.isEmpty
            ? null
            : double.tryParse(_controllers[stationId]!['distance']!.text);

        final degStr = _controllers[stationId]!['angle_deg']!.text;
        final minStr = _controllers[stationId]!['angle_min']!.text;
        final secStr = _controllers[stationId]!['angle_sec']!.text;

        // Если все поля угла пустые, считаем, что угол не введен (null)
        if (degStr.isEmpty && minStr.isEmpty && secStr.isEmpty) {
          _stations[i].horizontalAngle = null;
        } else {
          // Если хотя бы одно поле заполнено, пытаемся собрать угол.
          // Для простоты валидации, если одно заполнено, остальные тоже должны быть.
          // Но форма сама это проверит через validators.
          int? degrees = int.tryParse(degStr.isNotEmpty ? degStr : "0"); // Если пусто, считаем 0 для сборки
          int? minutes = int.tryParse(minStr.isNotEmpty ? minStr : "0");
          double? seconds = double.tryParse(secStr.isNotEmpty ? secStr : "0.0");

          // Дополнительная проверка, если поля были частично пустыми, но прошли валидаторы (которые требуют "Нужно")
          // Это условие больше для логики, если бы валидаторы разрешали пустые поля при частичном вводе.
          // В текущей реализации валидаторы TextField потребуют значения, если форма активна.

          if (degrees != null && minutes != null && seconds != null) {
            if (minutes >= 0 && minutes < 60 && seconds >= 0.0 && seconds < 60.0) {
              _stations[i].horizontalAngle = AngleDMS(degrees: degrees, minutes: minutes, seconds: seconds).toDecimalDegrees();
            } else {
              allAngleFieldsValid = false;
              break;
            }
          } else {
            allAngleFieldsValid = false;
            break;
          }
        }
      }
    }

    if (!allAngleFieldsValid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка в значениях минут или секунд (должны быть < 60). Пожалуйста, проверьте все поля углов.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Перед отправкой еще раз обновим _stations, т.к. onChanged для TextFormFields
      // мог не успеть обновить _stations[i].horizontalAngle если фокус сразу ушел на кнопку.
      // Логика выше уже должна была это сделать, но для надежности.
      for (int i = 0; i < _stations.length; i++) {
        final stationId = _stations[i].id;
        final degStr = _controllers[stationId]!['angle_deg']!.text;
        final minStr = _controllers[stationId]!['angle_min']!.text;
        final secStr = _controllers[stationId]!['angle_sec']!.text;

        if (degStr.isEmpty && minStr.isEmpty && secStr.isEmpty) {
          _stations[i].horizontalAngle = null;
        } else {
          int degrees = int.tryParse(degStr.isNotEmpty ? degStr : "0") ?? 0;
          int minutes = int.tryParse(minStr.isNotEmpty ? minStr : "0") ?? 0;
          double seconds = double.tryParse(secStr.isNotEmpty ? secStr : "0.0") ?? 0.0;
          _stations[i].horizontalAngle = AngleDMS(degrees: degrees, minutes: minutes, seconds: seconds).toDecimalDegrees();
        }
      }
      widget.onSubmit(List.from(_stations));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, исправьте ошибки в форме.')),
        );
      }
    }
  }

  Widget _buildStationInput(int index) {
    final station = _stations[index];
    final stationId = station.id;
    // Получаем AngleDMS из сохраненного decimalDegrees.
    // Если horizontalAngle is null, AngleDMS.fromDecimalDegrees вернет AngleDMS(0,0,0)
    final angleDMS = AngleDMS.fromDecimalDegrees(station.horizontalAngle);

    // Инициализация или обновление контроллеров
    if (!_controllers.containsKey(stationId)) {
      // Эта ветка должна вызываться реже, в основном при добавлении новой станции.
      _initializeControllersForStation(
        stationId,
        name: station.stationName,
        angleDMS: angleDMS, // передаем уже готовый AngleDMS
        distance: station.distance?.toString(),
      );
    } else {
      // Эта ветка чаще при перестроениях виджета. Обновляем текст.
      final stationInList = _stations[index]; // Берем актуальное значение из списка
      final currentAngleDMS = AngleDMS.fromDecimalDegrees(stationInList.horizontalAngle);
      final isAngleEffectivelyNullOrZero = stationInList.horizontalAngle == null || stationInList.horizontalAngle == 0.0;

      _controllers[stationId]!['name']!.text = stationInList.stationName;
      _controllers[stationId]!['angle_deg']!.text = isAngleEffectivelyNullOrZero && currentAngleDMS.degrees == 0 ? '' : currentAngleDMS.degrees.toString();
      _controllers[stationId]!['angle_min']!.text = isAngleEffectivelyNullOrZero && currentAngleDMS.minutes == 0 ? '' : currentAngleDMS.minutes.toString();
      // Для секунд, если 0.0 и угол был null/0, ставим '', иначе форматируем
      _controllers[stationId]!['angle_sec']!.text = isAngleEffectivelyNullOrZero && currentAngleDMS.seconds == 0.0 ? '' : currentAngleDMS.seconds.toStringAsFixed(2);
      _controllers[stationId]!['distance']!.text = stationInList.distance?.toString() ?? '';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controllers[stationId]!['name'],
                    decoration: InputDecoration(
                      labelText: 'Станция ${index + 1}',
                      isDense: true,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                    onChanged: (value) { // Обновляем имя станции в модели сразу
                      setState(() {
                        _stations[index].stationName = value;
                      });
                    },
                  ),
                ),
                if (_stations.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _removeStation(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Горизонтальный угол:", style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _controllers[stationId]!['angle_deg'],
                    decoration: const InputDecoration(labelText: 'Град.°', hintText: "ГГ"),
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')), LengthLimitingTextInputFormatter(4)], // Разрешаем знак минус и цифры
                    textAlign: TextAlign.center,
                    validator: (value) {
                      final allEmpty = _controllers[stationId]!['angle_deg']!.text.isEmpty &&
                          _controllers[stationId]!['angle_min']!.text.isEmpty &&
                          _controllers[stationId]!['angle_sec']!.text.isEmpty;
                      if (allEmpty) return null; // Если все поля угла пустые, ошибки нет
                      if (value == null || value.isEmpty) return 'Нужно';
                      if (int.tryParse(value) == null) return 'Число';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _controllers[stationId]!['angle_min'],
                    decoration: const InputDecoration(labelText: "Мин.'", hintText: "ММ"),
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    textAlign: TextAlign.center,
                    validator: (value) {
                      final allEmpty = _controllers[stationId]!['angle_deg']!.text.isEmpty &&
                          _controllers[stationId]!['angle_min']!.text.isEmpty &&
                          _controllers[stationId]!['angle_sec']!.text.isEmpty;
                      if (allEmpty) return null;
                      if (value == null || value.isEmpty) return 'Нужно';
                      final min = int.tryParse(value);
                      if (min == null) return 'Число';
                      if (min < 0 || min >= 60) return '0-59';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _controllers[stationId]!['angle_sec'],
                    decoration: const InputDecoration(labelText: 'Сек."', hintText: "СС.сс"),
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      LengthLimitingTextInputFormatter(5)
                    ],
                    textAlign: TextAlign.center,
                    validator: (value) {
                      final allEmpty = _controllers[stationId]!['angle_deg']!.text.isEmpty &&
                          _controllers[stationId]!['angle_min']!.text.isEmpty &&
                          _controllers[stationId]!['angle_sec']!.text.isEmpty;
                      if (allEmpty) return null;
                      if (value == null || value.isEmpty) return 'Нужно';
                      final sec = double.tryParse(value);
                      if (sec == null) return 'Число';
                      if (sec < 0.0 || sec >= 60.0) return '0-59.99';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controllers[stationId]!['distance'],
              decoration: const InputDecoration(labelText: 'Расстояние до след. (метры)', hintText: 'например, 150.75'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
              validator: (value) { // Расстояние всегда обязательно
                if (value == null || value.isEmpty) return 'Введите расстояние';
                final distance = double.tryParse(value);
                if (distance == null) return 'Корректное число';
                if (distance <= 0) return 'Больше нуля';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction, // Включим автовалидацию
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8.0, bottom: 80.0), // Увеличим отступ снизу для прокрутки над кнопками
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  return _buildStationInput(index);
                },
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 10.0,
        bottom: MediaQuery.of(context).padding.bottom + 10.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Добавить станцию'),
            onPressed: _addStation,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Рассчитать'),
          ),
        ],
      ),
    );
  }
}

