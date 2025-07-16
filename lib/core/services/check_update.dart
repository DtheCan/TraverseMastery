import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Для File
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
// import 'package:url_launcher/url_launcher.dart'; // Может не понадобиться, если скачивание и установка происходят внутри приложения
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart'; // Для скачивания
import 'package:open_filex/open_filex.dart'; // Для открытия APK
import 'package:permission_handler/permission_handler.dart'; // Для разрешений

class UpdateInfo {
  final bool isUpdateAvailable;
  final String? latestVersion;
  final String? currentVersion;
  final String? releaseNotes;
  final String? apkDownloadUrl; // URL для скачивания APK
  final String? releasePageUrl; // URL страницы релиза на GitHub

  UpdateInfo({
    required this.isUpdateAvailable,
    this.latestVersion,
    this.currentVersion,
    this.releaseNotes,
    this.apkDownloadUrl,
    this.releasePageUrl,
  });
}

enum DownloadProgressStatus {
  idle,
  downloading,
  completed,
  error,
}

class CheckUpdateService with ChangeNotifier {
  UpdateInfo? _updateInfo;
  bool _isLoadingVersionCheck = false;
  String? _errorMessage;

  DownloadProgressStatus _downloadStatus = DownloadProgressStatus.idle;
  double _downloadProgress = 0.0;
  String? _downloadedApkPath;

  UpdateInfo? get updateInfo => _updateInfo;
  bool get isLoadingVersionCheck => _isLoadingVersionCheck;
  String? get errorMessage => _errorMessage;

  DownloadProgressStatus get downloadStatus => _downloadStatus;
  double get downloadProgress => _downloadProgress;
  String? get downloadedApkPath => _downloadedApkPath;

  // --- ВАЖНО: ЗАМЕНИТЕ ЭТИ ЗНАЧЕНИЯ ---
  final String _githubOwner = 'DtheCan'; // Пример: 'YourGitHubUsername'
  final String _githubRepo = 'TraverseMastery'; // Пример: 'YourRepoName'
  final String _apkAssetName = 'TraverseMastery.apk'; // Имя вашего APK файла в релизах GitHub
  // --- КОНЕЦ ВАЖНЫХ ЗНАЧЕНИЙ ---

  CheckUpdateService() {
    // Небольшая задержка перед первой проверкой, чтобы дать приложению прогрузиться
    Future.delayed(const Duration(seconds: 2), () {
      if (_updateInfo == null && !_isLoadingVersionCheck) {
        checkForUpdates();
      }
    });
  }

  Future<void> checkForUpdates() async {
    if (_isLoadingVersionCheck) return;
    _isLoadingVersionCheck = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final Uri latestReleaseUrl = Uri.parse('https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest');
      print('CheckUpdateService: Запрос на $latestReleaseUrl');

      final response = await http.get(latestReleaseUrl, headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 15));

      print('CheckUpdateService: Ответ от GitHub API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> releaseData = json.decode(response.body);
        String latestVersionTag = releaseData['tag_name'] ?? '';
        if (latestVersionTag.startsWith('v')) {
          latestVersionTag = latestVersionTag.substring(1);
        }

        bool isUpdateAvailable = _isVersionGreaterThan(latestVersionTag, currentVersion);
        String? apkUrl;

        if (isUpdateAvailable) {
          final List<dynamic> assets = releaseData['assets'] as List<dynamic>? ?? [];
          for (var asset in assets) {
            if (asset is Map<String, dynamic> && asset['name'] == _apkAssetName) {
              apkUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
          if (apkUrl == null) {
            print('CheckUpdateService: APK файл "$_apkAssetName" не найден в релизе $latestVersionTag. Обновление не будет предложено.');
            // isUpdateAvailable = false; // Важно, если APK не найден, обновление не доступно для установки через приложение
          }
        }

        _updateInfo = UpdateInfo(
          isUpdateAvailable: isUpdateAvailable && apkUrl != null, // Обновление доступно только если есть APK
          latestVersion: latestVersionTag,
          currentVersion: currentVersion,
          releaseNotes: releaseData['body'] as String?,
          apkDownloadUrl: apkUrl,
          releasePageUrl: releaseData['html_url'] as String?,
        );
        print('CheckUpdateService: Обновление доступно: ${isUpdateAvailable && apkUrl != null}, Последняя версия: $latestVersionTag, APK URL: $apkUrl');
      } else {
        _errorMessage = 'Ошибка получения данных с GitHub: ${response.statusCode} - ${response.reasonPhrase}';
        print('CheckUpdateService: Ошибка: $_errorMessage');
        _updateInfo = UpdateInfo(isUpdateAvailable: false, currentVersion: currentVersion);
      }
    } catch (e, s) {
      _errorMessage = 'Ошибка проверки обновлений: ${e.toString()}';
      print('CheckUpdateService: Исключение: $_errorMessage');
      print('CheckUpdateService: StackTrace: $s');
      try {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        _updateInfo = UpdateInfo(isUpdateAvailable: false, currentVersion: packageInfo.version);
      } catch (_) {
        _updateInfo = UpdateInfo(isUpdateAvailable: false, currentVersion: "N/A");
      }
    } finally {
      _isLoadingVersionCheck = false;
      notifyListeners();
      print('CheckUpdateService: Проверка обновлений завершена.');
    }
  }

