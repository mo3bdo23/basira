import 'package:latlong2/latlong.dart';

import '../core/geo.dart';

/// مبنى داخل الحرم الجامعي — له وصف صوتي ومسار إرشادي.
class CampusBuilding {
  const CampusBuilding({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.description = '',
    this.entranceNote = '',
    this.category = 'building',
    this.audioGuide = const <String>[],
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String description;
  final String entranceNote;

  /// entrance | faculty | library | service | gate | landmark
  final String category;

  /// خطوات دليل صوتي تُنطق بالترتيب عند الوصول أو عند طلب الشرح.
  final List<String> audioGuide;

  LatLng get position => LatLng(lat, lng);

  String get categoryLabelAr {
    switch (category) {
      case 'faculty':
        return 'كلية';
      case 'library':
        return 'مكتبة';
      case 'service':
        return 'خدمات';
      case 'gate':
        return 'بوابة';
      case 'landmark':
        return 'علامة مميزة';
      default:
        return 'مبنى';
    }
  }

  factory CampusBuilding.fromMap(Map<dynamic, dynamic> map) => CampusBuilding(
        id: (map['id'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        description: (map['description'] as String?) ?? '',
        entranceNote: (map['entranceNote'] as String?) ?? '',
        category: (map['category'] as String?) ?? 'building',
        audioGuide: <String>[
          for (final Object? step in (map['audioGuide'] as List<dynamic>? ?? const <dynamic>[]))
            step.toString(),
        ],
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'description': description,
        'entranceNote': entranceNote,
        'category': category,
        'audioGuide': audioGuide,
      };
}

/// جامعة/حرم جامعي بخرائط صوتية.
class University {
  const University({
    required this.id,
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
    required this.buildings,
    this.shortName = '',
    this.description = '',
  });

  final String id;
  final String name;
  final String shortName;
  final String city;
  final double lat;
  final double lng;
  final String description;
  final List<CampusBuilding> buildings;

  LatLng get center => LatLng(lat, lng);

  CampusBuilding? get mainGate {
    for (final CampusBuilding b in buildings) {
      if (b.category == 'gate') return b;
    }
    return buildings.isEmpty ? null : buildings.first;
  }

  /// أقرب مبنى لموقع معين (بالمتر).
  CampusBuilding? nearestBuilding(double lat, double lng) {
    CampusBuilding? best;
    double bestDistance = double.infinity;
    for (final CampusBuilding b in buildings) {
      final double d = Geo.distanceMeters(lat, lng, b.lat, b.lng);
      if (d < bestDistance) {
        bestDistance = d;
        best = b;
      }
    }
    return best;
  }

  factory University.fromMap(Map<dynamic, dynamic> map) => University(
        id: (map['id'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        shortName: (map['shortName'] as String?) ?? '',
        city: (map['city'] as String?) ?? '',
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        description: (map['description'] as String?) ?? '',
        buildings: <CampusBuilding>[
          for (final Object? b in (map['buildings'] as List<dynamic>? ?? const <dynamic>[]))
            CampusBuilding.fromMap(b as Map<dynamic, dynamic>),
        ],
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'shortName': shortName,
        'city': city,
        'lat': lat,
        'lng': lng,
        'description': description,
        'buildings': buildings.map((CampusBuilding b) => b.toMap()).toList(),
      };
}
