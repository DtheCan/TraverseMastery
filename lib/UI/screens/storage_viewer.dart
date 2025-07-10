import 'package:flutter/material.dart';
import 'dart:io'; // Для работы с файлами, понадобится позже
import 'package:path_provider/path_provider.dart'; // Для получения пути к документам

class StorageViewerScreen extends StatefulWidget {
  const StorageViewerScreen({super.key});

  @override
  State<StorageViewerScreen> createState() => _StorageViewerScreenState();
}

class _StorageViewerScreenState extends State<StorageViewerScreen> {
  List<FileSystemEntity> _savedFiles = [];
  bool _isLoading = true;
  String _loadingError = '';

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
  }

  Future<void> _loadSavedFiles() async {
    setState(() {
      _isLoading = true;
      _loadingError = '';
    });
    try {
      // TODO: Заменить "SavedCalculationResult" на актуальное имя вашей папки, если оно другое
      final directory = await getApplicationDocumentsDirectory();
      final savedDir = Directory('${directory.path}/SavedCalculationResult');

      if (await savedDir.exists()) {
        // Получаем список файлов, можно отфильтровать по расширению, если нужно
        // например, .where((item) => item.path.endsWith('.json') || item.path.endsWith('.pdf'))
        _savedFiles = await savedDir.list().toList();
        // Сортировка по дате изменения (новые сверху), если нужно
        _savedFiles.sort((a, b) {
          try {
            FileStat statA = a.statSync();
            FileStat statB = b.statSync();
            return statB.modified.compareTo(statA.modified);
          } catch (e) {
            return 0; // В случае ошибки при доступе к стату файла
          }
        });

      } else {
        _savedFiles = [];
        // Можно установить _loadingError, если папка должна существовать
        // _loadingError = 'Папка с сохраненными расчетами не найдена.';
      }
    } catch (e) {
      print('Ошибка загрузки файлов: $e');
      _loadingError = 'Произошла ошибка при загрузке файлов: ${e.toString()}';
      _savedFiles = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Вспомогательный метод для получения имени файла из пути
  String _getFileName(FileSystemEntity file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сохраненные расчеты'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadingError.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _loadingError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : _savedFiles.isEmpty
          ? const Center(
        child: Text(
          'Сохраненных расчетов пока нет.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : RefreshIndicator( // Добавляем возможность обновить список свайпом вниз
        onRefresh: _loadSavedFiles,
        child: ListView.builder(
          itemCount: _savedFiles.length,
          itemBuilder: (context, index) {
            final file = _savedFiles[index];
            final fileName = _getFileName(file);
            // TODO: Здесь можно будет отображать более подробную информацию о файле
            // или иконку в зависимости от типа файла
            return ListTile(
              leading: Icon(
                  fileName.endsWith('.json') ? Icons.data_object :
                  fileName.endsWith('.pdf') ? Icons.picture_as_pdf_outlined :
                  Icons.insert_drive_file_outlined // Иконка по умолчанию
              ),
              title: Text(fileName),
              // subtitle: Text('Дата изменения: ${file.statSync().modified}'), // Пример
              onTap: () {
                // TODO: Действие при нажатии на файл (например, открытие)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Выбран файл: $fileName (пока не открывается)')),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
