// Модель для хранения данных одной станции теодолитного хода
class TheodoliteStation {
  final String id; // Уникальный идентификатор для управления списком
  String stationName;    // Название станции (например, Т1, Т2, ПП1)
  double? horizontalAngle; // Горизонтальный угол (градусы, минуты, секунды можно объединить или разделить)
  double? distance;        // Расстояние до следующей точки (метры)
  // Можно добавить и другие поля, если необходимо:
  // double? verticalAngle;
  // String? notes;

  TheodoliteStation({
    required this.id,
    this.stationName = '',
    this.horizontalAngle,
    this.distance,
  });
}
