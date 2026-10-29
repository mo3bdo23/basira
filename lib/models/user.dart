/// أدوار المستخدم داخل منظومة «بصيرة».
enum UserRole {
  blind('blind', 'مستخدم كفيف', 'Blind user'),
  lowVision('low_vision', 'مستخدم ضعيف البصر', 'Low-vision user'),
  volunteer('volunteer', 'متطوع', 'Volunteer'),
  universityAdmin('university_admin', 'مسؤول جامعي', 'University admin'),
  admin('admin', 'مسؤول النظام', 'Administrator');

  const UserRole(this.id, this.labelAr, this.labelEn);

  final String id;
  final String labelAr;
  final String labelEn;

  static UserRole fromId(String? value) {
    for (final UserRole r in UserRole.values) {
      if (r.id == value || r.name == value) return r;
    }
    return UserRole.blind;
  }

  /// صلاحيات إدارة المحتوى المجتمعي (التحقق من البلاغات).
  bool get canModerate =>
      this == UserRole.universityAdmin || this == UserRole.admin || this == UserRole.volunteer;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    this.universityId = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final UserRole role;
  final String phone;
  final String universityId;
  final DateTime? createdAt;

  bool get isGuest => id == 'guest';

  AppUser copyWith({String? name, UserRole? role, String? phone, String? universityId}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      universityId: universityId ?? this.universityId,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromMap(Map<dynamic, dynamic> map, String id) => AppUser(
        id: id,
        name: (map['name'] as String?) ?? '',
        role: UserRole.fromId(map['role'] as String?),
        phone: (map['phone'] as String?) ?? '',
        universityId: (map['universityId'] as String?) ?? '',
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? ''),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'role': role.id,
        'phone': phone,
        'universityId': universityId,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  static const AppUser guest = AppUser(
    id: 'guest',
    name: 'زائر',
    role: UserRole.blind,
  );
}
