import 'package:latlong2/latlong.dart';

import '../core/app_config.dart';
import '../core/geo.dart';
import '../models/safe_route.dart';

enum NavPhase { idle, navigating, arrived, offRoute }

/// نتيجة تحديث واحدة من محرك الإرشاد.
class NavUpdate {
  const NavUpdate({
    required this.phase,
    required this.stepIndex,
    required this.distanceToNext,
    required this.remainingMeters,
    required this.progress,
    required this.instruction,
    required this.bearingToNext,
    required this.offRouteDistance,
    required this.announcementKey,
  });

  final NavPhase phase;

  /// فهرس النقطة القادمة في المسار.
  final int stepIndex;
  final double distanceToNext;
  final double remainingMeters;

  /// من 0 إلى 1.
  final double progress;
  final String instruction;
  final double bearingToNext;

  /// المسافة عن أقرب نقطة على المسار.
  final double offRouteDistance;

  /// مفتاح يتغير عند الحاجة لنطق تنبيه جديد (خطوة أو مسافة).
  final String announcementKey;

  int get etaMinutes => (remainingMeters / AppConfig.walkingSpeedMps / 60).ceil();

  bool get isArrived => phase == NavPhase.arrived;
}

/// محرك إرشاد نقي: يأخذ موقعًا ويعيد تعليمات — بلا أي اعتماد على GPS أو صوت،
/// مما يجعله قابلًا للاختبار بالكامل.
class NavigationEngine {
  NavigationEngine({required this.route, this.verbosity = 'normal'});

  final SafeRoute route;
  final String verbosity;

  int _lastStepIndex = 0;
  int _lastBand = -1;
  bool _arrived = false;
  String _lastKey = '';

  NavUpdate initial(LatLng from) {
    _lastStepIndex = 0;
    _lastBand = -1;
    _arrived = false;
    _lastKey = '';
    return update(from, forceNavigating: true);
  }

  NavUpdate update(LatLng position, {bool forceNavigating = false}) {
    final List<LatLng> pts = route.points;
    if (pts.length < 2) {
      return NavUpdate(
        phase: NavPhase.arrived,
        stepIndex: 0,
        distanceToNext: 0,
        remainingMeters: 0,
        progress: 1,
        instruction: 'وصلت إلى ${route.name}',
        bearingToNext: 0,
        offRouteDistance: 0,
        announcementKey: 'arrived',
      );
    }

    final double total = route.lengthMeters;

    if (_arrived) {
      return NavUpdate(
        phase: NavPhase.arrived,
        stepIndex: pts.length - 1,
        distanceToNext: 0,
        remainingMeters: 0,
        progress: 1,
        instruction: 'وصلت إلى ${route.name}',
        bearingToNext: 0,
        offRouteDistance: 0,
        announcementKey: 'arrived',
      );
    }

    // 1) إيجاد أقرب قطعة على المسار.
    int bestSegment = 0;
    double bestDistance = double.infinity;
    double bestT = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final double t = Geo.projectionFactor(
        position.latitude,
        position.longitude,
        pts[i].latitude,
        pts[i].longitude,
        pts[i + 1].latitude,
        pts[i + 1].longitude,
      );
      final double projLat = pts[i].latitude + (pts[i + 1].latitude - pts[i].latitude) * t;
      final double projLng = pts[i].longitude + (pts[i + 1].longitude - pts[i].longitude) * t;
      final double d = Geo.distanceMeters(position.latitude, position.longitude, projLat, projLng);
      if (d < bestDistance) {
        bestDistance = d;
        bestSegment = i;
        bestT = t;
      }
    }

    // 2) المسافة المتبقية على المسار من موضع الإسقاط.
    double remaining = 0;
    final double segLen = Geo.distanceMeters(
      pts[bestSegment].latitude,
      pts[bestSegment].longitude,
      pts[bestSegment + 1].latitude,
      pts[bestSegment + 1].longitude,
    );
    remaining += (1 - bestT) * segLen;
    for (int i = bestSegment + 1; i < pts.length - 1; i++) {
      remaining += Geo.distanceMeters(
        pts[i].latitude,
        pts[i].longitude,
        pts[i + 1].latitude,
        pts[i + 1].longitude,
      );
    }

    final double progress = total <= 0 ? 1 : (1 - remaining / total).clamp(0.0, 1.0).toDouble();

    // 3) الوصول: قريب من نهاية المسار.
    final double distanceToEnd = Geo.distanceMeters(
      position.latitude,
      position.longitude,
      pts.last.latitude,
      pts.last.longitude,
    );
    if (distanceToEnd <= AppConfig.arrivalRadiusMeters || (remaining <= 4 && bestSegment >= pts.length - 2)) {
      _arrived = true;
      return NavUpdate(
        phase: NavPhase.arrived,
        stepIndex: pts.length - 1,
        distanceToNext: 0,
        remainingMeters: 0,
        progress: 1,
        instruction: 'وصلت إلى ${route.name}. أنت الآن عند الوجهة.',
        bearingToNext: 0,
        offRouteDistance: 0,
        announcementKey: 'arrived',
      );
    }

