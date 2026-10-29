import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../models/university.dart';

/// خريطة تخطيطية للحرم الجامعي — تعمل **أوفلاين بالكامل** (CustomPaint)
/// دون الحاجة لتحميل بلاطات خرائط. تُقرأ وصفًا نصيًا في قارئ الشاشة.
class CampusMap extends StatelessWidget {
  const CampusMap({
    super.key,
    required this.university,
    this.position,
    this.route,
    this.target,
    this.height = 320,
    this.showLegend = true,
  });

  final University university;
  final LatLng? position;
  final List<LatLng>? route;
  final LatLng? target;
  final double height;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String description = _describe();

    return Semantics(
      container: true,
      label: description,
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _CampusPainter(
                  university: university,
                  position: position,
                  route: route,
                  target: target,
                  scheme: scheme,
                ),
              ),
            ),
          ),
          if (showLegend) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 6,
              children: <Widget>[
                _LegendDot(color: scheme.primary, label: 'مسار'),
                _LegendDot(color: scheme.error, label: 'أنت هنا'),
                _LegendDot(color: scheme.tertiary, label: 'الوجهة'),
                _LegendDot(color: scheme.secondary, label: 'مبانٍ'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _describe() {
    final StringBuffer sb = StringBuffer('خريطة تخطيطية لـ ${university.name}. ');
    sb.write('تحتوي على ${university.buildings.length} مبنى. ');
    final int i = university.buildings.indexWhere((CampusBuilding b) => b.category == 'gate');
    if (i >= 0) sb.write('البوابة الرئيسية: ${university.buildings[i].name}. ');
    if (position != null) sb.write('موقعك الحالي معروض على الخريطة. ');
    if (target != null) sb.write('الوجهة محددة على الخريطة. ');
    if (route != null && route!.length > 1) sb.write('المسار مرسوم من موقعك إلى الوجهة.');
    return sb.toString();
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CampusPainter extends CustomPainter {
  _CampusPainter({
    required this.university,
    required this.position,
    required this.route,
    required this.target,
    required this.scheme,
  });

  final University university;
  final LatLng? position;
  final List<LatLng>? route;
  final LatLng? target;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect area = Offset.zero & size;
    canvas.drawRect(area, Paint()..color = scheme.surfaceContainerHighest.withOpacity(0.45));

    final List<LatLng> all = <LatLng>[
      for (final CampusBuilding b in university.buildings) b.position,
      if (position != null) position!,
      if (target != null) target!,
      if (route != null) ...route!,
    ];
    if (all.isEmpty) return;

    double minLat = all.first.latitude, maxLat = all.first.latitude;
    double minLng = all.first.longitude, maxLng = all.first.longitude;
    for (final LatLng p in all) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    if (maxLat - minLat < 1e-6) maxLat = minLat + 1e-6;
    if (maxLng - minLng < 1e-6) maxLng = minLng + 1e-6;

    const double pad = 0.16;
    final double latSpan = (maxLat - minLat) * (1 + pad * 2);
    final double lngSpan = (maxLng - minLng) * (1 + pad * 2);
    final double originLat = minLat - (maxLat - minLat) * pad;
    final double originLng = minLng - (maxLng - minLng) * pad;

    Offset project(LatLng p) {
      final double x = (p.longitude - originLng) / lngSpan * size.width;
      final double y = (originLat + latSpan - p.latitude) / latSpan * size.height;
      return Offset(x, y);
    }

    // شبكة خفيفة للدلالة على المسافات.
    final Paint grid = Paint()
      ..color = scheme.outlineVariant.withOpacity(0.35)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // المسار.
    final List<LatLng>? pts = route;
    if (pts != null && pts.length > 1) {
      final Path path = Path();
      final Offset start = project(pts.first);
      path.moveTo(start.dx, start.dy);
      for (int i = 1; i < pts.length; i++) {
        final Offset o = project(pts[i]);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = scheme.primary.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // المباني.
    for (final CampusBuilding b in university.buildings) {
      final Offset o = project(b.position);
      final bool isTarget = target != null && b.id == _targetBuildingId;
      final Color color = isTarget
          ? scheme.tertiary
          : b.category == 'gate'
              ? scheme.primary
              : scheme.secondary;
      final Rect rect = Rect.fromCenter(center: o, width: 40, height: 30);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(9)),
        Paint()..color = color.withOpacity(0.9),
      );
      _label(canvas, b.name, o + const Offset(0, 26), color, size);
    }

    // موقع المستخدم.
    if (position != null) {
      final Offset o = project(position!);
      canvas.drawCircle(o, 16, Paint()..color = scheme.error.withOpacity(0.25));
      canvas.drawCircle(o, 9, Paint()..color = scheme.error);
      canvas.drawCircle(
        o,
        9,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _label(canvas, 'أنت هنا', o + const Offset(0, 30), scheme.error, size, bold: true);
    }

    // الوجهة.
    if (target != null) {
      final Offset o = project(target!);
      final Path star = Path();
      for (int i = 0; i < 10; i++) {
        final double r = i.isEven ? 16 : 7;
        final double a = -math.pi / 2 + i * math.pi / 5;
        final Offset pt = o + Offset(math.cos(a) * r, math.sin(a) * r);
        if (i == 0) {
          star.moveTo(pt.dx, pt.dy);
        } else {
          star.lineTo(pt.dx, pt.dy);
        }
      }
      star.close();
      canvas.drawPath(star, Paint()..color = scheme.tertiary);
    }
  }

  String? get _targetBuildingId {
    if (target == null) return null;
    for (final CampusBuilding b in university.buildings) {
      if (Geo.distanceMeters(b.lat, b.lng, target!.latitude, target!.longitude) < 25) {
        return b.id;
      }
    }
    return null;
  }

  void _label(Canvas canvas, String text, Offset at, Color color, Size size, {bool bold = false}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: bold ? 14 : 12,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 130);
    double x = at.dx - tp.width / 2;
    x = x.clamp(2.0, size.width - tp.width - 2);
    tp.paint(canvas, Offset(x, at.dy));
  }

  @override
  bool shouldRepaint(covariant _CampusPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.route != route ||
        oldDelegate.target != target ||
        oldDelegate.university.id != university.id ||
        oldDelegate.scheme != scheme;
  }
}
