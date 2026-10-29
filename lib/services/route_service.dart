import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../models/safe_route.dart';
import 'storage_service.dart';

/// المسارات الآمنة المحفوظة (تعمل أوفلاين من Hive).
class RouteService {
  RouteService({Box<dynamic>? box}) : _box = box ?? StorageService.instance.routes;

  final Box<dynamic> _box;

  List<SafeRoute> all() {
    final List<SafeRoute> list = <SafeRoute>[];
    for (final dynamic key in _box.keys) {
      final dynamic raw = _box.get(key);
      if (raw is! Map) continue;
      try {
        final SafeRoute route = SafeRoute.fromMap(raw);
        if (route.points.length >= 2) list.add(route);
      } catch (_) {
        // تجاهل مسارًا تالفًا.
      }
    }
    return list;
  }

  SafeRoute? byId(String id) {
    final dynamic raw = _box.get(id);
    if (raw is! Map) return null;
    return SafeRoute.fromMap(raw);
  }

  /// المسارات مرتبة حسب قرب نقطة بدايتها من المستخدم.
  List<SafeRoute> nearest(LatLng from, {int limit = 6}) {
    final List<SafeRoute> list = all();
    list.sort((SafeRoute a, SafeRoute b) {
      final double da = Geo.distanceMeters(
          from.latitude, from.longitude, a.start.latitude, a.start.longitude);
      final double db = Geo.distanceMeters(
          from.latitude, from.longitude, b.start.latitude, b.start.longitude);
      return da.compareTo(db);
    });
    return list.take(limit).toList();
  }
}
