// lib/models/theodolite_station.dart
import 'package:flutter/foundation.dart';

class TheodoliteStation {
  final String id;
  final String stationName;
  final double? horizontalAngle;
  final double? distance;
  final double? directionAngle;
  final double? deltaX;
  final double? deltaY;
  final double? coordinateX;
  final double? coordinateY;

  TheodoliteStation({
    required this.id,
    required this.stationName,
    this.horizontalAngle,
    this.distance,
    this.directionAngle,
    this.deltaX,
    this.deltaY,
    this.coordinateX,
    this.coordinateY,
  });

  // <--- НАЧАЛО ВАЖНОЙ ЧАСТИ --->
  // Сериализация объекта TheodoliteStation в JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationName': stationName,
      'horizontalAngle': horizontalAngle,
      'distance': distance,
      'directionAngle': directionAngle,
      'deltaX': deltaX,
      'deltaY': deltaY,
      'coordinateX': coordinateX,
      'coordinateY': coordinateY,
    };
  }

  // Десериализация (создание объекта TheodoliteStation из JSON Map)
  factory TheodoliteStation.fromJson(Map<String, dynamic> json) {
    return TheodoliteStation(
      id: json['id'] as String,
      stationName: json['stationName'] as String,
      horizontalAngle: json['horizontalAngle'] as double?,
      distance: json['distance'] as double?,
      directionAngle: json['directionAngle'] as double?,
      deltaX: json['deltaX'] as double?,
      deltaY: json['deltaY'] as double?,
      coordinateX: json['coordinateX'] as double?,
      coordinateY: json['coordinateY'] as double?,
    );
  }
  // <--- КОНЕЦ ВАЖНОЙ ЧАСТИ --->

  TheodoliteStation copyWith({ // Оставим copyWith, он полезен
    String? id,
    String? stationName,
    double? horizontalAngle,
    double? distance,
    double? directionAngle,
    double? deltaX,
    double? deltaY,
    double? coordinateX,
    double? coordinateY,
  }) {
    return TheodoliteStation(
      id: id ?? this.id,
      stationName: stationName ?? this.stationName,
      horizontalAngle: horizontalAngle ?? this.horizontalAngle,
      distance: distance ?? this.distance,
      directionAngle: directionAngle ?? this.directionAngle,
      deltaX: deltaX ?? this.deltaX,
      deltaY: deltaY ?? this.deltaY,
      coordinateX: coordinateX ?? this.coordinateX,
      coordinateY: coordinateY ?? this.coordinateY,
    );
  }

  @override
  String toString() {
    return 'TheodoliteStation(id: $id, name: $stationName, angle: $horizontalAngle, dist: $distance, dirAngle: $directionAngle, dX: $deltaX, dY: $deltaY, X: $coordinateX, Y: $coordinateY)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TheodoliteStation &&
        other.id == id &&
        other.stationName == stationName &&
        other.horizontalAngle == horizontalAngle &&
        other.distance == distance &&
        other.directionAngle == directionAngle &&
        other.deltaX == deltaX &&
        other.deltaY == deltaY &&
        other.coordinateX == coordinateX &&
        other.coordinateY == coordinateY;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    stationName.hashCode ^
    horizontalAngle.hashCode ^
    distance.hashCode ^
    directionAngle.hashCode ^
    deltaX.hashCode ^
    deltaY.hashCode ^
    coordinateX.hashCode ^
    coordinateY.hashCode;
  }
}
