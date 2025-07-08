import 'package:traversemastery/models/theodolite_station.dart'; // Путь к вашей модели станции

// Единицы измерения углов (опционально, но полезно для ясности)
enum AngleUnit { degrees, radians }

class TraverseCalculationResult {
  final List<TheodoliteStation> inputStations; // Входные данные
  final DateTime calculationDate;

  // Суммы и невязки
  final double sumMeasuredAngles;     // Сумма изм. (внутренних) углов
  final double theoreticalSumAngles;  // Теоретическая сумма углов (n-2)*180
  final double angularMisclosure;     // Угловая невязка
  final double permissibleAngularMisclosure; // Допустимая угловая невязка
  final bool isAngularMisclosureAcceptable;

  // Исправленные углы
  final List<double> correctedAngles; // Исправленные внутренние углы

  // Дирекционные углы (или румбы, если предпочитаете)
  final List<double> directionAngles; // Дирекционные углы сторон

  // Приращения координат
  final List<double> deltaX;          // Приращения по X (Север/Юг)
  final List<double> deltaY;          // Приращения по Y (Восток/Запад)

  // Суммы приращений и невязки по координатам
  final double sumDeltaX;
  final double sumDeltaY;
  final double linearMisclosureX;     // Невязка по X
  final double linearMisclosureY;     // Невязка по Y
  final double absoluteLinearMisclosure; // Абсолютная линейная невязка
  final double relativeLinearMisclosure; // Относительная линейная невязка (1:M)
  final bool isLinearMisclosureAcceptable;

  // Исправленные приращения
  final List<double> correctedDeltaX;
  final List<double> correctedDeltaY;

  // Координаты точек (если задана начальная точка)
  final List<PointCoordinates> calculatedCoordinates; // Список координат (X, Y)

  // Конструктор
  TraverseCalculationResult({
    required this.inputStations,
    required this.calculationDate,
    required this.sumMeasuredAngles,
    required this.theoreticalSumAngles,
    required this.angularMisclosure,
    required this.permissibleAngularMisclosure,
    required this.isAngularMisclosureAcceptable,
    required this.correctedAngles,
    required this.directionAngles,
    required this.deltaX,
    required this.deltaY,
    required this.sumDeltaX,
    required this.sumDeltaY,
    required this.linearMisclosureX,
    required this.linearMisclosureY,
    required this.absoluteLinearMisclosure,
    required this.relativeLinearMisclosure,
    required this.isLinearMisclosureAcceptable,
    required this.correctedDeltaX,
    required this.correctedDeltaY,
    required this.calculatedCoordinates,
  });

// Можно добавить factory конструктор для удобства создания из пустого состояния или ошибки
}

// Вспомогательный класс для координат
class PointCoordinates {
  final String stationName;
  final double x; // Север (+) / Юг (-)
  final double y; // Восток (+) / Запад (-)

  PointCoordinates({required this.stationName, required this.x, required this.y});

  @override
  String toString() {
    return 'Точка: $stationName, X: ${x.toStringAsFixed(3)}, Y: ${y.toStringAsFixed(3)}';
  }
}
