// lib/utils/angle_utils.dart
class AngleDMS {
  int degrees;
  int minutes;
  double seconds;

  AngleDMS({this.degrees = 0, this.minutes = 0, this.seconds = 0.0});

  factory AngleDMS.fromDecimalDegrees(double? decimalDegrees) {
    if (decimalDegrees == null || decimalDegrees.isNaN || decimalDegrees.isInfinite) {
      return AngleDMS();
    }
    double absDecimal = decimalDegrees.abs();
    int d = absDecimal.floor();
    double remainingMinutes = (absDecimal - d) * 60.0;
    int m = remainingMinutes.floor();
    double s = (remainingMinutes - m) * 60.0;

    s = (s * 100).round() / 100.0;
    if (s >= 60.0) {
      s -= 60.0;
      m += 1;
    }
    if (m >= 60) {
      m -= 60;
      d += 1;
    }

    return AngleDMS(
      degrees: decimalDegrees < 0 ? -d : d,
      minutes: m,
      seconds: s,
    );
  }

  double toDecimalDegrees() {
    double decimal = degrees.abs().toDouble() + (minutes.abs() / 60.0) + (seconds.abs() / 3600.0);
    return degrees < 0 ? -decimal : decimal;
  }

  @override
  String toString() {
    String secStr = seconds.toStringAsFixed(2);
    // Убираем ".00" если секунды целые, но оставляем один знак после запятой, если он есть (например "12.5")
    if (seconds == seconds.truncateToDouble() && (seconds * 10) % 10 == 0) { // Проверяем, что нет дробной части или она .0
      secStr = seconds.toInt().toString();
    } else if ((seconds * 100) % 10 == 0) { // Если заканчивается на .X0, показываем как .X
      secStr = seconds.toStringAsFixed(1);
    }
    return "${degrees}° ${minutes}' ${secStr}\"";
  }
}
