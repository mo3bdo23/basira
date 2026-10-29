import 'package:latlong2/latlong.dart';

/// إشارة مرور — تُبلَّغ صوتيًا عند الاقتراب، وتُقرأ حالتها من Firestore أو من دورة محلية.
class TrafficSignal {
  const TrafficSignal({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.hasAudio = false,
    this.greenSeconds = 25,
    this.redSeconds = 35,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;

  /// هل الإشارة مزوّدة بمنبّه صوتي للمكفوفين؟ (مطلب رسالة مدرسة النور)
  final bool hasAudio;

  final int greenSeconds;
  final int redSeconds;
  final DateTime? updatedAt;

  LatLng get position => LatLng(lat, lng);

  factory TrafficSignal.fromMap(Map<dynamic, dynamic> map, String id) => TrafficSignal(
        id: id,
        name: (map['name'] as String?) ?? '',
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        hasAudio: map['hasAudio'] == true,
        greenSeconds: (map['greenSeconds'] as num?)?.toInt() ?? 25,
        redSeconds: (map['redSeconds'] as num?)?.toInt() ?? 35,
        updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? ''),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'lat': lat,
        'lng': lng,
        'hasAudio': hasAudio,
        'greenSeconds': greenSeconds,
        'redSeconds': redSeconds,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };
}