    final bool offRoute = bestDistance > AppConfig.offRouteThresholdMeters;
    final int nextIndex = (bestSegment + 1).clamp(0, pts.length - 1);
    final double distanceToNext = Geo.distanceMeters(
      position.latitude,
      position.longitude,
      pts[nextIndex].latitude,
      pts[nextIndex].longitude,
    );

    final double bearingToNext = Geo.bearingDegrees(
      position.latitude,
      position.longitude,
      pts[nextIndex].latitude,
      pts[nextIndex].longitude,
    );

    // 4) صياغة الإرشاد.
    final bool isFinal = nextIndex == pts.length - 1;
    String instruction;

    if (offRoute && !forceNavigating) {
      instruction = 'أنت خارج المسار بـ ${Geo.spokenDistance(bestDistance)}. '
          'اتجه ${Geo.compassLabel(Geo.bearingDegrees(position.latitude, position.longitude, pts[bestSegment].latitude, pts[bestSegment].longitude))} للعودة إلى المسار.';
    } else if (isFinal) {
      instruction = 'تابع ${Geo.spokenDistance(distanceToNext)} للوصول إلى ${route.name}.';
    } else {
      final double bearingIn = Geo.bearingDegrees(
        pts[bestSegment].latitude,
        pts[bestSegment].longitude,
        pts[bestSegment + 1].latitude,
        pts[bestSegment + 1].longitude,
      );
      final double bearingOut = Geo.bearingDegrees(
        pts[bestSegment + 1].latitude,
        pts[bestSegment + 1].longitude,
        pts[bestSegment + 2].latitude,
        pts[bestSegment + 2].longitude,
      );
      final String turn = Geo.turnLabel(Geo.angleDifference(bearingOut, bearingIn));
      final String landmark = nextIndex < route.landmarks.length && route.landmarks[nextIndex].isNotEmpty
          ? ' عند ${route.landmarks[nextIndex]}'
          : '';
      final String distanceText = Geo.spokenDistance(distanceToNext);
      switch (verbosity) {
        case 'brief':
          instruction = '$turn بعد $distanceText';
        case 'detailed':
          instruction = '$turn بعد $distanceText$landmark. '
              'اتجاهك الآن ${Geo.compassLabel(Geo.normalizeHeading(bearingToNext))}، '
              'المتبقي ${Geo.spokenDistance(remaining)} حوالي ${(remaining / AppConfig.walkingSpeedMps / 60).ceil()} دقيقة.';
        default:
          instruction = '$turn بعد $distanceText$landmark';
      }
    }

    // 5) مفتاح التنبيه: يتغير مع الخطوة أو مع عبور مستوى مسافة جديد.
    int band = 0;
    for (int i = 0; i < AppConfig.announceBands.length; i++) {
      if (distanceToNext <= AppConfig.announceBands[i]) band = i + 1;
    }
    if (offRoute) band = 50;
    final String key = '$nextIndex:$band:${offRoute ? 'off' : 'on'}';
    final bool changed = key != _lastKey;
    _lastKey = key;
    _lastStepIndex = nextIndex;
    _lastBand = band;

    final NavPhase phase = offRoute && !forceNavigating ? NavPhase.offRoute : NavPhase.navigating;

    return NavUpdate(
      phase: phase,
      stepIndex: nextIndex,
      distanceToNext: distanceToNext,
      remainingMeters: remaining,
      progress: progress,
      instruction: instruction,
      bearingToNext: bearingToNext,
      offRouteDistance: bestDistance,
      announcementKey: changed ? key : '$_lastStepIndex:$band:${offRoute ? 'off' : 'on'}:dup',
    );
  }

  /// هل يحتاج هذا التحديث إلى نطق؟ (يعتمد على تغيّر المفتاح دون لاحقة التكرار)
  static bool shouldAnnounce(NavUpdate update) => !update.announcementKey.endsWith(':dup');
}

/// بناء مسار مرن بين نقطتين (مثل: الطالب → بوابة الجامعة → المبنى).
class RouteFactory {
  const RouteFactory._();

  static SafeRoute between({
    required LatLng from,
    required LatLng to,
    required String name,
    LatLng? via,
    String city = '',
    int safetyScore = 4,
  }) {
    final List<LatLng> pts = <LatLng>[from];
    if (via != null) pts.add(via);
    // نقاط وسيطة لتمكين حساب الاتجاهات على مسار مستقيم.
    if (via == null) {
      const int steps = 5;
      for (int i = 1; i < steps; i++) {
        final double t = i / steps;
        pts.add(LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ));
      }
    }
    pts.add(to);
    return SafeRoute(
      id: 'generated_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      city: city,
      points: pts,
      safetyScore: safetyScore,
      description: 'مسار إرشادي مُولَّد',
    );
  }
}
