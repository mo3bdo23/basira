import 'dart:math' as math;

/// أدوات جغرافية خالصة (بلا اعتماد على أي حزمة) — قابلة للاختبار مباشرة.
class Geo {
  const Geo._();

  static const double earthRadiusMeters = 6371000.0;

  static double toRadians(double degrees) => degrees * math.pi / 180.0;

  static double toDegrees(double radians) => radians * 180.0 / math.pi;

  /// المسافة بالمتر بين نقطتين على سطح الأرض (معادلة هافرساين).
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    final double dLat = toRadians(lat2 - lat1);
    final double dLng = toRadians(lng2 - lng1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRadians(lat1)) *
            math.cos(toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// اتجاه البوصلة من نقطة إلى أخرى بالدرجات (0 = شمال، 90 = شرق).
  static double bearingDegrees(double lat1, double lng1, double lat2, double lng2) {
    final double lat1r = toRadians(lat1);
    final double lat2r = toRadians(lat2);
    final double dLng = toRadians(lng2 - lng1);
    final double y = math.sin(dLng) * math.cos(lat2r);
    final double x = math.cos(lat1r) * math.sin(lat2r) -
        math.sin(lat1r) * math.cos(lat2r) * math.cos(dLng);
    return (toDegrees(math.atan2(y, x)) + 360.0) % 360.0;
  }

  /// الفرق الزاوي الأقصر بين اتجاهين (بين -180 و +180).
  static double angleDifference(double a, double b) {
    double diff = (a - b + 540.0) % 360.0 - 180.0;
    return diff;
  }

  /// الإسقاط العمودي لنقطة على قطعة مستقيمة (بصيغة إسقاط مسطح تقريبي).
  /// يعيد نسبة الموضع t بين 0 و 1 على القطعة.
  static double projectionFactor(
      double pLat, double pLng, double aLat, double aLng, double bLat, double bLng) {
    final double dx = bLng - aLng;
    final double dy = bLat - aLat;
    final double lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return 0;
    final double t = ((pLng - aLng) * dx + (pLat - aLat) * dy) / lenSq;
    return t.clamp(0.0, 1.0).toDouble();
  }

  /// المسافة من نقطة إلى قطعة مستقيمة بالأمتار.
  static double distanceToSegmentMeters(double pLat, double pLng, double aLat, double aLng,
      double bLat, double bLng) {
    final double t = projectionFactor(pLat, pLng, aLat, aLng, bLat, bLng);
    final double projLat = aLat + (bLat - aLat) * t;
    final double projLng = aLng + (bLng - aLng) * t;
    return distanceMeters(pLat, pLng, projLat, projLng);
  }

  /// اسم الاتجاه بالعربية.
  static String compassLabel(double bearing) {
    final double b = (bearing % 360 + 360) % 360;
    if (b < 22.5 || b >= 337.5) return 'الشمال';
    if (b < 67.5) return 'الشمال الشرقي';
    if (b < 112.5) return 'الشرق';
    if (b < 157.5) return 'الجنوب الشرقي';
    if (b < 202.5) return 'الجنوب';
    if (b < 247.5) return 'الجنوب الغربي';
    if (b < 292.5) return 'الغرب';
    return 'الشمال الغربي';
  }

  /// "انعطف يمينًا / يسارًا / استمر للأمام" بحسب فرق الاتجاه.
  static String turnLabel(double deltaDegrees) {
    final double d = angleDifference(deltaDegrees, 0);
    final double abs = d.abs();
    if (abs < 20) return 'استمر للأمام';
    if (abs > 150) return 'استدر للخلف';
    if (d > 0) {
      return abs > 100 ? 'انعطف بحدة يمينًا' : 'انعطف يمينًا';
    }
    return abs > 100 ? 'انعطف بحدة يسارًا' : 'انعطف يسارًا';
  }

  /// صياغة المسافة بشكل منطوق ومفهوم: "ثلاثة وأربعين مترًا" تُقرَّب لأقرب 5.
  static String spokenDistance(double meters) {
    final double m = meters < 10 ? meters : (meters / 5).round() * 5.0;
    if (m < 1000) {
      return '${m.round()} مترًا';
    }
    final double km = m / 1000.0;
    return '${km.toStringAsFixed(1)} كيلومتر';
  }

  static String shortDistance(double meters) =>
      meters < 1000 ? '${meters.round()} م' : '${(meters / 1000).toStringAsFixed(1)} كم';

  /// تقدير زمن المشي بالدقائق (سرعة 1.2 م/ث).
  static double walkingMinutes(double meters, {double speedMetersPerSecond = 1.2}) {
    if (speedMetersPerSecond <= 0) return 0;
    return meters / speedMetersPerSecond / 60.0;
  }

  static double normalizeHeading(double degrees) => (degrees % 360 + 360) % 360;
}
