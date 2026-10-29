import 'package:basira/core/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Geo.distanceMeters', () {
    test('صفر لنفس النقطة', () {
      expect(Geo.distanceMeters(30.5566, 31.0091, 30.5566, 31.0091), 0);
    });

    test('نقطة معروفة (~ ميدان شبين الكوم → بوابة الجامعة)', () {
      final double d = Geo.distanceMeters(30.5566, 31.0091, 30.5462, 31.0105);
      // المسافة الحقيقية ~ 1.17 كم؛ نتحمل 2% خطأ.
      expect(d, greaterThan(1100));
      expect(d, lessThan(1250));
    });

    test('خط طول واحد عند خط الاستواء ≈ 111 كم', () {
      final double d = Geo.distanceMeters(0, 0, 0, 1);
      expect(d, closeTo(111195, 200));
    });
  });

  group('Geo.bearingDegrees', () {
    test('الشمال = 0 تقريبًا', () {
      final double b = Geo.bearingDegrees(30.0, 31.0, 30.001, 31.0);
      expect(b < 1 || b > 359, isTrue);
    });

    test('الشرق = 90 تقريبًا', () {
      final double b = Geo.bearingDegrees(30.0, 31.0, 30.0, 31.001);
      expect(b, closeTo(90, 1));
    });

    test('الجنوب = 180 تقريبًا', () {
      final double b = Geo.bearingDegrees(30.001, 31.0, 30.0, 31.0);
      expect(b, closeTo(180, 1));
    });
  });

  test('Geo.angleDifference يعيد الفرق الأقصر', () {
    expect(Geo.angleDifference(350, 10), closeTo(-20, 0.001));
    expect(Geo.angleDifference(10, 350), closeTo(20, 0.001));
    expect(Geo.angleDifference(90, 90), 0);
  });

  group('Geo.turnLabel', () {
    test('أمام', () => expect(Geo.turnLabel(5), 'استمر للأمام'));
    test('يمين', () => expect(Geo.turnLabel(45), 'انعطف يمينًا'));
    test('يسار', () => expect(Geo.turnLabel(-45), 'انعطف يسارًا'));
    test('استدارة', () => expect(Geo.turnLabel(175), 'استدر للخلف'));
  });

  group('Geo.spokenDistance', () {
    test('أقل من 1000 متر', () {
      expect(Geo.spokenDistance(43), contains('مترًا'));
    });
    test('أكثر من كيلومتر', () {
      expect(Geo.spokenDistance(1250), contains('كيلومتر'));
    });
    test('تقريب لأقرب 5 أمتار', () {
      expect(Geo.spokenDistance(43), '45 مترًا');
    });
  });

  test('Geo.walkingMinutes يحسب الزمن بسرعة 1.2 م/ث', () {
    expect(Geo.walkingMinutes(72), closeTo(1, 0.01));
  });

  group('Geo.distanceToSegmentMeters', () {
    test('نقطة على القطعة = صفر', () {
      final double d = Geo.distanceToSegmentMeters(30.0005, 31.0, 30.0, 31.0, 30.001, 31.0);
      expect(d, lessThan(0.5));
    });

    test('نقطة بعيدة عن القطعة', () {
      final double d = Geo.distanceToSegmentMeters(30.0005, 31.001, 30.0, 31.0, 30.001, 31.0);
      expect(d, greaterThan(80));
      expect(d, lessThan(110));
    });
  });

  test('Geo.normalizeHeading', () {
    expect(Geo.normalizeHeading(-10), closeTo(350, 0.001));
    expect(Geo.normalizeHeading(370), closeTo(10, 0.001));
  });
}
