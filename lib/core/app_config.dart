/// ثوابت التطبيق العامة.
class AppConfig {
  const AppConfig._();

  static const String appName = 'بصيرة';
  static const String appNameEn = 'Basira';
  static const String tagline = 'طريقك الآمن.. بصوتك';
  static const String version = '1.0.0';
  static const String contactEmail = 'basira.team@example.com';

  /// إحداثيات افتراضية: شبين الكوم — المنوفية (حيث مدرسة النور للمكفوفين).
  static const double defaultLat = 30.5566;
  static const double defaultLng = 31.0091;
  static const double defaultZoom = 15.5;

  /// سرعة المشي الافتراضية لحساب الزمن المتبقي.
  static const double walkingSpeedMps = 1.2;

  /// حدود التنبيهات.
  static const double arrivalRadiusMeters = 8.0;
  static const double offRouteThresholdMeters = 25.0;
  static const double signalAlertRadiusMeters = 60.0;
  static const double obstacleAlertRadiusMeters = 30.0;

  /// مستويات التنبيه بالمسافة (تُنطق عند عبور كل مستوى).
  static const List<double> announceBands = [150, 80, 40, 20, 10];

  static const Duration sosCountdown = Duration(seconds: 5);
  static const Duration splashDuration = Duration(milliseconds: 2200);

  /// حدود الوصول (نص التشغيل لا يُفلت من الـ Semantics tree).
  static const double minTouchTargetDp = 56;
  static const double largeTouchTargetDp = 88;
}
