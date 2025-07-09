import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:traversemastery/models/theodolite_station.dart'; // Предполагается, что этот файл существует
import 'package:traversemastery/core/utils/angle_utils.dart';   // Предполагается, что этот файл существует

// Вспомогательный виджет для сохранения состояния дочерних элементов в ListView
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({required Key key, required this.child}) : super(key: key);

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context); // Важно для AutomaticKeepAliveClientMixin
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true; // Сохраняем состояние
}

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
  final Map<String, Map<String, String>> _temporaryInputValues = {};
  bool _formSubmittedOnce = false;

  @override
  void initState() {
    super.initState();
    _addStation(name: "Т1");
    _addStation(name: "Т2");
    _addStation(name: "Т3");
  }

  void _initializeControllersForStation(String stationId, {
    String name = '',
    AngleDMS? angleDMSFromModel,
    String? distanceFromModel,
  }) {
    TheodoliteStation? currentStationFromList;
    try {
      currentStationFromList = _stations.firstWhere((s) => s.id == stationId);
    } catch (e) { /* Станция может быть новой */ }

    final effectiveAngleDMS = angleDMSFromModel ?? AngleDMS();
    final effectiveDistance = distanceFromModel ?? '';
    final tempValuesForStation = _temporaryInputValues[stationId] ?? {};

    bool isAngleActuallyNullOrZeroInModel = (currentStationFromList?.horizontalAngle == null || currentStationFromList?.horizontalAngle == 0.0);
    bool isDistanceActuallyNullOrZeroInModel = (currentStationFromList?.distance == null || currentStationFromList?.distance == 0.0);

    String initialName = tempValuesForStation['name'] ?? name;
    String initialDeg = tempValuesForStation['angle_deg'] ?? (isAngleActuallyNullOrZeroInModel && effectiveAngleDMS.degrees == 0 ? '' : effectiveAngleDMS.degrees.toString());
    String initialMin = tempValuesForStation['angle_min'] ?? (isAngleActuallyNullOrZeroInModel && effectiveAngleDMS.minutes == 0 ? '' : effectiveAngleDMS.minutes.toString());
    String initialSec = tempValuesForStation['angle_sec'] ?? (isAngleActuallyNullOrZeroInModel && effectiveAngleDMS.seconds == 0.0 ? '' : effectiveAngleDMS.seconds.toStringAsFixed(2));
    String initialDist = tempValuesForStation['distance'] ?? (isDistanceActuallyNullOrZeroInModel && effectiveDistance.isEmpty ? '' : effectiveDistance);

    final nameController = TextEditingController(text: initialName);
    final angleDegController = TextEditingController(text: initialDeg);
    final angleMinController = TextEditingController(text: initialMin);
    final angleSecController = TextEditingController(text: initialSec);
    final distanceController = TextEditingController(text: initialDist);

    _controllers[stationId] = {
      'name': nameController,
      'angle_deg': angleDegController,
      'angle_min': angleMinController,
      'angle_sec': angleSecController,
      'distance': distanceController,
    };

    _controllers[stationId]!.forEach((key, controller) {
      controller.addListener(() {
        _temporaryInputValues.putIfAbsent(stationId, () => {})[key] = controller.text;
        // Валидация при изменении будет происходить через AutovalidateMode.onUserInteraction
        // в самих TextFormField, если _formSubmittedOnce == true.
        // Явный вызов _formKey.currentState?.validate() здесь может быть избыточным и приводить
        // к валидации всей формы при каждом изменении символа, что не всегда желательно.
      });
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, stationControllers) {
      stationControllers.forEach((_, controller) => controller.dispose());
    });
    _controllers.clear();
    _temporaryInputValues.clear();
    super.dispose();
  }

  void _addStation({String name = '', double? initialAngleDecimal}) {
    setState(() {
      final stationId = _uuid.v4();
      final newStation = TheodoliteStation(id: stationId, stationName: name, horizontalAngle: initialAngleDecimal);
      _stations.add(newStation);
      _initializeControllersForStation(
        stationId,
        name: newStation.stationName,
        angleDMSFromModel: AngleDMS.fromDecimalDegrees(newStation.horizontalAngle),
        distanceFromModel: newStation.distance?.toString(),
      );
    });
  }

  void _removeStation(int index) {
    if (_stations.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Должна остаться хотя бы одна станция.')),
      );
      return;
    }
    setState(() {
      final stationId = _stations[index].id;
      _controllers[stationId]?.forEach((_, controller) => controller.dispose());
      _controllers.remove(stationId);
      _temporaryInputValues.remove(stationId);
      _stations.removeAt(index);
    });
  }

  void _submitForm() {
    if (!_formSubmittedOnce) {
      setState(() {
        _formSubmittedOnce = true;
      });
    }

    bool conversionErrorEncountered = false;
    for (int i = 0; i < _stations.length; i++) {
      final stationId = _stations[i].id;
      final stationControllers = _controllers[stationId];
      if (stationControllers != null) {
        _stations[i].stationName = stationControllers['name']!.text;

        final degStr = stationControllers['angle_deg']!.text;
        final minStr = stationControllers['angle_min']!.text;
        final secStr = stationControllers['angle_sec']!.text;
        final distStr = stationControllers['distance']!.text;

        if (distStr.isEmpty) {
          _stations[i].distance = null;
        } else {
          final distVal = double.tryParse(distStr);
          if (distVal != null && distVal > 0) {
            _stations[i].distance = distVal;
          } else {
            _stations[i].distance = null;
          }
        }

        if (degStr.isEmpty && minStr.isEmpty && secStr.isEmpty) {
          _stations[i].horizontalAngle = null;
        } else {
          int? degrees = int.tryParse(degStr.isNotEmpty ? degStr : "0");
          int? minutes = int.tryParse(minStr.isNotEmpty ? minStr : "0");
          double? seconds = double.tryParse(secStr.isNotEmpty ? secStr : "0.0");

          if (degrees != null && minutes != null && seconds != null) {
            if (minutes >= 0 && minutes < 60 && seconds >= 0.0 && seconds < 60.0) {
              _stations[i].horizontalAngle = AngleDMS(degrees: degrees, minutes: minutes, seconds: seconds).toDecimalDegrees();
            } else {
              _stations[i].horizontalAngle = null;
              conversionErrorEncountered = true;
            }
          } else {
            _stations[i].horizontalAngle = null;
            conversionErrorEncountered = true;
          }
        }
      }
    }

    // Небольшое уведомление о проблемах конвертации, если они были, но основная работа у валидаторов.
    if (conversionErrorEncountered && mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Проверьте корректность значений углов или расстояний.')),
      // );
    }

    if (_formKey.currentState!.validate()) {
      _temporaryInputValues.clear();
      setState(() {
        _formSubmittedOnce = false; // Сбрасываем для следующего цикла ввода
      });
      widget.onSubmit(List.from(_stations));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, исправьте ошибки в полях ввода.')),
        );
      }
      // _formSubmittedOnce остается true, чтобы поля продолжали валидироваться onUserInteraction
    }
  }

  Widget _buildStationInput(int index) {
    final station = _stations[index];
    final stationId = station.id;

    if (!_controllers.containsKey(stationId)) {
      _initializeControllersForStation(
        stationId,
        name: station.stationName,
        angleDMSFromModel: AngleDMS.fromDecimalDegrees(station.horizontalAngle),
        distanceFromModel: station.distance?.toString(),
      );
    }
    final stationSpecificControllers = _controllers[stationId]!;
    final currentAutovalidateMode = _formSubmittedOnce
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

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
                    controller: stationSpecificControllers['name'],
                    decoration: InputDecoration(
                      labelText: 'Станция ${index + 1}',
                      isDense: true,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                    autovalidateMode: currentAutovalidateMode,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Название станции?';
                      }
                      return null;
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
                    controller: stationSpecificControllers['angle_deg'],
                    decoration: const InputDecoration(labelText: 'Град.°', hintText: "ГГ"),
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')), LengthLimitingTextInputFormatter(4)],
                    textAlign: TextAlign.center,
                    autovalidateMode: currentAutovalidateMode,
                    validator: (value) {
                      final allAngleFieldsEmpty = stationSpecificControllers['angle_deg']!.text.isEmpty &&
                          stationSpecificControllers['angle_min']!.text.isEmpty &&
                          stationSpecificControllers['angle_sec']!.text.isEmpty;
                      if (allAngleFieldsEmpty) return null; // Если все поля угла пустые, ошибки нет
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
                    controller: stationSpecificControllers['angle_min'],
                    decoration: const InputDecoration(labelText: "Мин.'", hintText: "ММ"),
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    textAlign: TextAlign.center,
                    autovalidateMode: currentAutovalidateMode,
                    validator: (value) {
                      final allAngleFieldsEmpty = stationSpecificControllers['angle_deg']!.text.isEmpty &&
                          stationSpecificControllers['angle_min']!.text.isEmpty &&
                          stationSpecificControllers['angle_sec']!.text.isEmpty;
                      if (allAngleFieldsEmpty) return null;
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
                    controller: stationSpecificControllers['angle_sec'],
                    decoration: const InputDecoration(labelText: 'Сек."', hintText: "СС.сс"),
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), LengthLimitingTextInputFormatter(5)],
                    textAlign: TextAlign.center,
                    autovalidateMode: currentAutovalidateMode,
                    validator: (value) {
                      final allAngleFieldsEmpty = stationSpecificControllers['angle_deg']!.text.isEmpty &&
                          stationSpecificControllers['angle_min']!.text.isEmpty &&
                          stationSpecificControllers['angle_sec']!.text.isEmpty;
                      if (allAngleFieldsEmpty) return null;
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
              controller: stationSpecificControllers['distance'],
              decoration: const InputDecoration(labelText: 'Расстояние (метры)', hintText: 'например, 150.75'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
              autovalidateMode: currentAutovalidateMode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите расстояние';
                }
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
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8.0, bottom: 80.0), // Отступ для кнопок внизу
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  return KeepAliveWrapper(
                    key: ValueKey(_stations[index].id),
                    child: _buildStationInput(index),
                  );
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
