import 'package:flutter/foundation.dart';
import 'package:traversemastery/models/theodolite_station.dart'; // Убедитесь, что путь правильный

class TraverseCalculationResult {
  final String calculationId; // Уникальный ID для этого расчета, можно использовать UUID
  final DateTime calculationDate; // Дата и время выполнения расчета
  final String? calculationName; // Опциональное имя расчета (например, из имени файла)

  final List<TheodoliteStation> stations; // Список станций с исходными и/или вычисленными данными

  // Исходные данные для справки (если они не входят в каждую станцию)
  final double? initialAzimuth; // Исходный дирекционный угол (если использовался)
  final TheodoliteStation? startPointCoordinates; // Координаты начальной точки (если это не первая станция в списке)

  // Суммы и средние значения
  final double sumMeasuredAngles;         // Сумма измеренных (или левых по ходу) горизонтальных углов
  final double sumCorrectedAngles;        // Сумма исправленных горизонтальных углов
  final double sumTheoreticalAngles;      // Теоретическая сумма углов для данного типа хода
  final double sumDistances;              // Сумма длин сторон

  // Невязки
  final double angularMisclosure;         // Угловая невязка (фактическая - теоретическая)
  final double permissibleAngularMisclosure; // Допустимая угловая невязка
  final bool isAngularOk;                 // Прошла ли угловая невязка проверку допуска

  final double sumDeltaX;                 // Сумма приращений dX (алгебраическая)
  final double sumDeltaY;                 // Сумма приращений dY (алгебраическая)
  final double linearMisclosureAbsolute;  // Абсолютная линейная невязка (f_abs)
  final double linearMisclosureRelative;  // Относительная линейная невязка (например, 1/N)
  final double permissibleLinearMisclosureRelative; // Допустимая относительная линейная невязка
  final bool isLinearOk;                  // Прошла ли линейная невязка проверку допуска

  // Возможно, другие поля, специфичные для вашего расчета
  // final Map<String, dynamic>? additionalData; // Для любых других данных

  TraverseCalculationResult({
    required this.calculationId,
    required this.calculationDate,
    this.calculationName,
    required this.stations,
    this.initialAzimuth,
    this.startPointCoordinates,
    required this.sumMeasuredAngles,
    required this.sumCorrectedAngles,
    required this.sumTheoreticalAngles,
    required this.sumDistances,
    required this.angularMisclosure,
    required this.permissibleAngularMisclosure,
    required this.isAngularOk,
    required this.sumDeltaX,
    required this.sumDeltaY,
    required this.linearMisclosureAbsolute,
    required this.linearMisclosureRelative,
    required this.permissibleLinearMisclosureRelative,
    required this.isLinearOk,
    // this.additionalData,
  });

  // Сериализация в JSON
  Map<String, dynamic> toJson() {
    return {
      'calculationId': calculationId,
      'calculationDate': calculationDate.toIso8601String(), // Стандартный формат для даты
      'calculationName': calculationName,
      'stations': stations.map((s) => s.toJson()).toList(), // Сериализуем каждую станцию
      'initialAzimuth': initialAzimuth,
      'startPointCoordinates': startPointCoordinates?.toJson(), // Сериализуем, если не null
      'sumMeasuredAngles': sumMeasuredAngles,
      'sumCorrectedAngles': sumCorrectedAngles,
      'sumTheoreticalAngles': sumTheoreticalAngles,
      'sumDistances': sumDistances,
      'angularMisclosure': angularMisclosure,
      'permissibleAngularMisclosure': permissibleAngularMisclosure,
      'isAngularOk': isAngularOk,
      'sumDeltaX': sumDeltaX,
      'sumDeltaY': sumDeltaY,
      'linearMisclosureAbsolute': linearMisclosureAbsolute,
      'linearMisclosureRelative': linearMisclosureRelative,
      'permissibleLinearMisclosureRelative': permissibleLinearMisclosureRelative,
      'isLinearOk': isLinearOk,
      // 'additionalData': additionalData,
    };
  }

  // Десериализация из JSON
  factory TraverseCalculationResult.fromJson(Map<String, dynamic> json) {
    return TraverseCalculationResult(
      calculationId: json['calculationId'] as String,
      calculationDate: DateTime.parse(json['calculationDate'] as String),
      calculationName: json['calculationName'] as String?,
      stations: (json['stations'] as List<dynamic>)
          .map((sJson) => TheodoliteStation.fromJson(sJson as Map<String, dynamic>))
          .toList(),
      initialAzimuth: json['initialAzimuth'] as double?,
      startPointCoordinates: json['startPointCoordinates'] != null
          ? TheodoliteStation.fromJson(json['startPointCoordinates'] as Map<String, dynamic>)
          : null,
      sumMeasuredAngles: json['sumMeasuredAngles'] as double,
      sumCorrectedAngles: json['sumCorrectedAngles'] as double,
      sumTheoreticalAngles: json['sumTheoreticalAngles'] as double,
      sumDistances: json['sumDistances'] as double,
      angularMisclosure: json['angularMisclosure'] as double,
      permissibleAngularMisclosure: json['permissibleAngularMisclosure'] as double,
      isAngularOk: json['isAngularOk'] as bool,
      sumDeltaX: json['sumDeltaX'] as double,
      sumDeltaY: json['sumDeltaY'] as double,
      linearMisclosureAbsolute: json['linearMisclosureAbsolute'] as double,
      linearMisclosureRelative: json['linearMisclosureRelative'] as double,
      permissibleLinearMisclosureRelative: json['permissibleLinearMisclosureRelative'] as double,
      isLinearOk: json['isLinearOk'] as bool,
      // additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  // Для удобства отладки
  @override
  String toString() {
    return 'TraverseCalculationResult(id: $calculationId, name: $calculationName, stations: ${stations.length}, angularOk: $isAngularOk, linearOk: $isLinearOk)';
  }
}

