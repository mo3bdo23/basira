import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// محرك النطق: عربي مصري (ar-EG) مع طابور نطق يمنع تراكب الجُمل،
/// وتسريع/إبطاء، وإيقاف فوري (مهم عند أوامر "توقف").
class TtsService {
  TtsService({FlutterTts? engine}) : _tts = engine ?? FlutterTts();

  final FlutterTts _tts;
  final List<String> _queue = <String>[];
  bool _busy = false;
  bool _available = true;
  bool _initialized = false;
  double _rate = 0.45;
  double _pitch = 1.0;

  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> unavailable = ValueNotifier<bool>(false);

  bool get isAvailable => _available;
  String? lastSpoken;
  String _language = 'ar-EG';

  Future<void> init({double rate = 0.45, double pitch = 1.0}) async {
    _rate = rate;
    _pitch = pitch;
    if (_initialized) return;
    try {
      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(1.0);
      // الانتظار حتى تنتهي الجملة يسمح ببناء طابور مرتب.
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;
    } catch (e) {
      _available = false;
      unavailable.value = true;
      _initialized = true;
      debugPrint('TTS init failed: $e');
    }
  }

  /// اختيار صوت عربي إن وُجد على الجهاز.
  Future<String?> useBestArabicVoice() async {
    try {
      final dynamic raw = await _tts.getVoices;
      if (raw is! List<dynamic>) return null;
      for (final dynamic v in raw) {
        if (v is! Map<dynamic, dynamic>) continue;
        final String? locale = v['locale']?.toString();
        if (locale != null && locale.toLowerCase().startsWith('ar')) {
          await _tts.setVoice(<String, String>{
            'name': v['name'].toString(),
            'locale': locale,
          });
          _language = locale;
          return locale;
        }
      }
    } catch (_) {
      // لا يوجد صوت عربي مثبّت — سيستخدم النظام الافتراضي.
    }
    return null;
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.1, 1.0).toDouble();
    try {
      await _tts.setSpeechRate(_rate);
    } catch (_) {}
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0).toDouble();
    try {
      await _tts.setPitch(_pitch);
    } catch (_) {}
  }

  /// نطق نص. [interrupt] يقطع أي كلام جارٍ (للتنبيهات العاجلة).
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) await init(rate: _rate, pitch: _pitch);
    if (!_available) return;

    if (interrupt) {
      _queue.clear();
      try {
        await _tts.stop();
      } catch (_) {}
    }
    _queue.add(text);
    lastSpoken = text;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final String text = _queue.removeAt(0);
        speaking.value = true;
        try {
          await _tts.speak(text);
        } catch (_) {
          _available = false;
          unavailable.value = true;
        }
      }
    } finally {
      speaking.value = false;
      _busy = false;
    }
  }

  Future<void> stop() async {
    _queue.clear();
    try {
      await _tts.stop();
    } catch (_) {}
    speaking.value = false;
  }

  Future<void> dispose() async {
    await stop();
    speaking.dispose();
    unavailable.dispose();
  }
}
