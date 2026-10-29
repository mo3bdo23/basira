/// جهة اتصال طارئة (SOS).
class SosContact {
  const SosContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = '',
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  String get initial {
    final String trimmed = name.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }

  /// تنقية الرقم ليكون صالحًا للاتصال الدولي (مصر +20).
  String get dialablePhone {
    final String digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('00')) return '+${digits.substring(2)}';
    if (digits.startsWith('0')) return '+20${digits.substring(1)}';
    return digits;
  }

  SosContact copyWith({String? name, String? phone, String? relation, bool? isPrimary}) {
    return SosContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  factory SosContact.fromMap(Map<dynamic, dynamic> map, String id) => SosContact(
        id: id,
        name: (map['name'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        relation: (map['relation'] as String?) ?? '',
        isPrimary: map['isPrimary'] == true,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'phone': phone,
        'relation': relation,
        'isPrimary': isPrimary,
      };
}

/// سجل حدث طارئ (للخصوصية: يُحفظ محليًا فقط).
class SosEvent {
  const SosEvent({
    required this.id,
    required this.createdAt,
    required this.lat,
    required this.lng,
    required this.contactsNotified,
    this.cancelled = false,
  });

  final String id;
  final DateTime createdAt;
  final double lat;
  final double lng;
  final int contactsNotified;
  final bool cancelled;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'createdAt': createdAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'contactsNotified': contactsNotified,
        'cancelled': cancelled,
      };

  factory SosEvent.fromMap(Map<dynamic, dynamic> map, String id) => SosEvent(
        id: id,
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now(),
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        contactsNotified: (map['contactsNotified'] as num?)?.toInt() ?? 0,
        cancelled: map['cancelled'] == true,
      );
}
