import 'dart:math';
import 'package:uuid/uuid.dart'; // Для генерации уникальных ID
// Убедитесь, что пути импорта ВЕРНЫ для вашей структуры проекта:
import 'package:traversemastery/models/theodolite_station.dart';
import 'package:traversemastery/models/traverse_calculation_result.dart';
// import 'package:traversemastery/models/point_coordinates.dart'; // Заменено на поля в TheodoliteStation

const _uuid = Uuid();

class TraverseCalculatorService {
  // Эти значения можно сделать параметрами метода или получать из настроек
  final double defaultPermissibleAngularMisclosurePerMinutePerStation = 1.0; // в минутах дуги на станцию
  final double defaultRelativeLinearMisclosureDenominator = 2000; // 1:M

  // Начальные данные теперь лучше передавать в метод расчета, если они могут меняться
  // final PointCoordinates initialCoordinates = PointCoordinates(stationName: "Т1 (Нач.)", x: 1000.0, y: 1000.0); // Заменено
  // final double initialDirectionAngle = 45.0; // Заменено

  Future<TraverseCalculationResult> calculateClosedTraverse({
    required List<TheodoliteStation> inputStations, // Используем копию, чтобы не изменять исходный список напрямую
    required TheodoliteStation initialStationData, // Начальные X, Y и имя для первой точки
    required double initialDirectionAngleDegrees, // Начальный дирекционный угол в градусах
    String? calculationName, // Опциональное имя для расчета
  }) async {
    if (inputStations.length < 3) {
      throw ArgumentError(
          "Для замкнутого теодолитного хода необходимо минимум 3 станции.");
    }

    List<TheodoliteStation> stations = inputStations
        .map((s) => s.copyWith(id: s.id.isEmpty ? _uuid.v4() : s.id)) // Гарантируем наличие ID
        .toList();


    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      if (station.horizontalAngle == null) {
        throw ArgumentError(
            "Отсутствует горизонтальный угол для станции ${station.stationName.isNotEmpty ? station.stationName : '№${i + 1}'}");
      }
      if (station.distance == null) {
        throw ArgumentError(
            "Отсутствует расстояние для стороны от станции ${station.stationName.isNotEmpty ? station.stationName : '№${i + 1}'}");
      }
    }

    int n = stations.length;

    // 1. Угловые невязки
    double sumMeasuredAngles =
    stations.fold(0.0, (sum, s) => sum + (s.horizontalAngle ?? 0.0));
    double theoreticalSumAngles = (n - 2) * 180.0;
    double angularMisclosure = sumMeasuredAngles - theoreticalSumAngles;
    double permissibleAngularMisclosure =
        (defaultPermissibleAngularMisclosurePerMinutePerStation / 60.0) *
            sqrt(n);
    bool isAngularMisclosureAcceptable =
        angularMisclosure.abs() <= permissibleAngularMisclosure;

    // 2. Исправление углов и запись в копии станций
    double angleCorrectionPerStation = isAngularMisclosureAcceptable
        ? -angularMisclosure / n
        : 0.0; // Не исправляем, если невязка недопустима

    List<TheodoliteStation> stationsWithCorrectedAngles = [];
    double sumCorrectedAngles = 0;
    for (var station in stations) {
      double correctedAngle = (station.horizontalAngle ?? 0.0) + angleCorrectionPerStation;
      stationsWithCorrectedAngles.add(station.copyWith(horizontalAngle: correctedAngle)); // Обновляем угол в копии
      sumCorrectedAngles += correctedAngle;
    }


