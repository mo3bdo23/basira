import 'package:flutter/material.dart';

import 'user.dart';

enum AppLanguage { arabic, english }

enum GuidanceVerbosity {
  brief('مختصر', 'الأوامر الأساسية فقط'),
  normal('متوسط', 'أوامر + مسافة + اتجاه'),
  detailed('مفصّل', 'كل التفاصيل والعلامات المميزة');

  const GuidanceVerbosity(this.labelAr, this.descriptionAr);
  final String labelAr;
  final String descriptionAr;
}

/// إعدادات التطبيق — تُحفظ في Hive (مشفّرة) وتُقرأ عند الإقلاع.
@immutable
class AppSettings {
  const AppSettings({
    this.speechRate = 0.45,
    this.pitch = 1.0,
    this.announceOnFocus = true,
    this.haptics = true,
    this.highContrast = false,
    this.themeMode = ThemeMode.system,
    this.verbosity = GuidanceVerbosity.normal,
    this.onboardingDone = false,
    this.disclaimerAccepted = false,
    this.locationConsent = false,
    this.sosCountdownSeconds = 5,
    this.userName = '',
    this.role = UserRole.blind,
    this.universityId = '',
    this.language = AppLanguage.arabic,
    this.speakOnStart = true,
    this.saveSosHistory = true,
  });

  final double speechRate;
  final double pitch;

  /// يقرأ العنصر تلقائيًا عند وصول مؤشر TalkBack إليه.
  final bool announceOnFocus;

  final bool haptics;
  final bool highContrast;
  final ThemeMode themeMode;
  final GuidanceVerbosity verbosity;
  final bool onboardingDone;
  final bool disclaimerAccepted;
  final bool locationConsent;
  final int sosCountdownSeconds;
  final String userName;
  final UserRole role;
  final String universityId;
  final AppLanguage language;
  final bool speakOnStart;
  final bool saveSosHistory;

  bool get needsOnboarding => !onboardingDone || !disclaimerAccepted;

  AppSettings copyWith({
    double? speechRate,
    double? pitch,
    bool? announceOnFocus,
    bool? haptics,
    bool? highContrast,
    ThemeMode? themeMode,
    GuidanceVerbosity? verbosity,
    bool? onboardingDone,
    bool? disclaimerAccepted,
    bool? locationConsent,
    int? sosCountdownSeconds,
    String? userName,
    UserRole? role,
    String? universityId,
    AppLanguage? language,
    bool? speakOnStart,
    bool? saveSosHistory,
  }) {
    return AppSettings(
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      announceOnFocus: announceOnFocus ?? this.announceOnFocus,
      haptics: haptics ?? this.haptics,
      highContrast: highContrast ?? this.highContrast,
      themeMode: themeMode ?? this.themeMode,
      verbosity: verbosity ?? this.verbosity,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      locationConsent: locationConsent ?? this.locationConsent,
      sosCountdownSeconds: sosCountdownSeconds ?? this.sosCountdownSeconds,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      universityId: universityId ?? this.universityId,
      language: language ?? this.language,
      speakOnStart: speakOnStart ?? this.speakOnStart,
      saveSosHistory: saveSosHistory ?? this.saveSosHistory,
    );
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    final num rate = (map['speechRate'] as num?) ?? 0.45;
    return AppSettings(
      speechRate: rate.toDouble().clamp(0.1, 1.0).toDouble(),
      pitch: ((map['pitch'] as num?) ?? 1.0).toDouble().clamp(0.5, 2.0).toDouble(),
      announceOnFocus: map['announceOnFocus'] != false,
      haptics: map['haptics'] != false,
      highContrast: map['highContrast'] == true,
      themeMode: _themeFromId(map['themeMode'] as String?),
      verbosity: _verbosityFromId(map['verbosity'] as String?),
      onboardingDone: map['onboardingDone'] == true,
      disclaimerAccepted: map['disclaimerAccepted'] == true,
      locationConsent: map['locationConsent'] == true,
      sosCountdownSeconds: ((map['sosCountdownSeconds'] as num?) ?? 5).toInt().clamp(3, 15),
      userName: (map['userName'] as String?) ?? '',
      role: UserRole.fromId(map['role'] as String?),
      universityId: (map['universityId'] as String?) ?? '',
      language: map['language'] == 'english' ? AppLanguage.english : AppLanguage.arabic,
      speakOnStart: map['speakOnStart'] != false,
      saveSosHistory: map['saveSosHistory'] != false,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'speechRate': speechRate,
        'pitch': pitch,
        'announceOnFocus': announceOnFocus,
        'haptics': haptics,
        'highContrast': highContrast,
        'themeMode': themeMode.name,
        'verbosity': verbosity.name,
        'onboardingDone': onboardingDone,
        'disclaimerAccepted': disclaimerAccepted,
        'locationConsent': locationConsent,
        'sosCountdownSeconds': sosCountdownSeconds,
        'userName': userName,
        'role': role.id,
        'universityId': universityId,
        'language': language.name,
        'speakOnStart': speakOnStart,
        'saveSosHistory': saveSosHistory,
      };

  static ThemeMode _themeFromId(String? id) {
    switch (id) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static GuidanceVerbosity _verbosityFromId(String? id) {
    for (final GuidanceVerbosity v in GuidanceVerbosity.values) {
      if (v.name == id) return v;
    }
    return GuidanceVerbosity.normal;
  }
}
