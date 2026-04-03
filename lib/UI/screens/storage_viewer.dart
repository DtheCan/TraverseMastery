import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
// Сервисы
import 'package:traversemastery/core/services/share_service.dart';
// Экраны и модели
import 'package:traversemastery/UI/screens/calculation_results_screen.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart';

// Модель для хранения информации о файле и его состоянии выбора
class SelectableFile {
  final FileSystemEntity fileEntity;
  final DateTime modifiedDate;
  bool isSelected;

  SelectableFile({
    required this.fileEntity,
    required this.modifiedDate,
    this.isSelected = false,
  });

  String get fileName => fileEntity.path.split(Platform.pathSeparator).last;
}

class StorageViewerScreen extends StatefulWidget {
  const StorageViewerScreen({super.key});

  @override
  State<StorageViewerScreen> createState() => _StorageViewerScreenState();
}

class _StorageViewerScreenState extends State<StorageViewerScreen> {
  Map<DateTime, List<SelectableFile>> _groupedFiles = {};
  Set<String> _selectedFilePaths = {};
  bool _isLoading = true;
  String _loadingError = '';
  bool _isLoadingFile = false; // Для индикатора загрузки файла

  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _loadAndGroupFiles();
  }

  Future<void> _loadAndGroupFiles({bool preserveSelection = false}) async {
    if (!preserveSelection) {
      _selectedFilePaths.clear();
    }
    setState(() {
      _isLoading = true;
      _loadingError = '';
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final savedDir = Directory(
        '${directory.path}/data/SavedCalculationResult',
      );
      Map<DateTime, List<SelectableFile>> tempGroupedFiles = {};

      if (await savedDir.exists()) {
        List<FileSystemEntity> files = await savedDir.list().toList();
        List<SelectableFile> selectableFiles = [];

        for (var entity in files) {
          if (entity is File && entity.path.endsWith('.json')) {
            FileStat stats = await entity.stat();
            bool wasSelected = _selectedFilePaths.contains(entity.path);
            selectableFiles.add(
              SelectableFile(
                fileEntity: entity,
                modifiedDate: stats.modified,
                isSelected: preserveSelection ? wasSelected : false,
              ),
            );
          }
        }
        selectableFiles.sort(
          (a, b) => b.modifiedDate.compareTo(a.modifiedDate),
        );
        for (var selectableFile in selectableFiles) {
          DateTime dateKey = DateUtils.dateOnly(selectableFile.modifiedDate);
          tempGroupedFiles.putIfAbsent(dateKey, () => []).add(selectableFile);
        }
      } else {
        _loadingError =
            'Папка с сохраненными расчетами не найдена. Ожидаемый путь: ${savedDir.path}';
      }
      _groupedFiles = tempGroupedFiles;
    } catch (e) {
      _loadingError = 'Произошла ошибка при загрузке файлов: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // НОВЫЙ МЕТОД: Загрузка и парсинг JSON файла
  Future<TraverseCalculationResult?> _loadCalculationResult(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      return TraverseCalculationResult.fromJson(jsonData);
    } catch (e) {
      print('Ошибка загрузки файла: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки файла: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  // НОВЫЙ МЕТОД: Открытие выбранного файла для просмотра
  Future<void> _openSelectedFileForViewing() async {
    // Проверяем, что выбран ровно один файл
    if (_selectedFilePaths.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите один файл для просмотра'),
        ),
      );
      return;
    }

    // Показываем индикатор загрузки
    setState(() => _isLoadingFile = true);

    final String filePath = _selectedFilePaths.first;
    final String fileName = filePath.split(Platform.pathSeparator).last;

    final result = await _loadCalculationResult(filePath);

    setState(() => _isLoadingFile = false);

    if (result != null && mounted) {
      // Переходим на экран результатов расчета
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => CalculationResultScreen(
                result: result,
                suggestedFileName: fileName.replaceAll('.json', ''),
              ),
        ),
      ).then((_) {
        // Обновляем список после возврата (на случай если файл был удален)
        _loadAndGroupFiles(preserveSelection: true);
      });
    }
  }

  void _toggleFileSelection(SelectableFile file) {
    setState(() {
      file.isSelected = !file.isSelected;
      if (file.isSelected) {
        _selectedFilePaths.add(file.fileEntity.path);
      } else {
        _selectedFilePaths.remove(file.fileEntity.path);
      }
    });
  }

  void _toggleDateGroupSelection(DateTime dateKey, bool selectAll) {
    setState(() {
      List<SelectableFile>? filesInGroup = _groupedFiles[dateKey];
      if (filesInGroup != null) {
        for (var fileInGroup in filesInGroup) {
          fileInGroup.isSelected = selectAll;
          if (selectAll) {
            _selectedFilePaths.add(fileInGroup.fileEntity.path);
          } else {
            _selectedFilePaths.remove(fileInGroup.fileEntity.path);
          }
        }
      }
    });
  }

  bool _areAllFilesInGroupSelected(DateTime dateKey) {
    List<SelectableFile>? filesInGroup = _groupedFiles[dateKey];
    if (filesInGroup == null || filesInGroup.isEmpty) return false;
    return filesInGroup.every((file) => file.isSelected);
  }

  Future<void> _handleShareSelectedFiles() async {
    if (_selectedFilePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите файлы для отправки.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Подготовка файлов к отправке... (${_selectedFilePaths.length} шт.)',
        ),
      ),
    );
    final status = await _shareService.shareMultipleFiles(
      filePaths: _selectedFilePaths.toList(),
      text:
          'Сохраненные результаты расчетов (${_selectedFilePaths.length} шт.)',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    if (status != null) {
      String message;
      switch (status) {
        case ShareResultStatus.success:
          message = 'Файлы успешно отправлены!';
          break;
        case ShareResultStatus.dismissed:
          message = 'Отправка отменена.';
          break;
        case ShareResultStatus.unavailable:
          message =
              'Не удалось отправить: один или несколько файлов недоступны.';
          break;
        default:
          message = 'Не удалось отправить файлы. Попробуйте еще раз.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось определить статус отправки файлов.'),
        ),
      );
    }
  }

  Future<void> _handleDeleteSelectedFiles() async {
    if (_selectedFilePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите файлы для удаления.'),
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтверждение удаления'),
          content: Text(
            'Вы уверены, что хотите удалить выбранные файлы (${_selectedFilePaths.length} шт.)? Это действие необратимо.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Удалить'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      int deletedCount = 0;
      List<String> errors = [];

      for (String filePath in _selectedFilePaths.toList()) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        } catch (e) {
          errors.add(filePath.split(Platform.pathSeparator).last);
          print('Ошибка удаления файла $filePath: $e');
        }
      }

      String message;
      if (errors.isEmpty) {
        message = 'Удалено файлов: $deletedCount.';
      } else {
        message =
            'Удалено: $deletedCount. Ошибка при удалении: ${errors.join(', ')}.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      _selectedFilePaths.clear();
      await _loadAndGroupFiles(preserveSelection: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<DateTime> sortedDateKeys =
        _groupedFiles.keys.toList()..sort((a, b) => b.compareTo(a));

    const double commonHorizontalPadding = 16.0;
    const EdgeInsets listTileContentPadding = EdgeInsets.only(
      left: commonHorizontalPadding,
      right: commonHorizontalPadding,
      top: 4.0,
      bottom: 4.0,
    );
    const EdgeInsets dateHeaderContentPadding = EdgeInsets.only(
      left: commonHorizontalPadding,
      right: commonHorizontalPadding,
      top: 12.0,
      bottom: 12.0,
    );

    // Определяем, должна ли быть видна FAB (ровно один файл выбран)
    final bool showFab = _selectedFilePaths.length == 1 && !_isLoadingFile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сохраненные расчеты'),
        elevation: 0,
        actions: [
          if (_selectedFilePaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Удалить выбранные',
              onPressed: _handleDeleteSelectedFiles,
            ),
          if (_selectedFilePaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Поделиться выбранными',
              onPressed: _handleShareSelectedFiles,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadingError.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(_loadingError, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _loadAndGroupFiles(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Попробовать снова'),
                    ),
                  ],
                ),
              )
              : _groupedFiles.isEmpty && _loadingError.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_alt, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Нет сохраненных расчетов',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Выполните расчет и сохраните результат',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
              : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh:
                        () => _loadAndGroupFiles(preserveSelection: true),
                    child: ListView.builder(
                      itemCount: sortedDateKeys.length,
                      itemBuilder: (context, dateIndex) {
                        final dateKey = sortedDateKeys[dateIndex];
                        final filesForDate = _groupedFiles[dateKey]!;
                        bool allFilesInThisGroupSelected =
                            _areAllFilesInGroupSelected(dateKey);

                        return Column(
                          children: [
                            CheckboxListTile(
                              title: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Divider(
                                    thickness: 1,
                                    color: Colors.grey,
                                  ),
                                  Container(
                                    color:
                                        Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'dd MMMM yyyy г.',
                                        'ru_RU',
                                      ).format(dateKey),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              value: allFilesInThisGroupSelected,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  _toggleDateGroupSelection(dateKey, value);
                                }
                              },
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                              controlAffinity: ListTileControlAffinity.trailing,
                              contentPadding: dateHeaderContentPadding,
                              dense: false,
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filesForDate.length,
                              itemBuilder: (context, fileIndex) {
                                final selectableFile = filesForDate[fileIndex];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color:
                                          selectableFile.isSelected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Colors.grey.withOpacity(0.2),
                                      width: selectableFile.isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    title: Text(
                                      selectableFile.fileName,
                                      style: TextStyle(
                                        fontWeight:
                                            selectableFile.isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${DateFormat('HH:mm', 'ru_RU').format(selectableFile.modifiedDate)} - ${(selectableFile.fileEntity.statSync().size / 1024).toStringAsFixed(1)} КБ',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    value: selectableFile.isSelected,
                                    onChanged: (bool? value) {
                                      _toggleFileSelection(selectableFile);
                                    },
                                    activeColor:
                                        Theme.of(context).colorScheme.primary,
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    contentPadding: listTileContentPadding,
                                    dense: true,
                                  ),
                                );
                              },
                            ),
                            if (dateIndex < sortedDateKeys.length - 1)
                              const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ),
                  // SafeArea для плавающей кнопки и других элементов
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
                      child: Stack(
                        children: [
                          // Плавающая кнопка для просмотра выбранного файла
                          if (showFab)
                            Positioned(
                              bottom: 0,
                              right: 16,
                              child: FloatingActionButton.extended(
                                onPressed: _openSelectedFileForViewing,
                                icon:
                                    _isLoadingFile
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.visibility),
                                label: Text(
                                  _isLoadingFile
                                      ? 'Загрузка...'
                                      : 'Просмотреть',
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                              ),
                            ),
                          // Подсказка при выборе одного файла
                          if (_selectedFilePaths.length == 1 && !showFab)
                            Positioned(
                              bottom: 0,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Загрузка...',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Информация о количестве выбранных файлов
                          if (_selectedFilePaths.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Выбрано: ${_selectedFilePaths.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
