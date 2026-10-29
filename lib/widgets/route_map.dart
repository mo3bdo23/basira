import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// خريطة مسار تخطيطية تعمل أوفلاين — ترسم المسار والموقع والوجهة.
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.position,
    this.headingDegrees,
    this.height = 260,
  });

  final List<LatLng> route;
  final LatLng? position;
  final double? headingDegrees;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = route.length < 2
        ? 'لا يوجد مسار'
        : 'خريطة المسار: ${route.length} نقاط، من ${route.first.latitude.toStringAsFixed(4)} إلى ${route.last.latitude.toStringAsFixed(4)}';

    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _RouteMapPainter(
              route: route,
              position: position,
              scheme: scheme,
              heading: headingDegrees,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.route,
    required this.position,
    required this.scheme,
    required this.heading,
  });

  final List<LatLng> route;
  final LatLng? position;
  final ColorScheme scheme;
  final double? heading;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect area = Offset.zero & size;
    canvas.drawRect(area, Paint()..color = scheme.surfaceContainerHighest.withValues(alpha: 0.5));

    final List<LatLng> pts = <LatLng>[...route, if (position != null) position!];
    if (pts.isEmpty) return;

    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final LatLng p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    if (maxLat - minLat < 1e-6) maxLat = minLat + 1e-6;
    if (maxLng - minLng < 1e-6) maxLng = minLng + 1e-6;

    const double pad = 0.14;
    final double latSpan = (maxLat - minLat) * (1 + pad * 2);
    final double lngSpan = (maxLng - minLng) * (1 + pad * 2);
    final double baseLat = minLat - (maxLat - minLat) * pad;
    final double baseLng = minLng - (maxLng - minLng) * pad;

    Offset project(LatLng p) => Offset(
          (p.longitude - baseLng) / lngSpan * size.width,
          (baseLat + latSpan - p.latitude) / latSpan * size.height,
        );

    final Paint grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (route.length > 1) {
      final Path shadow = Path();
      final Offset s0 = project(route.first);
      shadow.moveTo(s0.dx, s0.dy);
      for (int i = 1; i < route.length; i++) {
        final Offset o = project(route[i]);
        shadow.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        shadow,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        shadow,
        Paint()
          ..color = scheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // علامة النهاية.
      final Offset end = project(route.last);
      canvas.drawCircle(end, 15, Paint()..color = scheme.tertiary);
      canvas.drawCircle(
        end,
        15,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(end, 6, Paint()..color = Colors.white);
    }

    if (position != null) {
      final Offset me = project(position!);
      canvas.drawCircle(me, 18, Paint()..color = scheme.primary.withValues(alpha: 0.2));
      canvas.drawCircle(me, 11, Paint()..color = scheme.primary);
      canvas.drawCircle(
        me,
        11,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
      if (heading != null) {
        final double rad = (heading! - 90) * math.pi / 180;
        final Offset tip = me + Offset(math.cos(rad) * 30, math.sin(rad) * 30);
        final Offset left = me + Offset(math.cos(rad + 2.5) * 18, math.sin(rad + 2.5) * 18);
        final Offset right = me + Offset(math.cos(rad - 2.5) * 18, math.sin(rad - 2.5) * 18);
        final Path cone = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close();
        canvas.drawPath(cone, Paint()..color = scheme.primary.withValues(alpha: 0.35));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.route != route ||
      oldDelegate.heading != heading ||
      oldDelegate.scheme != scheme;
}
