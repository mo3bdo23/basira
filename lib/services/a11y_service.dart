import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// إتاحة: إعلانات قارئ الشاشة (TalkBack / VoiceOver) + اهتزاز دلالي.
class A11yService {
  const A11yService._();

  /// إعلان فوري عبر قارئ الشاشة (لا يُقرأ إلا إذا كان مفعّلًا).
  static Future<void> announce(String message, {bool assertive = true}) async {
    if (message.trim().isEmpty) return;
    try {
      // ignore: deprecated_member_use
      await SemanticsService.announce(message, TextDirection.rtl);
      if (assertive) {
        // لا شيء إضافي: الإعلان أعلاه كافٍ لـ TalkBack/VoiceOver.
      }
    } catch (_) {
      // بعض المنصات لا تدعم الإعلان المباشر — نتجاهل بهدوء.
    }
  }

  /// نمط اهتزاز دلالي: قصير = تنبيه، مزدوج = انتقال، طويل = خطر.
  static Future<void> haptic(String pattern, {bool enabled = true}) async {
    if (!enabled) return;
    try {
      switch (pattern) {
        case 'danger':
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.heavyImpact();
        case 'double':
          await HapticFeedback.mediumImpact();
          await Future<void>.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.mediumImpact();
        case 'success':
          await HapticFeedback.lightImpact();
        default:
          await HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }
}
