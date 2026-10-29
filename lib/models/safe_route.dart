import 'package:latlong2/latlong.dart';

import '../core/geo.dart';

/// مسار آمن موثّق (من مدرسة/جامعة/مجتمع) بنقاط إرشادية.
class SafeRoute {
  const SafeRoute({
    required this.id,
    required this.name,
    required this.city,
    required this.points,
    this.description = '',
    this.safetyScore = 3,
    this.landmarks = const <String>[],
    this.estimatedMinutes = 0,
    this.tags = const <String>[],
  });

  final String id;
  final String name;
  final String city;
  final String description;

  /// درجة الأمان من 1 (غير آمن) إلى 5 (آمن جدًا).
  final int safetyScore;

  /// نقاط المسار بالترتيب (بداية → نهاية).
  final List<LatLng> points;

  /// علامات مميزة تُنطق عند المرور بها.
  final List<String> landmarks;

  final int estimatedMinutes;
  final List<String> tags;

  LatLng get start => points.first;
  LatLng get end => points.last;

  double get lengthMeters {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += Geo.distanceMeters(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  String get safetyLabelAr {
    switch (safetyScore) {
      case 5:
        return 'آمن جدًا';
      case 4:
        return 'آمن';
      case 3:
        return 'متوسط الأمان';
      case 2:
        return 'يحتاج حذرًا';
      default:
        return 'غير آمن';
    }
  }

  String get summaryAr {
    final int minutes = estimatedMinutes > 0
        ? estimatedMinutes
        : Geo.walkingMinutes(lengthMeters).ceil();
    return '$name — ${Geo.shortDistance(lengthMeters)}، حوالي $minutes دقيقة، $safetyLabelAr';
  }

  factory SafeRoute.fromMap(Map<dynamic, dynamic> map) => SafeRoute(
        id: (map['id'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        city: (map['city'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        safetyScore: (map['safetyScore'] as num?)?.toInt() ?? 3,
        estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 0,
        points: <LatLng>[
          for (final Object? p in (map['points'] as List<dynamic>? ?? const <dynamic>[]))
            if (p is List && p.length >= 2)
              LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        landmarks: <String>[
          for (final Object? l in (map['landmarks'] as List<dynamic>? ?? const <dynamic>[]))
            l.toString(),
        ],
        tags: <String>[
          for (final Object? t in (map['tags'] as List<dynamic>? ?? const <dynamic>[])) t.toString(),
        ],
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'city': city,
        'description': description,
        'safetyScore': safetyScore,
        'estimatedMinutes': estimatedMinutes,
        'points': points.map((LatLng p) => <double>[p.latitude, p.longitude]).toList(),
        'landmarks': landmarks,
        'tags': tags,
      };
}
