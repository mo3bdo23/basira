import 'package:flutter/foundation.dart';

import '../models/obstacle.dart';
import 'firebase_service.dart';
import 'obstacle_service.dart';

/// مزامنة البلاغات المعلّقة مع Firestore عندما يعود الاتصال.
/// التصميم: لا يمسح أي بلاغ محليًا إلا بعد نجاح الرفع.
class SyncService {
  SyncService({ObstacleService? obstacles}) : _obstacles = obstacles ?? ObstacleService();

  final ObstacleService _obstacles;

  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);
  final ValueNotifier<int> pending = ValueNotifier<int>(0);
  DateTime? lastSyncAt;
  String? lastMessage;

  int get pendingCount => _obstacles.pendingSync().length;

  Future<int> flush() async {
    if (busy.value) return 0;
    if (!FirebaseService.instance.ready) {
      lastMessage = 'وضع أوفلاين — سيتم الرفع عند توفر الاتصال';
      return 0;
    }
    busy.value = true;
    int uploaded = 0;
    try {
      final List<Obstacle> queue = _obstacles.pendingSync();
      for (final Obstacle item in queue) {
        final String id = item.id;
        try {
          await FirebaseService.instance.uploadObstacle(item);
          await _obstacles.markSynced(<String>[id]);
          uploaded++;
        } catch (_) {
          // فشل فردي لا يوقف بقية الطابور.
        }
      }
      lastSyncAt = DateTime.now();
      lastMessage = uploaded > 0 ? 'تم رفع $uploaded بلاغًا' : 'لا جديد للمزامنة';
    } finally {
      busy.value = false;
      pending.value = pendingCount;
    }
    return uploaded;
  }

  void refreshPending() {
    pending.value = pendingCount;
  }
}
