import 'package:flutter/services.dart';

/// أنماط اهتزاز دلالية: كل نوع حدث له «توقيع» لمسي مميّز،
/// حتى يستطيع المستخدم تمييزه دون سماع الصوت (بيئة صاخبة/سماعة معطلة).
enum HapticPattern {
  step, // خطوة عادية
  turnLeft, // انعطف يسارًا
  turnRight, // انعطف يمينًا
  arrived, // وصلت الوجهة
  obstacle, // عائق قريب
  danger, // خطر (إشارة حمراء / خارج المسار)
  signalGreen, // إشارة خضراء
  signalRed, // إشارة حمراء
  success, // نجاح (حفظ/إرسال)
  error, // خطأ
}

class HapticService {
  const HapticService._();

  /// ينفّذ نمط الاهتزاز. [enabled] يأتي من إعدادات المستخدم.
  static Future<void> play(HapticPattern pattern, {bool enabled = true}) async {
    if (!enabled) return;
    try {
      switch (pattern) {
        case HapticPattern.step:
          await HapticFeedback.selectionClick();

        case HapticPattern.turnLeft:
          // نبضتان سريعتان ثم وقفة: «شمال»
          await HapticFeedback.lightImpact();
          await Future<void>.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.lightImpact();
          await Future<void>.delayed(const Duration(milliseconds: 260));
          await HapticFeedback.lightImpact();

        case HapticPattern.turnRight:
          // نبضتان قويتان: «يمين»
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.heavyImpact();

        case HapticPattern.arrived:
          // ثلاث نبضات قوية متصاعدة
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 160));
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 160));
          await HapticFeedback.heavyImpact();

        case HapticPattern.obstacle:
          await HapticFeedback.mediumImpact();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.mediumImpact();

        case HapticPattern.danger:
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await HapticFeedback.heavyImpact();

        case HapticPattern.signalGreen:
          // ثلاث نبضات خفيفة: «امشِ»
          for (int i = 0; i < 3; i++) {
            await HapticFeedback.lightImpact();
            await Future<void>.delayed(const Duration(milliseconds: 70));
          }

        case HapticPattern.signalRed:
          // نبضة واحدة طويلة: «قف»
          await HapticFeedback.heavyImpact();

        case HapticPattern.success:
          await HapticFeedback.lightImpact();
          await Future<void>.delayed(const Duration(milliseconds: 80));
          await HapticFeedback.mediumImpact();

        case HapticPattern.error:
          await HapticFeedback.mediumImpact();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // بعض الأجهزة لا تدعم الاهتزاز — نتجاهل بهدوء.
    }
  }
}
