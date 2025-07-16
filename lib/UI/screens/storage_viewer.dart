import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // Для ShareResultStatus
// Сервисы
import 'package:traversemastery/core/services/share_service.dart'; // Импорт обновленного ShareService

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

  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _loadAndGroupFiles();
  }

  Future<void> _loadAndGroupFiles({bool preserveSelection = false}) async { // Добавлен параметр
    if (!preserveSelection) {
      _selectedFilePaths.clear(); // Сбрасываем выделение, если не указано иное
    }
    setState(() {
      _isLoading = true;
      _loadingError = '';
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final savedDir = Directory('${directory.path}/data/SavedCalculationResult');
      Map<DateTime, List<SelectableFile>> tempGroupedFiles = {};

      if (await savedDir.exists()) {
        List<FileSystemEntity> files = await savedDir.list().toList();
        List<SelectableFile> selectableFiles = [];

        for (var entity in files) {
          if (entity is File) {
            FileStat stats = await entity.stat();
            bool wasSelected = _selectedFilePaths.contains(entity.path);
            selectableFiles.add(SelectableFile(
              fileEntity: entity,
              modifiedDate: stats.modified,
              isSelected: preserveSelection ? wasSelected : false, // Учитываем preserveSelection
            ));
          }
        }
        selectableFiles.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
        for (var selectableFile in selectableFiles) {
          DateTime dateKey = DateUtils.dateOnly(selectableFile.modifiedDate);
          tempGroupedFiles.putIfAbsent(dateKey, () => []).add(selectableFile);
        }
      } else {
        _loadingError = 'Папка с сохраненными расчетами не найдена. Ожидаемый путь: ${savedDir.path}';
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
        const SnackBar(content: Text('Пожалуйста, выберите файлы для отправки.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Подготовка файлов к отправке... (${_selectedFilePaths.length} шт.)')),
    );
    final status = await _shareService.shareMultipleFiles(
      filePaths: _selectedFilePaths.toList(),
      text: 'Сохраненные результаты расчетов (${_selectedFilePaths.length} шт.)',
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
          message = 'Не удалось отправить: один или несколько файлов недоступны.';
          break;
        default:
          message = 'Не удалось отправить файлы. Попробуйте еще раз.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить статус отправки файлов.')),
      );
    }
  }

  // НОВЫЙ МЕТОД ДЛЯ УДАЛЕНИЯ ФАЙЛОВ
  Future<void> _handleDeleteSelectedFiles() async {
    if (_selectedFilePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите файлы для удаления.')),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтверждение удаления'),
          content: Text('Вы уверены, что хотите удалить выбранные файлы (${_selectedFilePaths.length} шт.)? Это действие необратимо.'),
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

      for (String filePath in _selectedFilePaths.toList()) { // toList() для безопасного изменения _selectedFilePaths
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
        message = 'Удалено: $deletedCount. Ошибка при удалении: ${errors.join(', ')}.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      // Обновляем список файлов и сбрасываем выделение
      _selectedFilePaths.clear();
      await _loadAndGroupFiles(preserveSelection: false); // Перезагружаем список, сбрасывая выделение
    }
  }

  @override
  Widget build(BuildContext context) {
    List<DateTime> sortedDateKeys = _groupedFiles.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    const double commonHorizontalPadding = 16.0;
    const EdgeInsets listTileContentPadding = EdgeInsets.only(left: commonHorizontalPadding, right: commonHorizontalPadding, top: 4.0, bottom: 4.0);
    const EdgeInsets dateHeaderContentPadding = EdgeInsets.only(left: commonHorizontalPadding, right: commonHorizontalPadding, top: 12.0, bottom: 12.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сохраненные расчеты'),
        elevation: 0,
        actions: [
          // НОВАЯ КНОПКА УДАЛЕНИЯ
          if (_selectedFilePaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent), // Иконка удаления
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadingError.isNotEmpty
          ? Center( /* ... ваш код для отображения ошибки ... */ )
          : _groupedFiles.isEmpty && _loadingError.isEmpty
          ? Center( /* ... ваш код для "нет расчетов" ... */ )
          : RefreshIndicator(
        onRefresh: () => _loadAndGroupFiles(preserveSelection: true), // Сохраняем выделение при ручном обновлении
        child: ListView.builder(
          itemCount: sortedDateKeys.length,
          itemBuilder: (context, dateIndex) {
            // ... остальная часть вашего ListView.builder без изменений ...
            final dateKey = sortedDateKeys[dateIndex];
            final filesForDate = _groupedFiles[dateKey]!;
            bool allFilesInThisGroupSelected = _areAllFilesInGroupSelected(dateKey);

            return Column(
              children: [
                CheckboxListTile(
                  title: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Divider(thickness: 1, color: Colors.grey),
                      Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          DateFormat('dd MMMM yyyy г.', 'ru_RU').format(dateKey),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
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
                  activeColor: Theme.of(context).colorScheme.primary,
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
                    return CheckboxListTile(
                      title: Text(selectableFile.fileName),
                      subtitle: Text(
                        '${DateFormat('HH:mm', 'ru_RU').format(selectableFile.modifiedDate)} - ${(selectableFile.fileEntity.statSync().size / 1024).toStringAsFixed(1)} КБ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: selectableFile.isSelected,
                      onChanged: (bool? value) {
                        _toggleFileSelection(selectableFile);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: listTileContentPadding,
                      dense: true,
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
    );
  }
}