    // 3. Расчет дирекционных углов и запись в копии станций
    List<TheodoliteStation> stationsWithDirectionAngles = List.from(stationsWithCorrectedAngles); // Создаем новую изменяемую копию
    if (n > 0) {
      stationsWithDirectionAngles[0] = stationsWithDirectionAngles[0].copyWith(directionAngle: initialDirectionAngleDegrees);
      for (int i = 0; i < n - 1; i++) {
        double prevAlpha = stationsWithDirectionAngles[i].directionAngle!;
        double currentBeta = stationsWithDirectionAngles[(i + 1) % n].horizontalAngle!; // Используем исправленный угол следующей станции
        double nextAlpha = (prevAlpha + 180.0 - currentBeta + 360.0) % 360.0;
        stationsWithDirectionAngles[i+1] = stationsWithDirectionAngles[i+1].copyWith(directionAngle: nextAlpha);
      }
      // Дирекционный угол для последней стороны (от последней к первой станции)
      // Нужен для расчета последнего приращения
      // Если это замкнутый ход, то этот угол должен быть alpha_n-1 + 180 - beta_0
      // Но для списка станций он для стороны stationsWithDirectionAngles[n-1]
      // то есть stationsWithDirectionAngles[n-1].directionAngle уже должен быть вычислен на предыдущем шаге
    }


    // 4. Расчет приращений координат (dX, dY) и запись в копии станций
    List<TheodoliteStation> stationsWithDeltas = List.from(stationsWithDirectionAngles);
    List<double> deltaXList = [];
    List<double> deltaYList = [];
    double sumDistances = 0;

    for (int i = 0; i < n; i++) {
      double alphaRad = _degreesToRadians(stationsWithDeltas[i].directionAngle!);
      double distance = stationsWithDeltas[i].distance!;
      double dX = distance * cos(alphaRad);
      double dY = distance * sin(alphaRad);
      deltaXList.add(dX);
      deltaYList.add(dY);
      stationsWithDeltas[i] = stationsWithDeltas[i].copyWith(deltaX: dX, deltaY: dY);
      sumDistances += distance;
    }

    // 5. Линейные невязки
    double sumDeltaXUncorrected = deltaXList.reduce((a, b) => a + b);
    double sumDeltaYUncorrected = deltaYList.reduce((a, b) => a + b);
    double linearMisclosureX = -sumDeltaXUncorrected; // fx
    double linearMisclosureY = -sumDeltaYUncorrected; // fy
    double absoluteLinearMisclosure = sqrt(pow(linearMisclosureX, 2) + pow(linearMisclosureY, 2));
    double relativeLinearMisclosure = sumDistances > 0 && absoluteLinearMisclosure > 0
        ? absoluteLinearMisclosure / sumDistances // f_abs / P  (для формата 1:M потом инвертируем)
        : 0.0; // или double.infinity, если абсолютная 0

    // Для формата 1:M, где M = P / f_abs
    double relativeLinearMisclosureDenominatorResult = sumDistances > 0 && absoluteLinearMisclosure > 0
        ? sumDistances / absoluteLinearMisclosure
        : double.infinity;


    bool isLinearMisclosureAcceptable =
        (relativeLinearMisclosureDenominatorResult >= defaultRelativeLinearMisclosureDenominator) || absoluteLinearMisclosure == 0;


    // 6. Исправление приращений и запись в копии станций
    List<TheodoliteStation> stationsWithCorrectedDeltas = List.from(stationsWithDeltas);
    List<double> correctedDeltaXList = [];
    List<double> correctedDeltaYList = [];

    // Исправляем только если обе невязки в допуске (или только угловая, если так принято)
    // В вашем коде было: isLinearMisclosureAcceptable && isAngularMisclosureAcceptable
    // Это правильный подход для окончательных координат.
    bool canCorrectCoordinates = isAngularMisclosureAcceptable && isLinearMisclosureAcceptable;

    for (int i = 0; i < n; i++) {
      double originalDx = stationsWithDeltas[i].deltaX!;
      double originalDy = stationsWithDeltas[i].deltaY!;
      double distance = stationsWithDeltas[i].distance!;
      double dxCorrection = 0;
      double dyCorrection = 0;

      if (canCorrectCoordinates && sumDistances > 0) {
        dxCorrection = (linearMisclosureX * distance.abs()) / sumDistances;
        dyCorrection = (linearMisclosureY * distance.abs()) / sumDistances;
      }

      double correctedDx = originalDx + dxCorrection;
      double correctedDy = originalDy + dyCorrection;

      correctedDeltaXList.add(correctedDx);
      correctedDeltaYList.add(correctedDy);
      stationsWithCorrectedDeltas[i] = stationsWithCorrectedDeltas[i].copyWith(deltaX: correctedDx, deltaY: correctedDy);
    }

