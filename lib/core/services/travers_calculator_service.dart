import 'dart:math';
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart';

class TraverseCalculatorService {
  final double defaultPermissibleAngularMisclosurePerMinutePerStation = 1.0; // в минутах дуги на станцию
  final double defaultRelativeLinearMisclosureDenominator = 2000; // 1:M
  final PointCoordinates initialCoordinates = PointCoordinates(stationName: "Т1 (Нач.)", x: 1000.0, y: 1000.0);
  final double initialDirectionAngle = 45.0; // Начальный дирекционный угол в градусах (например, СВ)

  Future<TraverseCalculationResult> calculateClosedTraverse(
      List<TheodoliteStation> stations) async {
    if (stations.length < 3) {
      throw ArgumentError("Для замкнутого теодолитного хода необходимо минимум 3 станции.");
    }
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      if (station.horizontalAngle == null) {
        throw ArgumentError("Отсутствует горизонтальный угол для станции ${station.stationName.isNotEmpty ? station.stationName : '№${i + 1}'}");
      }
      if (station.distance == null) {
        throw ArgumentError("Отсутствует расстояние для стороны от станции ${station.stationName.isNotEmpty ? station.stationName : '№${i + 1}'}");
      }
    }

    double sumMeasuredAngles = _calculateSumMeasuredAngles(stations);
    int n = stations.length;
    double theoreticalSumAngles = (n - 2) * 180.0;
    double angularMisclosure = sumMeasuredAngles - theoreticalSumAngles;
    // Допустимая невязка в градусах (1 минута = 1/60 градуса)
    double permissibleAngularMisclosure = (defaultPermissibleAngularMisclosurePerMinutePerStation / 60.0) * sqrt(n);
    bool isAngularMisclosureAcceptable = angularMisclosure.abs() <= permissibleAngularMisclosure;

    List<double> correctedAngles = _correctAngles(stations, angularMisclosure, isAngularMisclosureAcceptable);
    List<double> directionAngles = _calculateDirectionAngles(correctedAngles, initialDirectionAngle, n);

    List<double> deltaX = [];
    List<double> deltaY = [];
    List<double> distances = stations.map((s) => s.distance!).toList();

    for (int i = 0; i < n; i++) {
      double alphaRad = _degreesToRadians(directionAngles[i]);
      deltaX.add(distances[i] * cos(alphaRad));
      deltaY.add(distances[i] * sin(alphaRad));
    }

    double sumDeltaX = deltaX.reduce((a, b) => a + b);
    double sumDeltaY = deltaY.reduce((a, b) => a + b);
    double linearMisclosureX = -sumDeltaX;
    double linearMisclosureY = -sumDeltaY;
    double absoluteLinearMisclosure = sqrt(pow(linearMisclosureX, 2) + pow(linearMisclosureY, 2));
    double perimeter = distances.reduce((a, b) => a + b);
    double relativeLinearMisclosure = perimeter > 0 && absoluteLinearMisclosure > 0 ? perimeter / absoluteLinearMisclosure : double.infinity;
    bool isLinearMisclosureAcceptable = relativeLinearMisclosure >= defaultRelativeLinearMisclosureDenominator || absoluteLinearMisclosure == 0;


    List<double> correctedDeltaX = _correctDeltas(deltaX, linearMisclosureX, distances, perimeter, isLinearMisclosureAcceptable && isAngularMisclosureAcceptable);
    List<double> correctedDeltaY = _correctDeltas(deltaY, linearMisclosureY, distances, perimeter, isLinearMisclosureAcceptable && isAngularMisclosureAcceptable);

    // Координаты считаем только если обе невязки в допуске
    List<PointCoordinates> calculatedCoordinates = (isAngularMisclosureAcceptable && isLinearMisclosureAcceptable)
        ? _calculateCoordinates(stations, correctedDeltaX, correctedDeltaY, initialCoordinates)
        : _generatePlaceholderCoordinates(stations, initialCoordinates);


