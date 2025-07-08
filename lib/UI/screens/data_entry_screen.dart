import 'package:flutter/material.dart';
import 'package:traversemastery/core/services/travers_calculator_service.dart';
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart';
import 'package:traversemastery/ui/screens/calculation_results_screen.dart';
import 'package:traversemastery/ui/widgets/theodolite_form.dart';

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  // Убедитесь, что TraverseCalculatorService инициализируется корректно
  final TraverseCalculatorService _calculatorService = TraverseCalculatorService();
  bool _isLoading = false;

  void _onCalculate(List<TheodoliteStation> stations) async {
    if (!mounted) return; // Проверка mounted в самом начале

    if (stations.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для расчета замкнутого хода необходимо минимум 3 станции с данными.')),
      );
      return;
    }

    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      final stationIdentifier = station.stationName.isNotEmpty ? station.stationName : '№${i + 1}';
      if (station.horizontalAngle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Отсутствует горизонтальный угол для станции $stationIdentifier')),
        );
        return;
      }
      if (station.distance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Отсутствует расстояние для стороны от станции $stationIdentifier')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final TraverseCalculationResult result = await _calculatorService.calculateClosedTraverse(stations);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalculationResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();
      if (e is ArgumentError) { // Более специфичная обработка для ArgumentError
        errorMessage = e.message ?? "Неизвестная ошибка аргумента";
      } else {
        errorMessage = errorMessage.replaceFirst("Exception: ", ""); // Убираем общий префикс
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка расчета: $errorMessage'),
          duration: const Duration(seconds: 5),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ввод данных замкнутого теодолитного хода'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Выполняется расчет...",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      )
      // Убедитесь, что класс TheodoliteForm импортирован и его конструктор соответствует
          : TheodoliteForm(
        onSubmit: _onCalculate,
      ),
    );
  }
}