    // 7. Расчет координат и запись в копии станций
    List<TheodoliteStation> finalStations = List.from(stationsWithCorrectedDeltas);
    if (n > 0) {
      // Начальная станция получает X, Y из initialStationData
      // Имя и ID у нее уже есть из inputStations (или сгенерирован)
      finalStations[0] = finalStations[0].copyWith(
        coordinateX: initialStationData.coordinateX,
        coordinateY: initialStationData.coordinateY,
        // stationName: initialStationData.stationName // Имя должно браться из inputStations
      );

      for (int i = 0; i < n - 1; i++) { // Расчет координат для n-1 следующих станций
        double prevX = finalStations[i].coordinateX!;
        double prevY = finalStations[i].coordinateY!;
        double currentCorrectedDx = finalStations[i].deltaX!; // Используем dX от i-й станции к (i+1)-й
        double currentCorrectedDy = finalStations[i].deltaY!;

        finalStations[i+1] = finalStations[i+1].copyWith(
          coordinateX: prevX + currentCorrectedDx,
          coordinateY: prevY + currentCorrectedDy,
        );
      }
      // Координаты последней точки (n-1) вычислены.
      // Приращения от последней точки к первой (finalStations[n-1].deltaX/Y)
      // должны замкнуть ход на finalStations[0].coordinateX/Y
      // Это можно использовать для проверки.
      // double finalCheckX = finalStations[n-1].coordinateX! + finalStations[n-1].deltaX!;
      // double finalCheckY = finalStations[n-1].coordinateY! + finalStations[n-1].deltaY!;
      // print("Проверка замыкания X: $finalCheckX (должно быть ${finalStations[0].coordinateX})");
      // print("Проверка замыкания Y: $finalCheckY (должно быть ${finalStations[0].coordinateY})");
    }


    // Создание и возврат TraverseCalculationResult
    return TraverseCalculationResult(
      calculationId: _uuid.v4(), // Генерируем ID для самого расчета
      calculationDate: DateTime.now(),
      calculationName: calculationName,
      stations: finalStations, // Список станций со всеми вычисленными данными
      initialAzimuth: initialDirectionAngleDegrees,
      startPointCoordinates: initialStationData, // Сохраняем начальные данные
      sumMeasuredAngles: sumMeasuredAngles,
      sumCorrectedAngles: sumCorrectedAngles, // Сумма уже исправленных углов
      sumTheoreticalAngles: theoreticalSumAngles,
      sumDistances: sumDistances,
      angularMisclosure: angularMisclosure,
      permissibleAngularMisclosure: permissibleAngularMisclosure,
      isAngularOk: isAngularMisclosureAcceptable,
      sumDeltaX: sumDeltaXUncorrected, // Сумма НЕИСПРАВЛЕННЫХ приращений для отчета
      sumDeltaY: sumDeltaYUncorrected, // Сумма НЕИСПРАВЛЕННЫХ приращений для отчета
      linearMisclosureAbsolute: absoluteLinearMisclosure,
      linearMisclosureRelative: relativeLinearMisclosureDenominatorResult, // Сохраняем знаменатель M (1:M)
      permissibleLinearMisclosureRelative: defaultRelativeLinearMisclosureDenominator.toDouble(), // Допустимый знаменатель M
      isLinearOk: isLinearMisclosureAcceptable,
    );
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

// Эти вспомогательные методы из вашего оригинального кода [1] больше не нужны в таком виде,
// так как логика встроена в основной метод и использует copyWith для обновления станций.
// _calculateSumMeasuredAngles, _correctAngles, _calculateDirectionAngles, _correctDeltas, _calculateCoordinates, _generatePlaceholderCoordinates
}