    return TraverseCalculationResult(
      inputStations: stations,
      calculationDate: DateTime.now(),
      sumMeasuredAngles: sumMeasuredAngles,
      theoreticalSumAngles: theoreticalSumAngles,
      angularMisclosure: angularMisclosure,
      permissibleAngularMisclosure: permissibleAngularMisclosure,
      isAngularMisclosureAcceptable: isAngularMisclosureAcceptable,
      correctedAngles: correctedAngles,
      directionAngles: directionAngles,
      deltaX: deltaX,
      deltaY: deltaY,
      sumDeltaX: sumDeltaX,
      sumDeltaY: sumDeltaY,
      linearMisclosureX: linearMisclosureX,
      linearMisclosureY: linearMisclosureY,
      absoluteLinearMisclosure: absoluteLinearMisclosure,
      relativeLinearMisclosure: relativeLinearMisclosure,
      isLinearMisclosureAcceptable: isLinearMisclosureAcceptable,
      correctedDeltaX: correctedDeltaX,
      correctedDeltaY: correctedDeltaY,
      calculatedCoordinates: calculatedCoordinates,
    );
  }

  double _calculateSumMeasuredAngles(List<TheodoliteStation> stations) {
    return stations.fold(0.0, (sum, station) => sum + (station.horizontalAngle ?? 0.0));
  }

  List<double> _correctAngles(List<TheodoliteStation> stations, double misclosure, bool isAcceptable) {
    if (!isAcceptable) {
      return stations.map((s) => s.horizontalAngle ?? 0.0).toList();
    }
    double correctionPerAngle = -misclosure / stations.length;
    return stations.map((s) => (s.horizontalAngle ?? 0.0) + correctionPerAngle).toList();
  }

  List<double> _calculateDirectionAngles(List<double> correctedInnerAngles, double initialAlpha, int n) {
    List<double> alphas = List.filled(n, 0.0);
    if (n == 0) return alphas;

    alphas[0] = initialAlpha; // Дирекционный угол первой стороны

    // Предполагаем, что correctedInnerAngles - это ИЗМЕРЕННЫЕ (и исправленные) ВНУТРЕННИЕ углы полигона.
    // Обход по часовой стрелке (правые углы).
    // α_след = (α_пред + 180° - β_внутр_след) mod 360°
    // β_внутр_след - это угол на вершине, где заканчивается текущая сторона и начинается следующая.
    // correctedInnerAngles[0] - внутренний угол на СТАНЦИИ 0 (начало первой стороны)
    // correctedInnerAngles[1] - внутренний угол на СТАНЦИИ 1 (конец первой стороны, начало второй)

    for (int i = 0; i < n - 1; i++) {
      // correctedInnerAngles[i+1] - это угол на вершине (i+1)-й станции,
      // то есть угол между стороной (i -> i+1) и стороной (i+1 -> i+2)
      alphas[i+1] = (alphas[i] + 180.0 - correctedInnerAngles[(i+1) % n] + 360.0) % 360.0;
    }
    return alphas;
  }

  List<double> _correctDeltas(List<double> deltas, double misclosureComponent, List<double> lengths, double perimeter, bool isAcceptable) {
    if (!isAcceptable || perimeter == 0) {
      return List.from(deltas);
    }
    List<double> corrected = [];
    for (int i = 0; i < deltas.length; i++) {
      double correction = (-misclosureComponent * lengths[i].abs()) / perimeter; // Используем abs(длины)
      corrected.add(deltas[i] + correction);
    }
    return corrected;
  }

  List<PointCoordinates> _calculateCoordinates(
      List<TheodoliteStation> stations,
      List<double> correctedDeltaX,
      List<double> correctedDeltaY,
      PointCoordinates startPoint) {
    List<PointCoordinates> coordinates = [startPoint];
    double currentX = startPoint.x;
    double currentY = startPoint.y;

    for (int i = 0; i < correctedDeltaX.length; i++) {
      // Если это не последняя итераия (т.е. мы не считаем координаты для возврата в начальную точку по приращениям)
      if (i < stations.length -1) { // Мы получим N-1 новых точек + 1 начальная = N точек
        currentX += correctedDeltaX[i];
        currentY += correctedDeltaY[i];
        String stationName = stations[i + 1].stationName.isNotEmpty ? stations[i + 1].stationName : "Тчк. ${i + 2}";
        coordinates.add(PointCoordinates(stationName: stationName, x: currentX, y: currentY));
      } else if (i == stations.length - 1) {
        // Это приращение от последней точки к начальной. Можно проверить замыкание.
        // double closingX = currentX + correctedDeltaX[i];
        // double closingY = currentY + correctedDeltaY[i];
        // print("Проверка замыкания: X=${closingX.toStringAsFixed(3)}, Y=${closingY.toStringAsFixed(3)} (Должно быть ${startPoint.x}, ${startPoint.y})");
      }
    }
    // Для замкнутого хода, последняя вычисленная точка должна совпасть с начальной (после исправлений)
    // Наш список coordinates будет содержать N точек, если N - количество станций.
    // Первая - начальная, остальные N-1 - вычисленные.
    return coordinates;
  }

  // Метод для генерации плейсхолдеров координат, если расчет не удался или невязки недопустимы
  List<PointCoordinates> _generatePlaceholderCoordinates(List<TheodoliteStation> stations, PointCoordinates startPoint) {
    List<PointCoordinates> placeholderCoordinates = [startPoint];
    for(int i = 0; i < stations.length -1; i++) {
      String stationName = stations[i + 1].stationName.isNotEmpty ? stations[i + 1].stationName : "Тчк. ${i + 2}";
      placeholderCoordinates.add(PointCoordinates(stationName: stationName, x: 0.0, y: 0.0)); // или null, или NaN
    }
    return placeholderCoordinates;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }
}
