import 'package:basira/models/app_settings.dart';
import 'package:basira/models/obstacle.dart';
import 'package:basira/models/sos_contact.dart';
import 'package:basira/models/university.dart';
import 'package:basira/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Obstacle', () {
    test('رحمة ذهاب وعودة عبر toMap/fromMap', () {
      final Obstacle o = Obstacle(
        id: 'o1',
        type: ObstacleType.stairs,
        description: 'سلالم بدون درابزين',
        lat: 30.5,
        lng: 31.0,
        reporterId: 'u1',
        createdAt: DateTime(2026, 10, 1, 10, 30),
        severity: 3,
      );
      final Obstacle back = Obstacle.fromMap(o.toMap(), 'o1');
      expect(back.type, ObstacleType.stairs);
      expect(back.lat, 30.5);
      expect(back.severity, 3);
      expect(back.status, ObstacleStatus.pending);
      expect(back.isActive, isTrue);
    });

    test('toSpeech يحتوي نوع العائق والمسافة', () {
      final Obstacle o = Obstacle(
        id: 'o2',
        type: ObstacleType.hole,
        description: '',
        lat: 0,
        lng: 0,
        reporterId: 'u',
        createdAt: DateTime.now(),
      );
      expect(o.toSpeech(distanceMeters: 15), contains('حفرة'));
      expect(o.toSpeech(distanceMeters: 15), contains('15'));
    });

    test('toFirestore يستخدم location كخريطة', () {
      final Obstacle o = Obstacle(
        id: 'o3',
        type: ObstacleType.construction,
        description: '',
        lat: 30.1,
        lng: 31.1,
        reporterId: 'u',
        createdAt: DateTime.now(),
      );
      final Map<String, dynamic> data = o.toFirestore();
      expect(data['location'], isA<Map<String, dynamic>>());
      expect((data['location'] as Map<String, dynamic>)['lat'], 30.1);
    });
  });

  group('SosContact', () {
    test('يحوّل الرقم المحلي إلى دولي', () {
      const SosContact c = SosContact(id: '1', name: 'أحمد', phone: '01012345678');
      expect(c.dialablePhone, '+201012345678');
    });

    test('يحافظ على الرقم الدولي', () {
      const SosContact c = SosContact(id: '1', name: 'أحمد', phone: '+201012345678');
      expect(c.dialablePhone, '+201012345678');
    });

    test('يحوّل 00 إلى +', () {
      const SosContact c = SosContact(id: '1', name: 'أحمد', phone: '00201012345678');
      expect(c.dialablePhone, '+201012345678');
    });

    test('initial يعيد أول حرف أو علامة استفهام', () {
      expect(const SosContact(id: '1', name: 'منى', phone: '1').initial, 'م');
      expect(const SosContact(id: '2', name: '   ', phone: '1').initial, '؟');
    });
  });

  group('AppSettings', () {
    test('القيم الافتراضية آمنة', () {
      const AppSettings s = AppSettings();
      expect(s.disclaimerAccepted, isFalse);
      expect(s.needsOnboarding, isTrue);
      expect(s.speechRate, greaterThan(0));
    });

    test('copyWith لا يفقد القيم', () {
      const AppSettings s = AppSettings(userName: 'سارة', haptics: false);
      final AppSettings s2 = s.copyWith(highContrast: true);
      expect(s2.userName, 'سارة');
      expect(s2.haptics, isFalse);
      expect(s2.highContrast, isTrue);
    });

    test('fromMap/toMap متماثلان', () {
      const AppSettings s = AppSettings(
        userName: 'علي',
        speechRate: 0.6,
        verbosity: GuidanceVerbosity.detailed,
        role: UserRole.volunteer,
      );
      final AppSettings back = AppSettings.fromMap(s.toMap());
      expect(back.userName, 'علي');
      expect(back.speechRate, 0.6);
      expect(back.verbosity, GuidanceVerbosity.detailed);
      expect(back.role, UserRole.volunteer);
    });

    test('يقصّ سرعة النطق خارج النطاق', () {
      final AppSettings s = AppSettings.fromMap(const <String, dynamic>{'speechRate': 5.0});
      expect(s.speechRate, lessThanOrEqualTo(1.0));
    });
  });

  group('UserRole', () {
    test('fromId يرجع blind للحالات غير المعروفة', () {
      expect(UserRole.fromId('xyz'), UserRole.blind);
      expect(UserRole.fromId('volunteer'), UserRole.volunteer);
    });

    test('canModerate للباقي', () {
      expect(UserRole.admin.canModerate, isTrue);
      expect(UserRole.blind.canModerate, isFalse);
    });
  });

  group('University', () {
    test('nearestBuilding يعيد الأقرب', () {
      final University u = University.fromMap(<String, dynamic>{
        'id': 'u',
        'name': 'جامعة اختبار',
        'city': 'شبين الكوم',
        'lat': 30.0,
        'lng': 31.0,
        'buildings': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'b1', 'name': 'بعيد', 'lat': 30.01, 'lng': 31.0},
          <String, dynamic>{'id': 'b2', 'name': 'قريب', 'lat': 30.0001, 'lng': 31.0},
        ],
      });
      expect(u.nearestBuilding(30.0, 31.0)?.id, 'b2');
    });

    test('mainGate يفضّل فئة gate', () {
      final University u = University.fromMap(<String, dynamic>{
        'id': 'u',
        'name': 'جامعة',
        'city': 'c',
        'lat': 30.0,
        'lng': 31.0,
        'buildings': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'b1', 'name': 'مبنى', 'lat': 30.0, 'lng': 31.0},
          <String, dynamic>{'id': 'g', 'name': 'بوابة', 'lat': 30.0, 'lng': 31.0, 'category': 'gate'},
        ],
      });
      expect(u.mainGate?.id, 'g');
    });
  });
}