  bool _isVersionGreaterThan(String v1, String v2) {
    if (v1.isEmpty || v2.isEmpty || v1 == v2) return false;
    List<int> parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < parts1.length; i++) {
      if (i >= parts2.length) return true; // v1 длиннее, например 1.0.0 vs 1.0
      if (parts1[i] > parts2[i]) return true;
      if (parts1[i] < parts2[i]) return false;
    }
    // Если все предыдущие части равны, но v2 длиннее (например, 1.0 vs 1.0.1), то v1 не больше.
    return parts1.length > parts2.length;
  }

  Future<void> downloadAndInstallUpdate() async {
    if (_updateInfo?.apkDownloadUrl == null) {
      _errorMessage = "URL для скачивания APK отсутствует.";
      _downloadStatus = DownloadProgressStatus.error; // Устанавливаем статус ошибки
      notifyListeners();
      return;
    }
    if (_downloadStatus == DownloadProgressStatus.downloading) return;

    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      _errorMessage = "Разрешения не предоставлены для скачивания или установки.";
      _downloadStatus = DownloadProgressStatus.error;
      notifyListeners();
      return;
    }

    _downloadStatus = DownloadProgressStatus.downloading;
    _downloadProgress = 0.0;
    _downloadedApkPath = null;
    _errorMessage = null; // Сбрасываем предыдущую ошибку
    notifyListeners();

    try {
      final Dio dio = Dio();
      final Directory? tempDir = await getTemporaryDirectory();
      if (tempDir == null) {
        _errorMessage = "Не удалось получить временную директорию.";
        _downloadStatus = DownloadProgressStatus.error;
        notifyListeners();
        return;
      }
      final String fileName = _apkAssetName; // Используем имя ассета
      final String savePath = '${tempDir.path}/$fileName';

      print('CheckUpdateService: Скачивание APK с ${_updateInfo!.apkDownloadUrl!} в $savePath');

      await dio.download(
        _updateInfo!.apkDownloadUrl!,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgress = received / total;
            notifyListeners();
          }
        },
      );

      _downloadStatus = DownloadProgressStatus.completed;
      _downloadedApkPath = savePath;
      print('CheckUpdateService: APK скачан: $savePath');
      notifyListeners();

      // Автоматически пытаемся установить после скачивания
      await installApk(savePath); // <--- ИЗМЕНЕНИЕ: вызываем публичный метод

    } on DioException catch (e) {
      _errorMessage = 'Ошибка скачивания: ${e.message ?? e.toString()}';
      _downloadStatus = DownloadProgressStatus.error;
      print('CheckUpdateService: DioError - ${e.toString()}');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Общая ошибка скачивания: ${e.toString()}';
      _downloadStatus = DownloadProgressStatus.error;
      print('CheckUpdateService: General Error - ${e.toString()}');
      notifyListeners();
    }
  }

  Future<bool> _requestPermissions() async {
    // Для Android < 13 может понадобиться Permission.storage (WRITE_EXTERNAL_STORAGE)
    // если пишете не в приватные папки. Для getTemporaryDirectory() обычно не нужно.
    // Для Android 13+ используйте более гранулярные разрешения, если пишете не в приватную папку.

    // Ключевое разрешение - на установку пакетов.
    if (Platform.isAndroid) {
      var installPermissionStatus = await Permission.requestInstallPackages.status;
      if (!installPermissionStatus.isGranted) {
        installPermissionStatus = await Permission.requestInstallPackages.request();
        if (!installPermissionStatus.isGranted) {
          print("Разрешение REQUEST_INSTALL_PACKAGES не предоставлено. Пользователь должен включить его в настройках.");
          // Можно добавить openAppSettings(); чтобы направить пользователя.
          // Либо показать SnackBar/Dialog с этой информацией.
          // openAppSettings();
          return false;
        }
      }
    }
    return true; // Если дошли сюда, основное разрешение получено или не требуется (не Android)
  }

  Future<void> installApk(String apkPath) async {
    if (apkPath.isEmpty) {
      _errorMessage = "Путь к APK для установки не указан.";
      // _downloadStatus = DownloadProgressStatus.error;
      notifyListeners();
      return;
    }

    // Дополнительная проверка разрешения перед попыткой открыть файл
    // Это важно, если метод вызывается отдельно от downloadAndInstallUpdate
    if (Platform.isAndroid) {
      final bool canInstall = await Permission.requestInstallPackages.isGranted;
      if (!canInstall) {
        _errorMessage = "Разрешение на установку пакетов не предоставлено. Перейдите в настройки.";
        print("CheckUpdateService: Попытка установки без разрешения REQUEST_INSTALL_PACKAGES.");
        _downloadStatus = DownloadProgressStatus.error; // Указываем на ошибку
        notifyListeners();
        // openAppSettings(); // Предложить пользователю открыть настройки
        return;
      }
    }

    print("CheckUpdateService: Попытка установки APK из $apkPath");
    final OpenResult result = await OpenFilex.open(apkPath, type: 'application/vnd.android.package-archive');

    switch (result.type) {
      case ResultType.done:
        print('APK файл успешно открыт для установки системой.');
        // Если установка инициирована, можно сбросить состояние загрузки
        // _downloadStatus = DownloadProgressStatus.idle;
        // _downloadedApkPath = null;
        // notifyListeners(); // Уведомить об изменении состояния
        break;
      case ResultType.error:
        _errorMessage = 'Ошибка при открытии APK файла: ${result.message}';
        print('OpenFilex error: ${result.message}');
        _downloadStatus = DownloadProgressStatus.error; // Указываем на ошибку
        notifyListeners();
        break;
      case ResultType.fileNotFound:
        _errorMessage = 'Файл APK не найден: $apkPath';
        print('OpenFilex error: File not found at $apkPath');
        _downloadStatus = DownloadProgressStatus.error;
        notifyListeners();
        break;
      case ResultType.noAppToOpen:
        _errorMessage = 'Нет приложения для открытия APK (маловероятно для Android).';
        print('OpenFilex error: No app to open APK');
        _downloadStatus = DownloadProgressStatus.error;
        notifyListeners();
        break;
      case ResultType.permissionDenied:
        _errorMessage = 'Отказано в разрешении на открытие файла APK (не путать с REQUEST_INSTALL_PACKAGES).';
        print('OpenFilex error: Permission denied to open APK');
        _downloadStatus = DownloadProgressStatus.error;
        notifyListeners();
        break;
    }
  }

  // Для перехода на страницу релизов, если скачивание/установка не удались
  // или если пользователь хочет увидеть детали релиза на GitHub.
  Future<void> launchReleasePageUrl() async {
    if (_updateInfo?.releasePageUrl != null) {
      final Uri url = Uri.parse(_updateInfo!.releasePageUrl!);
      // Для этого потребуется импорт 'package:url_launcher/url_launcher.dart';
      // if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      //   _errorMessage = 'Не удалось открыть URL: ${url.toString()}';
      //   notifyListeners();
      //    print('CheckUpdateService: Не удалось запустить URL: $url');
      // } else {
      //    print('CheckUpdateService: URL страницы релиза открыт: $url');
      // }
      print("Для просмотра страницы релиза, перейдите на: ${url.toString()}"); // Заглушка, если url_launcher не используется активно
    } else {
      _errorMessage = 'URL страницы релиза недоступен.';
      notifyListeners();
      print('CheckUpdateService: URL страницы релиза отсутствует.');
    }
  }
}
