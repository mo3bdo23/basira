import 'package:hive/hive.dart';

import '../core/geo.dart';
import '../models/traffic_signal.dart';
import 'storage_service.dart';

/// حالة إشارة في لحظة معينة.
class SignalSnapshot {
  const SignalSnapshot({
    required this.signal,
    required this.distanceMeters,
    required this.isGreen,
    required this.secondsRemaining,
  });

  final TrafficSignal signal;
  final double distanceMeters;
  final bool isGreen;
  final int secondsRemaining;

  /// رسالة صوتية جاهزة.
  String toSpeech() {
    final String state = isGreen
        ? 'الضوء أخضر الآن، تبقّى $secondsRemaining ثانية'
        : 'الضوء أحمر، انتظر $secondsRemaining ثانية';
    final String audio = signal.hasAudio
        ? 'وهذه الإشارة مزوّدة بمنبّه صوتي.'
        : 'لا يوجد منبّه صوتي في هذه الإشارة، احترس.';
    return 'إشارة ${signal.name} على بعد ${Geo.spokenDistance(distanceMeters)}. $state. $audio';
  }
}

/// إشارات المرور القريبة + دورتها الضوئية (تُحسب محليًا للعمل أوفلاين،
/// وتُحدَّث من Firestore عند توفر الاتصال).
class TrafficSignalService {
  TrafficSignalService({Box<dynamic>? box}) : _box = box ?? StorageService.instance.signals;

  final Box<dynamic> _box;

  List<TrafficSignal> all() {
    final List<TrafficSignal> list = <TrafficSignal>[];
    for (final dynamic key in _box.keys) {
      final dynamic raw = _box.get(key);
      if (raw is Map) list.add(TrafficSignal.fromMap(raw, key.toString()));
    }
    return list;
  }

  SignalSnapshot snapshot(TrafficSignal signal, double distanceMeters, {DateTime? now}) {
    final DateTime t = now ?? DateTime.now();
    final int cycle = signal.greenSeconds + signal.redSeconds;
    if (cycle <= 0) {
      return SignalSnapshot(
        signal: signal,
        distanceMeters: distanceMeters,
        isGreen: false,
        secondsRemaining: 0,
      );
    }
    final int elapsed = t.millisecondsSinceEpoch ~/ 1000 % cycle;
    final bool isGreen = elapsed < signal.greenSeconds;
    final int remaining = isGreen ? signal.greenSeconds - elapsed : cycle - elapsed;
    return SignalSnapshot(
      signal: signal,
      distanceMeters: distanceMeters,
      isGreen: isGreen,
      secondsRemaining: remaining,
    );
  }

  /// الإشارة الأقرب ضمن النطاق (للتنبيه أثناء التنقل).
  SignalSnapshot? nearest(double lat, double lng, {double radiusMeters = 60, DateTime? now}) {
    TrafficSignal? best;
    double bestDistance = double.infinity;
    for (final TrafficSignal s in all()) {
      final double d = Geo.distanceMeters(lat, lng, s.lat, s.lng);
      if (d < bestDistance && d <= radiusMeters) {
        bestDistance = d;
        best = s;
      }
    }
    if (best == null) return null;
    return snapshot(best, bestDistance, now: now);
  }

  /// تحديث محلي لحالة الإشارة (يُستدعى بعد مزامنة Firestore).
  Future<void> upsert(TrafficSignal signal) => _box.put(signal.id, signal.toMap());
}
