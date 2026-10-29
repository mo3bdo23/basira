import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// الاستماع للأوامر الصوتية بالعربية، مع كشف التوفر وتقليل الضوضاء.
class SttService {
  SttService({SpeechToText? engine}) : _stt = engine ?? SpeechToText();

  final SpeechToText _stt;
  bool _initialized = false;
  bool _available = false;
  String _localeId = 'ar_EG';

  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);
  final ValueNotifier<bool> available = ValueNotifier<bool>(false);
  final ValueNotifier<String> lastWords = ValueNotifier<String>('');

  bool get isAvailable => _available;
  String get localeId => _localeId;
  String? errorMessage;

  Future<bool> init() async {
    if (_initialized) return _available;
    try {
      _available = await _stt.initialize(
        onError: (SpeechRecognitionError e) {
          errorMessage = e.errorMsg;
          listening.value = false;
        },
        onStatus: (String status) {
          listening.value = status == 'listening';
        },
        debugLogging: false,
      );
      if (_available) {
        final List<LocaleName> locales = await _stt.locales();
        final LocaleName? arabic = locales.cast<LocaleName?>().firstWhere(
              (LocaleName? l) =>
                  l != null &&
                  (l.localeId == 'ar_EG' || l.localeId.toLowerCase().startsWith('ar')),
              orElse: () => null,
            );
        if (arabic != null) _localeId = arabic.localeId;
      }
    } catch (e) {
      _available = false;
      errorMessage = e.toString();
      debugPrint('STT init failed: $e');
    }
    available.value = _available;
    _initialized = true;
    return _available;
  }

  /// يبدأ الاستماع لجملة واحدة قصيرة.
  Future<bool> listen({
    required void Function(String text) onResult,
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 2),
    void Function(double level)? onSoundLevel,
  }) async {
    if (!_initialized) await init();
    if (!_available) return false;
    if (_stt.isListening) await _stt.stop();

    try {
      listening.value = true;
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          final String words = result.recognizedWords;
          if (words.trim().isNotEmpty) lastWords.value = words;
          if (result.finalResult && words.trim().isNotEmpty) {
            listening.value = false;
            onResult(words.trim());
          }
        },
        localeId: _localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onSoundLevelChange: onSoundLevel,
        onError: (SpeechRecognitionError e) {
          listening.value = false;
          errorMessage = e.errorMsg;
        },
        onStatus: (String s) {
          listening.value = s == 'listening';
        },
      );
      return true;
    } catch (e) {
      listening.value = false;
      errorMessage = e.toString();
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    listening.value = false;
  }

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    listening.value = false;
  }

  void dispose() {
    unawaitedSafe(cancel());
    listening.dispose();
    available.dispose();
    lastWords.dispose();
  }
}

void unawaitedSafe(Future<void> future) {
  // تجاهل النتيجة بأمان دون رفع lints.
  future.catchError((Object _) {});
}
