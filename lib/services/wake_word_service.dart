import 'dart:async';

import 'package:flutter/foundation.dart';

import 'stt_service.dart';
import 'voice_command_router.dart';

/// استماع دائم لكلمة التنبيه «يا بصيرة».
///
/// يعيد تشغيل الاستماع تلقائيًا بعد كل جملة أو انقطاع، ويتوقف فورًا
/// عند سماع الكلمة ليفسح المجال لأمر المستخدم.
class WakeWordService {
  WakeWordService({
    required SttService stt,
    required Future<void> Function() onWake,
    Duration window = const Duration(seconds: 30),
  })  : _stt = stt,
        _onWake = onWake,
        _window = window;

  final SttService _stt;
  final Future<void> Function() _onWake;
  final Duration _window;

  static const List<String> wakeNames = <String>[
    'بصيره',
    'بصيرة',
    'يا بصيره',
    'يا بصيرة',
    'basira',
    'hey basira',
  ];

  bool _active = false;
  bool _handling = false;
  Timer? _restart;

  final ValueNotifier<bool> listeningForWake = ValueNotifier<bool>(false);

  bool get isActive => _active;

  /// هل النص يحتوي كلمة التنبيه؟
  bool matches(String text) {
    final String normalized = VoiceCommandRouter.normalize(text);
    if (normalized.isEmpty) return false;
    for (final String name in wakeNames) {
      if (normalized.contains(VoiceCommandRouter.normalize(name))) return true;
    }
    return false;
  }

  Future<void> start() async {
    if (_active) return;
    if (!_stt.isAvailable) {
      final bool ok = await _stt.init();
      if (!ok) return;
    }
    _active = true;
    _schedule(immediate: true);
  }

  void _schedule({bool immediate = false}) {
    _restart?.cancel();
    if (!_active) return;
    _restart = Timer(
      immediate ? Duration.zero : _window + const Duration(seconds: 1),
      _listenOnce,
    );
  }

  Future<void> _listenOnce() async {
    if (!_active || _handling) return;
    listeningForWake.value = true;
    final bool started = await _stt.listen(
      listenFor: _window,
      pauseFor: const Duration(seconds: 4),
      onPartial: (String text) {
        if (!_active || _handling) return;
        if (matches(text)) {
          _handling = true;
          listeningForWake.value = false;
          unawaited(_stt.stop());
          unawaited(_handleWake());
        }
      },
      onResult: (_) {
        // نهاية الجملة بلا كلمة تنبيه: نعيد التشغيل.
        if (_active && !_handling) {
          listeningForWake.value = false;
          _schedule();
        }
      },
    );

    if (!started) {
      listeningForWake.value = false;
      _schedule();
      return;
    }
    // نضمن إعادة التشغيل حتى لو لم تُرجع المنصة نتيجة نهائية.
    _schedule();
  }

  Future<void> _handleWake() async {
    try {
      await _onWake();
    } finally {
      _handling = false;
      if (_active) {
        listeningForWake.value = false;
        _schedule();
      }
    }
  }

  Future<void> stop() async {
    _active = false;
    _handling = false;
    _restart?.cancel();
    _restart = null;
    listeningForWake.value = false;
    await _stt.stop();
  }

  void dispose() {
    _restart?.cancel();
    listeningForWake.dispose();
  }
}
