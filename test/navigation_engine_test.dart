import 'package:basira/models/safe_route.dart';
import 'package:basira/services/navigation_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

SafeRoute _straightRoute() {
  return const SafeRoute(
    id: 'test',
    name: 'مسار الاختبار',
    city: 'شبين الكوم',
    points: <LatLng>[
      LatLng(30.0000, 31.0000),
      LatLng(30.0005, 31.0000),
      LatLng(30.0010, 31.0000),
    ],
    landmarks: <String>['البداية', 'منتصف الطريق', 'النهاية'],
    safetyScore: 4,
  );
}

void main() {
  group('طول المسار', () {
    test('يحسب مجموع القطع', () {
      final SafeRoute r = _straightRoute();
      expect(r.lengthMeters, greaterThan(100));
      expect(r.lengthMeters, lessThan(130));
    });

    test('summaryAr يحتوي الاسم والزمن', () {
      final SafeRoute r = _straightRoute();
      expect(r.summaryAr, contains('مسار الاختبار'));
      expect(r.summaryAr, contains('دقيقة'));
    });
  });

  group('NavigationEngine', () {
    test('التحديث الأول يعطي إرشادًا وليس وصولًا', () {
      final NavigationEngine engine = NavigationEngine(route: _straightRoute());
      final NavUpdate u = engine.initial(const LatLng(30.0, 31.0));
      expect(u.phase, NavPhase.navigating);
      expect(u.instruction.isNotEmpty, isTrue);
      expect(u.remainingMeters, greaterThan(80));
    });

    test('الاقتراب من النهاية يعطي حالة وصول', () {
      final NavigationEngine engine = NavigationEngine(route: _straightRoute());
      engine.initial(const LatLng(30.0, 31.0));
      final NavUpdate u = engine.update(const LatLng(30.0010, 31.0000));
      expect(u.phase, NavPhase.arrived);
      expect(u.progress, 1);
      expect(u.instruction, contains('وصلت'));
    });

    test('الابتعاد عن المسار يعطي offRoute', () {
      final NavigationEngine engine = NavigationEngine(route: _straightRoute());
      engine.initial(const LatLng(30.0, 31.0));
      final NavUpdate u = engine.update(const LatLng(30.0005, 31.0008));
      expect(u.phase, NavPhase.offRoute);
      expect(u.instruction, contains('خارج المسار'));
    });

    test('التقدم يزيد كلما تقدمنا', () {
      final NavigationEngine engine = NavigationEngine(route: _straightRoute());
      final NavUpdate a = engine.initial(const LatLng(30.0, 31.0));
      final NavUpdate b = engine.update(const LatLng(30.0008, 31.0));
      expect(b.progress, greaterThan(a.progress));
      expect(b.remainingMeters, lessThan(a.remainingMeters));
    });

    test('shouldAnnounce يتغير مرة واحدة لكل خطوة/مسافة', () {
      final NavigationEngine engine = NavigationEngine(route: _straightRoute());
      final NavUpdate first = engine.initial(const LatLng(30.0, 31.0));
      expect(NavigationEngine.shouldAnnounce(first), isTrue);

      final NavUpdate same = engine.update(const LatLng(30.0, 31.0));
      expect(NavigationEngine.shouldAnnounce(same), isFalse);

      final NavUpdate far = engine.update(const LatLng(30.0009, 31.0));
      expect(NavigationEngine.shouldAnnounce(far), isTrue);
    });

    test('ETA منطقي (أقل من 5 دقائق لمسار 120 مترًا)', () {
      final NavigationEngine engine = NavigationEngine(route: _straightRoute());
      final NavUpdate u = engine.initial(const LatLng(30.0, 31.0));
      expect(u.etaMinutes, lessThanOrEqualTo(5));
      expect(u.etaMinutes, greaterThanOrEqualTo(1));
    });
  });

  group('RouteFactory', () {
    test('يبني مسارًا بين نقطتين', () {
      final SafeRoute r = SafeRouteFactory.between(
        from: const LatLng(30.0, 31.0),
        to: const LatLng(30.001, 31.0),
        name: 'اختبار',
      );
      expect(r.points.length, greaterThan(2));
      expect(r.points.first, const LatLng(30.0, 31.0));
      expect(r.points.last, const LatLng(30.001, 31.0));
    });

    test('يبني مسارًا عبر نقطة وسيطة', () {
      final SafeRoute r = SafeRouteFactory.between(
        from: const LatLng(30.0, 31.0),
        to: const LatLng(30.002, 31.0),
        via: const LatLng(30.001, 31.0005),
        name: 'عبر البوابة',
      );
      expect(r.points.length, 3);
      expect(r.points[1], const LatLng(30.001, 31.0005));
    });
  });
}
