// lib/ui/screens/data_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:traversemastery/core/services/travers_calculator_service.dart';
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart';
import 'package:traversemastery/models/full_traverse_input.dart'; // Наша новая модель
import 'package:traversemastery/ui/screens/calculation_results_screen.dart';
import 'package:traversemastery/ui/widgets/theodolite_form.dart'; // Наша обновленная форма

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  final TraverseCalculatorService _calculatorService = TraverseCalculatorService();
  bool _isLoading = false;

  // Контроллеры и форма начальных данных удалены отсюда

  void _onCalculate(FullTraverseInput fullInput) async { // Принимает FullTraverseInput
    FocusScope.of(context).unfocus(); // Скрыть клавиатуру, если вдруг открыта

    // Валидация уже произошла внутри TheodoliteForm
    // Но можно добавить базовую проверку, если нужно
    if (fullInput.stations.isEmpty || fullInput.stations.length < 3) {
      _showErrorSnackBar('Недостаточно данных по станциям для расчета.');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Создаем объект TheodoliteStation для начальной точки на основе данных из fullInput
      final TheodoliteStation initialStationData = TheodoliteStation(
        // ID для начальной точки может быть сгенерирован заново или взят из первой станции,
        // но так как stations в fullInput - это только _измеренные_ данные,
        // лучше сгенерировать новый или использовать фиксированный.
        // Для примера, возьмем ID первой ИЗМЕРЕННОЙ станции, но это не всегда логично.
        // Лучше: id: _uuid.v4(), (если _uuid определен здесь или в сервисе)
        id: fullInput.stations.first.id, // Пример, может потребовать корректировки логики
        stationName: "Нач. точка (${fullInput.stations.first.stationName})", // Пример именования
        coordinateX: fullInput.initialX,
        coordinateY: fullInput.initialY,
        horizontalAngle: null,
        distance: null,
      );

      final TraverseCalculationResult result =
      await _calculatorService.calculateClosedTraverse(
        inputStations: fullInput.stations, // Это список ИЗМЕРЕННЫХ станций
        initialStationData: initialStationData, // Сформированная начальная станция
        initialDirectionAngleDegrees: fullInput.initialAzimuth,
        calculationName: fullInput.calculationName,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalculationResultScreen(
            result: result,
            suggestedFileName: result.calculationName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Ошибка расчета: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ввод данных теодолитного хода'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Text(
                'Меню',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Новый расчет'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('История расчетов'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar('Пункт "История расчетов" еще не реализован.');
              },
            ),
            // Spacer будет занимать все пространство МЕЖДУ верхними элементами
            // и нижней группой, обернутой в SafeArea
            const Spacer(),
            // Оборачиваем нижнюю группу в SafeArea, чтобы учесть системные отступы снизу
            SafeArea(
              top: false, // Нам не нужен отступ сверху для этой части
              bottom: true, // Включаем отступ снизу
              child: Column(
                mainAxisSize: MainAxisSize.min, // Чтобы Column занимал минимально необходимое место
                children: [
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Настройки'),
                    onTap: () {
                      Navigator.pop(context);
                      _showErrorSnackBar('Пункт "Настройки" еще не реализован.');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('О приложении'),
                    onTap: () {
                      Navigator.pop(context);
                      _showErrorSnackBar('Пункт "О приложении" еще не реализован.');
                    },
                  ),
                  // const SizedBox(height: 8.0), // Этот отступ теперь будет внутри SafeArea
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Выполняется расчет..."),
            ],
          ),
        )
            : TheodoliteForm(
          onSubmit: (FullTraverseInput submittedData) {
            _onCalculate(submittedData);
          },
        ),
      ),
    );
  }
}
