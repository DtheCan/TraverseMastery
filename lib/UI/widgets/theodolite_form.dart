import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
// ЗАМЕНИТЕ 'traversemastery' на имя вашего проекта, если оно другое
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

  // Ключ: stationId, Значение: Map<String (fieldName), TextEditingController>
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  // Ключ: stationId, Значение: Map<String (fieldName), String (currentTextValue)>
  final Map<String, Map<String, String>> _temporaryInputValues = {};

  // Флаг, указывающий, была ли уже попытка отправки формы
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
    AngleDMS? angleDMSFromModel, // Угол из основной модели _stations
    String? distanceFromModel,   // Расстояние из основной модели _stations
  }) {
    // Получаем текущую станцию из списка _stations, чтобы проверить её сохраненные значения
    TheodoliteStation? currentStationFromList;
    try {
      currentStationFromList = _stations.firstWhere((s) => s.id == stationId);
    } catch (e) {
      // Станция может быть еще не в _stations, если это самый первый вызов для новой станции
    }

    final effectiveAngleDMS = angleDMSFromModel ?? AngleDMS(); // Если из модели null, то (0,0,0)
    final effectiveDistance = distanceFromModel ?? '';

    // Восстанавливаем временные значения, если они есть для этой станции
    final tempValuesForStation = _temporaryInputValues[stationId] ?? {};

    // Логика определения, должно ли поле быть пустым при инициализации
    // Поле пустое, если:
    // 1. Нет временного значения И (модельное значение null/0 ИЛИ AngleDMS компоненты все нули)
    bool isAngleActuallyNullOrZeroInModel = (currentStationFromList?.horizontalAngle == null || currentStationFromList?.horizontalAngle == 0.0);
    bool isDistanceActuallyNullOrZeroInModel = (currentStationFromList?.distance == null || currentStationFromList?.distance == 0.0);

    String initialDeg = tempValuesForStation['angle_deg'] ?? (isAngleActuallyNullOrZeroInModel && effectiveAngleDMS.degrees == 0 ? '' : effectiveAngleDMS.degrees.toString());
    String initialMin = tempValuesForStation['angle_min'] ?? (isAngleActuallyNullOrZeroInModel && effectiveAngleDMS.minutes == 0 ? '' : effectiveAngleDMS.minutes.toString());
    String initialSec = tempValuesForStation['angle_sec'] ?? (isAngleActuallyNullOrZeroInModel && effectiveAngleDMS.seconds == 0.0 ? '' : effectiveAngleDMS.seconds.toStringAsFixed(2));
    String initialDist = tempValuesForStation['distance'] ?? (isDistanceActuallyNullOrZeroInModel && effectiveDistance.isEmpty ? '' : effectiveDistance);
    String initialName = tempValuesForStation['name'] ?? name;


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

    // Добавляем слушателей для сохранения временных значений
    _controllers[stationId]!.forEach((key, controller) {
      controller.addListener(() {
        _temporaryInputValues.putIfAbsent(stationId, () => {})[key] = controller.text;
        // Если форма уже была отправлена один раз, инициируем повторную валидацию поля при изменении
        if (_formSubmittedOnce && _formKey.currentState != null) {
          _formKey.currentState!.validate();
        }
      });
    });
  }

  @override
  void dispose() {
    _controllers.forEach((stationId, stationControllers) {
      stationControllers.forEach((_, controller) {
        // Слушатели удаляются автоматически при dispose контроллера,
        // но для чистоты можно было бы хранить ссылки на слушатели и удалять их явно.
        // В данном случае, это не критично.
        controller.dispose();
      });
    });
    _controllers.clear();
    _temporaryInputValues.clear();
    super.dispose();
  }

  void _addStation({String name = '', double? initialAngleDecimal}) {
    setState(() {
      final stationId = _uuid.v4();
      final newStation = TheodoliteStation(id: stationId, stationName: name, horizontalAngle: initialAngleDecimal);
      _stations.add(newStation); // Добавляем в модель ДО инициализации контроллеров

      // При добавлении новой станции, ее значения в _temporaryInputValues еще не будет,
      // так что контроллеры получат значения из newStation (или пустые, если там null/0)
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
      // Удаляем слушателей и диспозим контроллеры
      _controllers[stationId]?.forEach((_, controller) {
        controller.dispose(); // Слушатели удалятся вместе с контроллером
      });
      _controllers.remove(stationId);
      _temporaryInputValues.remove(stationId);
      _stations.removeAt(index);
    });
  }

  void _submitForm() {
    setState(() {
      _formSubmittedOnce = true; // Устанавливаем флаг, что была попытка отправки
    });

    // Обновляем данные в _stations из контроллеров (или из _temporaryInputValues, которые уже в контроллерах)
    bool conversionError = false;
    for (int i = 0; i < _stations.length; i++) {
      final stationId = _stations[i].id;
      final stationControllers = _controllers[stationId];
      if (stationControllers != null) {
        _stations[i].stationName = stationControllers['name']!.text;

        final degStr = stationControllers['angle_deg']!.text;
        final minStr = stationControllers['angle_min']!.text;
        final secStr = stationControllers['angle_sec']!.text;
        final distStr = stationControllers['distance']!.text;

        // Расстояние
        if (distStr.isEmpty) {
          _stations[i].distance = null;
        } else {
          final distVal = double.tryParse(distStr);
          if (distVal != null && distVal > 0) {
            _stations[i].distance = distVal;
          } else {
            _stations[i].distance = null; // Невалидное расстояние сбрасываем, валидатор поймает
            // conversionError = true; // Можно добавить флаг, если нужно отдельное сообщение
          }
        }

        // Угол
        if (degStr.isEmpty && minStr.isEmpty && secStr.isEmpty) {
          _stations[i].horizontalAngle = null;
        } else {
          // Если хотя бы одно поле угла заполнено, пытаемся собрать.
          // Валидаторы полей должны обеспечить, что если одно заполнено, то и другие (или выдать ошибку "Нужно").
          int? degrees = int.tryParse(degStr.isNotEmpty ? degStr : "0");
          int? minutes = int.tryParse(minStr.isNotEmpty ? minStr : "0");
          double? seconds = double.tryParse(secStr.isNotEmpty ? secStr : "0.0");

          if (degrees != null && minutes != null && seconds != null) {
            if (minutes >= 0 && minutes < 60 && seconds >= 0.0 && seconds < 60.0) {
              _stations[i].horizontalAngle = AngleDMS(degrees: degrees, minutes: minutes, seconds: seconds).toDecimalDegrees();
            } else {
              _stations[i].horizontalAngle = null; // Невалидные минуты/секунды, валидатор поймает
              conversionError = true;
            }
          } else {
            _stations[i].horizontalAngle = null; // Ошибка парсинга, валидатор поймает
            conversionError = true;
          }
        }
      }
    }

    if (conversionError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка в значениях минут/секунд. Проверьте поля.')),
      );
      // Не продолжаем, если была явная ошибка конвертации, даже если валидаторы формы еще не сработали
      // return; // Раскомментировать, если хотим остановить здесь. Но лучше дать форме самой отвалидироваться.
    }


    if (_formKey.currentState!.validate()) {
      // Очищаем временные значения ПОСЛЕ успешной отправки,
      // так как они теперь сохранены в _stations.
      _temporaryInputValues.clear();
      _formSubmittedOnce = false; // Сбрасываем флаг для следующего цикла ввода
      widget.onSubmit(List.from(_stations));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, исправьте ошибки в полях ввода.')),
        );
      }
      // Не очищаем _temporaryInputValues, чтобы пользователь не потерял ввод при ошибке валидации
    }
  }


  Widget _buildStationInput(int index) {
    final station = _stations[index];
    final stationId = station.id;

    // Контроллеры должны быть уже инициализированы при добавлении станции
    // или при первом построении из initState.
    // Если по какой-то причине контроллера нет (не должно происходить в нормальном потоке),
    // инициализируем его здесь.
    if (!_controllers.containsKey(stationId)) {
      _initializeControllersForStation(
        stationId,
        name: station.stationName,
        angleDMSFromModel: AngleDMS.fromDecimalDegrees(station.horizontalAngle),
        distanceFromModel: station.distance?.toString(),
      );
    }

    final stationSpecificControllers = _controllers[stationId]!;

    // Валидация будет происходить при взаимодействии, если _formSubmittedOnce = true,
    // или при вызове _formKey.currentState.validate()
    AutovalidateMode currentAutovalidateMode = _formSubmittedOnce
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
                        return 'Название?'; // Имя станции делаем обязательным
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
                    inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), LengthLimitingTextInputFormatter(5) ],
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
              decoration: const InputDecoration(labelText: 'Расстояние до след. (метры)', hintText: 'например, 150.75'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
              autovalidateMode: currentAutovalidateMode,
              validator: (value) {
                // Если мы хотим, чтобы расстояние было необязательным для последней станции в ЗАМКНУТОМ ходе,
                // то для последней станции (index == _stations.length - 1) это поле может быть пустым.
                // Но для простоты сейчас оно всегда обязательно, если не пустое
                if (value == null || value.isEmpty) {
                  // Для замкнутого хода обычно все расстояния нужны.
                  // Если это последняя станция и мы хотим сделать его необязательным:
                  // if (index == _stations.length - 1 && _stations.length > 1) return null;
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
        // autovalidateMode теперь управляется индивидуально в TextFormField или при вызове validate()
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8.0, bottom: 80.0), // Отступ для кнопок внизу
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  return KeepAliveWrapper(
                    key: ValueKey(_stations[index].id), // Уникальный ключ для сохранения состояния
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
        bottom: MediaQuery.of(context).padding.bottom + 10.0, // Учитываем нижний SafeArea
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

