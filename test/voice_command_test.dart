import 'package:basira/services/voice_command_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('التطبيع', () {
    test('يزيل التشكيل والتطويل', () {
      expect(VoiceCommandRouter.normalize('اِبْدَأِ التَّنَقُّل'), 'ابدا التنقل'.replaceAll(' ', ' '));
    });

    test('يوحّد الألف', () {
      expect(VoiceCommandRouter.normalize('أين أنا'), 'اين انا');
    });

    test('يوحّد التاء المربوطة والياء', () {
      expect(VoiceCommandRouter.normalize('الإعدادات'), 'الاعدادات');
      expect(VoiceCommandRouter.normalize('مستشفى'), 'مستشفي');
    });

    test('يزيل الترقيم', () {
      expect(VoiceCommandRouter.normalize('ابدأ التنقل؟!'), 'ابدا التنقل');
    });
  });

  group('تحليل النوايا', () {
    test('ابدأ التنقل', () {
      final VoiceCommand c = VoiceCommandRouter.parse('ابدأ التنقل');
      expect(c.intent, VoiceIntent.navigate);
      expect(c.confidence, greaterThan(0.5));
    });

    test('توقف', () {
      expect(VoiceCommandRouter.parse('توقف').intent, VoiceIntent.stopNavigation);
    });

    test('طوارئ', () {
      expect(VoiceCommandRouter.parse('محتاج مساعدة طوارئ').intent, VoiceIntent.sos);
    });

    test('أين أنا', () {
      expect(VoiceCommandRouter.parse('فين أنا؟').intent, VoiceIntent.whereAmI);
    });

    test('بلّغ عن عائق', () {
      expect(VoiceCommandRouter.parse('عايز أبلغ عن عائق').intent, VoiceIntent.reportObstacle);
    });

    test('خريطة الجامعة', () {
      expect(VoiceCommandRouter.parse('افتح الجامعة').intent, VoiceIntent.openUniversity);
    });

    test('كرر', () {
      expect(VoiceCommandRouter.parse('قول تاني').intent, VoiceIntent.repeat);
    });

    test('أسرع وأبطأ', () {
      expect(VoiceCommandRouter.parse('اسرع شوية').intent, VoiceIntent.faster);
      expect(VoiceCommandRouter.parse('ابطي').intent, VoiceIntent.slower);
    });

    test('أمر غير مفهوم', () {
      final VoiceCommand c = VoiceCommandRouter.parse('زرقاء اليمامة');
      expect(c.intent, VoiceIntent.unknown);
      expect(c.isKnown, isFalse);
    });

    test('نص فارغ', () {
      expect(VoiceCommandRouter.parse('   ').intent, VoiceIntent.unknown);
    });

    test('كشف الوجهة', () {
      expect(VoiceCommandRouter.parse('خذني للجامعة').target, 'university');
    });
  });

  test('قائمة المساعدة غير فارغة', () {
    expect(VoiceCommandRouter.helpPhrases, isNotEmpty);
    expect(VoiceCommandRouter.helpPhrases.length, greaterThanOrEqualTo(8));
  });
}
