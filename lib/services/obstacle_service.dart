import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/geo.dart';
import '../models/obstacle.dart';
import 'storage_service.dart';

/// إدارة بلاغات العوائق: محلية أولًا، ثم مزامنة عند توفر الشبكة.
class ObstacleService {
  ObstacleService({Box<dynamic>? box}) : _box = box ?? StorageService.instance.obstacles;

  final Box<dynamic> _box;
  final Uuid _uuid = const Uuid();

  List<Obstacle> all() {
    final List<Obstacle> list = <Obstacle>[];
    for (final dynamic key in _box.keys) {
      final dynamic raw = _box.get(key);
      if (raw is Map) {
        list.add(Obstacle.fromMap(raw, key.toString()));
      }
    }
    list.sort((Obstacle a, Obstacle b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Obstacle> active() => all().where((Obstacle o) => o.isActive).toList();

  /// العوائق القريبة مرتبة بالأقرب.
  List<Obstacle> nearby(double lat, double lng, {double radiusMeters = 300}) {
    final List<Obstacle> items = active()
        .where((Obstacle o) =>
            Geo.distanceMeters(lat, lng, o.lat, o.lng) <= radiusMeters)
        .toList();
    items.sort((Obstacle a, Obstacle b) => Geo.distanceMeters(lat, lng, a.lat, a.lng)
        .compareTo(Geo.distanceMeters(lat, lng, b.lat, b.lng)));
    return items;
  }

  Future<Obstacle> report({
    required ObstacleType type,
    required double lat,
    required double lng,
    String description = '',
    String reporterId = 'local',
    int severity = 2,
  }) async {
    final Obstacle obstacle = Obstacle(
      id: _uuid.v4(),
      type: type,
      description: description,
      lat: lat,
      lng: lng,
      reporterId: reporterId,
      createdAt: DateTime.now(),
      severity: severity,
    );
    await _box.put(obstacle.id, obstacle.toMap());
    return obstacle;
  }

  Future<void> setStatus(String id, ObstacleStatus status) async {
    final dynamic raw = _box.get(id);
    if (raw is! Map) return;
    final Obstacle o = Obstacle.fromMap(raw, id);
    await _box.put(id, o.copyWith(status: status).toMap());
  }

  Future<void> markSynced(Iterable<String> ids) async {
    for (final String id in ids) {
      final dynamic raw = _box.get(id);
      if (raw is! Map) continue;
      final Obstacle o = Obstacle.fromMap(raw, id);
      await _box.put(id, o.copyWith(synced: true).toMap());
    }
  }

  List<Obstacle> pendingSync() => all().where((Obstacle o) => !o.synced).toList();

  Future<void> delete(String id) => _box.delete(id);

  // ── التحقق المجتمعي ────────────────────────────────────────
  static const int _confirmThreshold = 3;
  static const int _rejectThreshold = 3;

  Box<dynamic> get _votes => StorageService.instance.votes;

  /// تأكيد وجود العائق. بعد 3 تأكيدات يصبح «مؤكدًا».
  Future<Obstacle?> confirm(String id) async {
    final dynamic raw = _box.get(id);
    if (raw is! Map) return null;
    final Obstacle o = Obstacle.fromMap(raw, id);
    final int count = ((_votes.get('c_$id') as num?)?.toInt() ?? 0) + 1;
    await _votes.put('c_$id', count);
    final Obstacle updated = o.copyWith(
      verificationCount: count,
      status: count >= _confirmThreshold ? ObstacleStatus.verified : o.status,
    );
    await _box.put(id, updated.toMap());
    return updated;
  }

  /// اعتراض على العائق. بعد 3 اعتراضات يصبح «مرفوضًا» ويختفي من التنبيهات.
  Future<Obstacle?> dispute(String id) async {
    final dynamic raw = _box.get(id);
    if (raw is! Map) return null;
    final Obstacle o = Obstacle.fromMap(raw, id);
    final int count = ((_votes.get('d_$id') as num?)?.toInt() ?? 0) + 1;
    await _votes.put('d_$id', count);
    final Obstacle updated = o.copyWith(
      disputeCount: count,
      status: count >= _rejectThreshold ? ObstacleStatus.rejected : o.status,
    );
    await _box.put(id, updated.toMap());
    return updated;
  }
}