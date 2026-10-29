import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled, unavailable }

/// مصدر الموقع: GPS حقيقي، مع محاكاة للمحاكي/العرض التجريبي.
class LocationService {
  LocationService();

  final ValueNotifier<LatLng?> position = ValueNotifier<LatLng?>(null);
  final ValueNotifier<double> accuracyMeters = ValueNotifier<double>(0);
  final ValueNotifier<bool> gpsOn = ValueNotifier<bool>(false);
  final ValueNotifier<bool> simulating = ValueNotifier<bool>(false);

  StreamSubscription<Position>? _sub;
  Timer? _simTimer;
  LocationAccess access = LocationAccess.denied;
  String? errorMessage;

  bool get hasFix => position.value != null;

  Future<LocationAccess> ensureAccess() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        gpsOn.value = false;
        access = LocationAccess.serviceDisabled;
        return access;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        access = LocationAccess.deniedForever;
        return access;
      }
      if (permission == LocationPermission.denied) {
        access = LocationAccess.denied;
        return access;
      }
      access = LocationAccess.granted;
      gpsOn.value = true;
      return access;
    } catch (e) {
      errorMessage = e.toString();
      access = LocationAccess.unavailable;
      return access;
    }
  }

  Future<void> start() async {
    if (simulating.value) return;
    final LocationAccess a = await ensureAccess();
    if (a != LocationAccess.granted) return;
    try {
      _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).listen(
        (Position p) {
          position.value = LatLng(p.latitude, p.longitude);
          accuracyMeters.value = p.accuracy;
        },
        onError: (Object e) => errorMessage = e.toString(),
      );
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null && position.value == null) {
        position.value = LatLng(last.latitude, last.longitude);
        accuracyMeters.value = last.accuracy;
      }
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _simTimer?.cancel();
    _simTimer = null;
  }

  /// تغذية موقع يدويًا (اختبارات / محاكاة زر SOS في العرض).
  void feed(double lat, double lng, {double accuracy = 5}) {
    position.value = LatLng(lat, lng);
    accuracyMeters.value = accuracy;
  }

  /// محاكاة المشي على مسار — تُستخدم في العرض التجريبي وفي المحاكي
  /// الذي لا يوفّر GPS حقيقيًا.
  void simulateWalk(List<LatLng> path, {double speedMps = 1.3, Duration tick = const Duration(seconds: 1)}) {
    if (path.length < 2) return;
    _simTimer?.cancel();
    simulating.value = true;
    int segment = 0;
    double travelled = 0;

    void step() {
      if (segment >= path.length - 1) {
        simulating.value = false;
        _simTimer?.cancel();
        return;
      }
      final LatLng a = path[segment];
      final LatLng b = path[segment + 1];
      final double segLength = _distance(a, b);
      travelled += speedMps * (tick.inMilliseconds / 1000.0);
      if (travelled >= segLength) {
        travelled -= segLength;
        segment++;
        if (segment >= path.length - 1) {
          position.value = path.last;
          simulating.value = false;
          _simTimer?.cancel();
          return;
        }
      }
      final LatLng from = path[segment];
      final LatLng to = path[segment + 1];
      final double len = _distance(from, to);
      final double t = len == 0 ? 1 : (travelled / len).clamp(0.0, 1.0);
      position.value = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      accuracyMeters.value = 3;
      _simTimer = Timer(tick, step);
    }

    _simTimer?.cancel();
    position.value = path.first;
    _simTimer = Timer(tick, step);
  }

  void stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    simulating.value = false;
  }

  static double _distance(LatLng a, LatLng b) {
    const double r = 6371000;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180;
    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  void dispose() {
    _sub?.cancel();
    _simTimer?.cancel();
    position.dispose();
    accuracyMeters.dispose();
    gpsOn.dispose();
    simulating.dispose();
  }
}
