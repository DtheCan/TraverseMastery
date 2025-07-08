import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/theodolite_station.dart';

class TheodoliteForm extends StatefulWidget {
  const TheodoliteForm({super.key});

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
    _addStation();
  }

  void _initializeControllersForStation(String stationId) {
    _controllers[stationId] = {
      'name': TextEditingController(),
      'angle': TextEditingController(),
      'distance': TextEditingController(),
    };
    // Если у станции уже есть данные, заполняем контроллеры
    final stationData = _stations.firstWhere((s) => s.id == stationId, orElse: () => TheodoliteStation(id: 'temp')); // orElse для безопасности
    if(stationData.id != 'temp') { // Проверяем, что станция найдена
      _controllers[stationId]!['name']!.text = stationData.stationName;
      _controllers[stationId]!['angle']!.text = stationData.horizontalAngle?.toString() ?? '';
      _controllers[stationId]!['distance']!.text = stationData.distance?.toString() ?? '';
    }
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

  void _addStation() {
    setState(() {
      final stationId = _uuid.v4();
      // Сначала добавляем станцию в список
      _stations.add(TheodoliteStation(id: stationId));
      // Затем инициализируем контроллеры для нее
      _initializeControllersForStation(stationId);
    });
  }

  void _removeStation(int index) {
    // Безопасное удаление, если станций больше одной
    if (_stations.length > 1) {
      setState(() {
        final stationId = _stations[index].id;
        _disposeControllersForStation(stationId);
        _stations.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить последнюю станцию')),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      for (int i = 0; i < _stations.length; i++) {
        final stationId = _stations[i].id;
        if (_controllers.containsKey(stationId)) { // Добавлена проверка на существование ключа
          _stations[i].stationName = _controllers[stationId]!['name']!.text;
          _stations[i].horizontalAngle = double.tryParse(_controllers[stationId]!['angle']!.text);
          _stations[i].distance = double.tryParse(_controllers[stationId]!['distance']!.text);
        }
      }

      print('Данные теодолитного хода:');
      for (var station in _stations) {
        print('Станция ID: ${station.id}');
        print('  Название: ${station.stationName}');
        print('  Угол: ${station.horizontalAngle}');
        print('  Расстояние: ${station.distance}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные сохранены (пока без расчета)!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, исправьте ошибки в форме.')),
      );
    }
  }

  Widget _buildStationInput(int index) {
    final station = _stations[index];
    final stationId = station.id;

    if (!_controllers.containsKey(stationId)) {
      _initializeControllersForStation(stationId);
    }


    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Добавлен горизонтальный отступ
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Станция ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                if (_stations.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _removeStation(index),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _controllers[stationId]!['name'],
              decoration: const InputDecoration(labelText: 'Название станции (Тчк. Набл.)'),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Введите название станции';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _controllers[stationId]!['angle'],
              decoration: const InputDecoration(labelText: 'Горизонтальный угол (градусы)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value != null && value.isNotEmpty && double.tryParse(value) == null) return 'Введите корректное число';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _controllers[stationId]!['distance'],
              decoration: const InputDecoration(labelText: 'Расстояние (метры)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value != null && value.isNotEmpty && double.tryParse(value) == null) return 'Введите корректное число';
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
    // Обернем Form в SafeArea, чтобы избежать перекрытия системными элементами сверху и снизу
    // но только для основного контента, а кнопки разместим отдельно
    return SafeArea(
      // Убираем отступы SafeArea снизу, т.к. мы сами будем управлять отступом кнопок
      bottom: false,
      child: Form(
        key: _formKey,
        child: Column( // Основной Column для разделения списка и кнопок
          children: [
            Expanded( // ListView.builder будет занимать все доступное пространство
              child: ListView.builder(
                // Убираем отступы ListView, так как Card уже имеет свои
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), // Отступы только сверху и снизу списка
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  return _buildStationInput(index);
                },
              ),
            ),
            // Контейнер для кнопок внизу
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  // Новый виджет для нижних кнопок
  Widget _buildBottomButtons() {
    return Container(
      // Добавляем отступ снизу, равный системному отступу + небольшой дополнительный
      // Это гарантирует, что кнопки будут над системной навигацией
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 10.0,
        bottom: MediaQuery.of(context).padding.bottom + 10.0, // Учитываем нижний системный отступ
      ),
      // Можно добавить цвет фона, если тема вашего Scaffold прозрачная или отличается
      // color: Theme.of(context).bottomAppBarTheme.color ?? Theme.of(context).colorScheme.surface,
      // Можно добавить разделитель сверху
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // Используем цвет поверхности из темы
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2), // Тень вверх
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Чтобы Column занимал минимально необходимую высоту
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
              // Можно сделать эту кнопку более выделяющейся (основной)
              // backgroundColor: Theme.of(context).colorScheme.primary,
              // foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Сохранить и Рассчитать'),
          ),
        ],
      ),
    );
  }
}

