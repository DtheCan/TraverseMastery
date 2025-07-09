// lib/models/full_traverse_input.dart
import 'package:traversemastery/models/theodolite_station.dart';

class FullTraverseInput {
  final String calculationName;
  final double initialX;
  final double initialY;
  final double initialAzimuth;
  final List<TheodoliteStation> stations; // Только измеренные данные (без нач. X,Y)

  FullTraverseInput({
    required this.calculationName,
    required this.initialX,
    required this.initialY,
    required this.initialAzimuth,
    required this.stations,
  });
}