import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

// УБЕДИТЕСЬ, ЧТО ЭТИ ПУТИ ВЕРНЫ И ФАЙЛЫ СУЩЕСТВУЮТ В ВАШЕМ ПРОЕКТЕ.
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/core/utils/angle_utils.dart';


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
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
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
  final Map<String, Map<String, String?>> _inlineFieldErrors = {};
  bool _formSubmittedOnce = false;

  @override
  void initState() {
    super.initState();
    _addStation(name: "Т1");
    _addStation(name: "Т2");
    _addStation(name: "Т3");
  }

  @override
  void dispose() {
    _controllers.forEach((_, stationControllers) {
      stationControllers.forEach((_, controller) => controller.dispose());
    });
    _controllers.clear();
    _temporaryInputValues.clear();
    _inlineFieldErrors.clear();
    super.dispose();
  }

  void _initializeControllersForStation(String stationId, {
    String name = '',
    AngleDMS? angleDMSFromModel,
    String? distanceFromModel,
  }) {
    TheodoliteStation? currentStationFromList;
    try {
      currentStationFromList = _stations.firstWhere((s) => s.id == stationId);
    } catch (e) { /* Новая станция */ }

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

    _controllers[stationId] = {
      'name': TextEditingController(text: initialName),
      'angle_deg': TextEditingController(text: initialDeg),
      'angle_min': TextEditingController(text: initialMin),
      'angle_sec': TextEditingController(text: initialSec),
      'distance': TextEditingController(text: initialDist),
    };

    _controllers[stationId]!.forEach((key, controller) {
      controller.addListener(() {
        _temporaryInputValues.putIfAbsent(stationId, () => {})[key] = controller.text;
      });
    });
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
      _inlineFieldErrors.remove(stationId);
      _stations.removeAt(index);
    });
  }

  // --- УПРОЩЕННЫЙ Валидатор для Минут ---
  String? _validateMinutesInput(String? value, {required String stationId}) {
    final stationControllers = _controllers[stationId];
    if (stationControllers == null) return null;

    bool otherAnglePartsExist = stationControllers['angle_deg']!.text.isNotEmpty ||
        stationControllers['angle_sec']!.text.isNotEmpty;

    if (value == null || value.isEmpty) {
      return otherAnglePartsExist ? 'Нужно' : null;
    }

    final min = int.tryParse(value);
    if (min == null) return 'Число';
    if (min < 0 || min >= 60) return '0-59';
    return null;
  }

  // --- УПРОЩЕННЫЙ Валидатор для Секунд ---
  String? _validateSecondsInput(String? value, {required String stationId}) {
    final stationControllers = _controllers[stationId];
    if (stationControllers == null) return null;

    bool otherAnglePartsExist = stationControllers['angle_deg']!.text.isNotEmpty ||
        stationControllers['angle_min']!.text.isNotEmpty;

    if (value == null || value.isEmpty) {
      return otherAnglePartsExist ? 'Нужно' : null;
    }

    final sec = double.tryParse(value);
    if (sec == null) return 'Число';
    if (sec < 0.0 || sec >= 60.0) return '0-59.99';
    return null;
  }

  void _submitForm() {
    if (!_formSubmittedOnce) {
      setState(() {
        _formSubmittedOnce = true;
      });
    }

    final bool isFormGloballyValid = _formKey.currentState!.validate();

    bool hasInlineErrorsAfterValidation = false;
    _inlineFieldErrors.forEach((_, errors) {
      if (errors['minError'] != null || errors['secError'] != null) {
        hasInlineErrorsAfterValidation = true;
      }
    });

    bool conversionErrorEncountered = false;
    if (isFormGloballyValid && !hasInlineErrorsAfterValidation) {
      for (int i = 0; i < _stations.length; i++) {
        final stationId = _stations[i].id;
        final stationControllers = _controllers[stationId];
        if (stationControllers != null) {
          _stations[i].stationName = stationControllers['name']!.text;

          final degStr = stationControllers['angle_deg']!.text;
          final minStr = stationControllers['angle_min']!.text;
          final secStr = stationControllers['angle_sec']!.text;
          final distStr = stationControllers['distance']!.text;

          if (distStr.isEmpty || double.tryParse(distStr) == null || double.tryParse(distStr)! <=0) {
            _stations[i].distance = null;
          } else {
            _stations[i].distance = double.tryParse(distStr);
          }

          if (degStr.isEmpty && minStr.isEmpty && secStr.isEmpty) {
            _stations[i].horizontalAngle = null;
          } else {
            int degrees = int.tryParse(degStr.isNotEmpty ? degStr : "0") ?? 0;
            int minutes = int.tryParse(minStr.isNotEmpty ? minStr : "0") ?? 0;
            double seconds = double.tryParse(secStr.isNotEmpty ? secStr : "0.0") ?? 0.0;

            if (minutes < 0 || minutes >= 60 || seconds < 0.0 || seconds >= 60.0) {
              _stations[i].horizontalAngle = null;
              conversionErrorEncountered = true;
            } else {
              _stations[i].horizontalAngle = AngleDMS(degrees: degrees, minutes: minutes, seconds: seconds).toDecimalDegrees();
            }
          }
        }
      }
    }

    if (isFormGloballyValid && !hasInlineErrorsAfterValidation && !conversionErrorEncountered) {
      _temporaryInputValues.clear();
      _inlineFieldErrors.forEach((_, errors) => errors.clear());
      setState(() {
        _formSubmittedOnce = false;
      });
      widget.onSubmit(List.from(_stations));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, исправьте ошибки в полях ввода.')),
        );
      }
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
    final currentFieldErrors = _inlineFieldErrors.putIfAbsent(stationId, () => {});

    final generalAutovalidateMode = _formSubmittedOnce
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
                    autovalidateMode: generalAutovalidateMode,
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
                    autovalidateMode: generalAutovalidateMode,
                    validator: (value) {
                      bool otherAnglePartsExist = stationSpecificControllers['angle_min']!.text.isNotEmpty ||
                          stationSpecificControllers['angle_sec']!.text.isNotEmpty;
                      if (value == null || value.isEmpty) {
                        return otherAnglePartsExist ? 'Нужно' : null;
                      }
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
                    decoration: InputDecoration(
                      labelText: "Мин.'",
                      hintText: "ММ",
                      errorText: currentFieldErrors['minError'],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    textAlign: TextAlign.center,
                    autovalidateMode: AutovalidateMode.disabled,
                    onChanged: (value) {
                      setState(() {
                        // Убрали isIntermediate
                        currentFieldErrors['minError'] = _validateMinutesInput(value, stationId: stationId);
                      });
                      _temporaryInputValues.putIfAbsent(stationId, () => {})['angle_min'] = value;
                      if (_formSubmittedOnce && currentFieldErrors['minError'] == null) {
                        _formKey.currentState?.validate();
                      }
                    },
                    validator: (value) {
                      // Убрали isIntermediate
                      final error = _validateMinutesInput(value, stationId: stationId);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && currentFieldErrors['minError'] != error) {
                          setState(() {
                            currentFieldErrors['minError'] = error;
                          });
                        }
                      });
                      return error;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: stationSpecificControllers['angle_sec'],
                    decoration: InputDecoration(
                      labelText: 'Сек."',
                      hintText: "СС.сс",
                      errorText: currentFieldErrors['secError'],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), LengthLimitingTextInputFormatter(5)],
                    textAlign: TextAlign.center,
                    autovalidateMode: AutovalidateMode.disabled,
                    onChanged: (value) {
                      setState(() {
                        // Убрали isIntermediate
                        currentFieldErrors['secError'] = _validateSecondsInput(value, stationId: stationId);
                      });
                      _temporaryInputValues.putIfAbsent(stationId, () => {})['angle_sec'] = value;
                      if (_formSubmittedOnce && currentFieldErrors['secError'] == null) {
                        _formKey.currentState?.validate();
                      }
                    },
                    validator: (value) {
                      // Убрали isIntermediate
                      final error = _validateSecondsInput(value, stationId: stationId);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && currentFieldErrors['secError'] != error) {
                          setState(() {
                            currentFieldErrors['secError'] = error;
                          });
                        }
                      });
                      return error;
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
              autovalidateMode: generalAutovalidateMode,
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
                padding: const EdgeInsets.only(top: 8.0, bottom: 130.0),
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
