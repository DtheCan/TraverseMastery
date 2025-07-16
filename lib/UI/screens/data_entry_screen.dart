import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:traversemastery/core/services/check_update.dart';
import 'package:traversemastery/core/services/travers_calculator_service.dart';
import 'package:traversemastery/models/full_traverse_input.dart';
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart';
import 'package:traversemastery/ui/screens/about_the_application.dart';
import 'package:traversemastery/ui/screens/calculation_results_screen.dart';
import 'package:traversemastery/ui/screens/storage_viewer.dart';
import 'package:traversemastery/ui/widgets/theodolite_form.dart';

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  final TraverseCalculatorService _calculatorService = TraverseCalculatorService();
  bool _isLoading = false;

  // Контроллеры и форма начальных данных удалены отсюда

  void _onCalculate(FullTraverseInput fullInput) async {
    FocusScope.of(context).unfocus();

    if (fullInput.stations.isEmpty || fullInput.stations.length < 3) {
      _showErrorSnackBar('Недостаточно данных по станциям для расчета.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final TheodoliteStation initialStationData = TheodoliteStation(
        id: fullInput.stations.first.id,
        stationName: "Нач. точка (${fullInput.stations.first.stationName})",
        coordinateX: fullInput.initialX,
        coordinateY: fullInput.initialY,
        horizontalAngle: null,
        distance: null,
      );

      final TraverseCalculationResult result =
      await _calculatorService.calculateClosedTraverse(
        inputStations: fullInput.stations,
        initialStationData: initialStationData,
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
        setState(() {
          _isLoading = false;
        });
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

  // <--- ИСПРАВЛЕНИЕ 1: Метод _extractFileName добавлен в класс --->
  String _extractFileName(String? path) {
    if (path == null || path.isEmpty) return '';
    return path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ввод данных теодолитного хода'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              DrawerHeader(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Меню',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Хранилище'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StorageViewerScreen()),
                  );
                },
              ),
              Consumer<CheckUpdateService>(
                builder: (context, updateService, child) {
                  final updateInfo = updateService.updateInfo;
                  final downloadStatus = updateService.downloadStatus;

                  if (updateInfo != null && updateInfo.isUpdateAvailable) {
                    String buttonText = 'Обновить до ${updateInfo.latestVersion ?? ""}';
                    Widget leadingIcon = const Icon(Icons.system_update_alt, color: Colors.white);
                    VoidCallback? onPressedAction = () {
                      updateService.downloadAndInstallUpdate();
                    };

                    if (downloadStatus == DownloadProgressStatus.downloading) {
                      buttonText = 'Загрузка... ${(updateService.downloadProgress * 100).toStringAsFixed(0)}%';
                      leadingIcon = SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: updateService.downloadProgress,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      );
                      onPressedAction = null;
                    } else if (downloadStatus == DownloadProgressStatus.completed) {
                      // Используем метод _extractFileName из этого класса
                      buttonText = 'Установить (${_extractFileName(updateService.downloadedApkPath)})';
                      leadingIcon = const Icon(Icons.install_mobile, color: Colors.white);
                      onPressedAction = () {
                        if (updateService.downloadedApkPath != null) {
                          // <--- ИСПРАВЛЕНИЕ 2: Вызываем публичный метод installApk --->
                          updateService.installApk(updateService.downloadedApkPath!);
                        }
                      };
                    } else if (downloadStatus == DownloadProgressStatus.error) {
                      buttonText = 'Ошибка. Попробовать снова?';
                      leadingIcon = const Icon(Icons.error_outline, color: Colors.red);
                      // Позволяем пользователю попробовать снова скачать и установить
                      onPressedAction = () {
                        updateService.downloadAndInstallUpdate();
                      };
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      child: InkWell(
                        onTap: onPressedAction,
                        borderRadius: BorderRadius.circular(8.0),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: onPressedAction == null
                                ? LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700])
                                : const LinearGradient(
                              colors: [Colors.blueAccent, Colors.greenAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [ // Добавил небольшую тень для лучшего визуального эффекта
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                            child: Row(
                              children: [
                                leadingIcon,
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    buttonText,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    if (updateService.isLoadingVersionCheck && updateInfo == null) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text("Проверка обновлений...")
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                },
              ),
              const Spacer(),
              SafeArea( // Обертка для нижних элементов, чтобы они не заезжали под системные элементы
                top: false, // Не влияет на верхнюю часть, так как уже есть Spacer
                bottom: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Чтобы Column занимал минимально необходимое место
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('О приложении'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AboutTheApplicationScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
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

