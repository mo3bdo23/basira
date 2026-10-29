import 'package:latlong2/latlong.dart';

/// أنواع العوائق التي يمكن للمجتمع الإبلاغ عنها.
enum ObstacleType {
  stairs('stairs', 'سلالم أو درج', '🪜'),
  hole('hole', 'حفرة أو كسر في الرصيف', '🕳️'),
  construction('construction', 'أعمال بناء', '🚧'),
  parkedCar('parked_car', 'سيارة واقفة على الرصيف', '🚗'),
  blockedSidewalk('blocked_sidewalk', 'رصيف مسدود', '⛔'),
  slippery('slippery', 'أرضية زلقة', '💧'),
  crowd('crowd', 'تزاحم', '👥'),
  brokenSignal('broken_signal', 'إشارة مرور معطلة', '🚦'),
  other('other', 'عائق آخر', '❓');

  const ObstacleType(this.id, this.labelAr, this.emoji);

  final String id;
  final String labelAr;
  final String emoji;

  static ObstacleType fromId(String? value) {
    for (final ObstacleType t in ObstacleType.values) {
      if (t.id == value || t.name == value) return t;
    }
    return ObstacleType.other;
  }
}

enum ObstacleStatus {
  pending('pending', 'بانتظار التحقق'),
  verified('verified', 'مؤكد'),
  resolved('resolved', 'تم إصلاحه');

  const ObstacleStatus(this.id, this.labelAr);
  final String id;
  final String labelAr;

  static ObstacleStatus fromId(String? value) {
    for (final ObstacleStatus s in ObstacleStatus.values) {
      if (s.id == value || s.name == value) return s;
    }
    return ObstacleStatus.pending;
  }
}

/// بلاغ عائق — يُخزَّن محليًا أولًا (Hive) ويُزامَن مع Firestore عند الاتصال.
class Obstacle {
  const Obstacle({
    required this.id,
    required this.type,
    required this.description,
    required this.lat,
    required this.lng,
    required this.reporterId,
    required this.createdAt,
    this.status = ObstacleStatus.pending,
    this.synced = false,
    this.severity = 2,
  });

  final String id;
  final ObstacleType type;
  final String description;
  final double lat;
  final double lng;
  final String reporterId;
  final DateTime createdAt;
  final ObstacleStatus status;
  final bool synced;

  /// 1 = منخفض، 2 = متوسط، 3 = خطر.
  final int severity;

  LatLng get position => LatLng(lat, lng);

  bool get isActive => status != ObstacleStatus.resolved;

  Obstacle copyWith({
    ObstacleType? type,
    String? description,
    ObstacleStatus? status,
    bool? synced,
    int? severity,
  }) {
    return Obstacle(
      id: id,
      type: type ?? this.type,
      description: description ?? this.description,
      lat: lat,
      lng: lng,
      reporterId: reporterId,
      createdAt: createdAt,
      status: status ?? this.status,
      synced: synced ?? this.synced,
      severity: severity ?? this.severity,
    );
  }

  /// جملة جاهزة للنطق: "سيارة واقفة على الرصيف، على بعد ١٥ مترًا".
  String toSpeech({double? distanceMeters}) {
    final String dist = distanceMeters == null ? '' : ' على بعد ${distanceMeters.round()} مترًا';
    return '${type.labelAr}$dist';
  }

  factory Obstacle.fromMap(Map<dynamic, dynamic> map, String id) => Obstacle(
        id: id,
        type: ObstacleType.fromId(map['type'] as String?),
        description: (map['description'] as String?) ?? '',
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        reporterId: (map['reporterId'] as String?) ?? 'unknown',
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now(),
        status: ObstacleStatus.fromId(map['status'] as String?),
        synced: map['synced'] == true,
        severity: (map['severity'] as num?)?.toInt() ?? 2,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type.id,
        'description': description,
        'lat': lat,
        'lng': lng,
        'reporterId': reporterId,
        'createdAt': createdAt.toIso8601String(),
        'status': status.id,
        'synced': synced,
        'severity': severity,
      };

  /// نسخة مناسبة للإرسال إلى Firestore.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'type': type.id,
        'description': description,
        'location': <String, dynamic>{'lat': lat, 'lng': lng},
        'reporterId': reporterId,
        'createdAt': createdAt.toIso8601String(),
        'status': status.id,
        'severity': severity,
      };
}
