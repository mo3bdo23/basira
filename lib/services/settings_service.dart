import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/user.dart';
import 'storage_service.dart';

/// مصدر الحقيقة الوحيد لإعدادات المستخدم.
class SettingsService extends ChangeNotifier {
  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    final Map<dynamic, dynamic> raw = StorageService.instance.settings.toMap();
    _settings = AppSettings.fromMap(raw);
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    await StorageService.instance.settings.putAll(next.toMap());
    notifyListeners();
  }

  Future<void> patch({
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
    bool? speakOnStart,
    bool? saveSosHistory,
    bool? wakeWordEnabled,
  }) async {
    await update(_settings.copyWith(
      speechRate: speechRate,
      pitch: pitch,
      announceOnFocus: announceOnFocus,
      haptics: haptics,
      highContrast: highContrast,
      themeMode: themeMode,
      verbosity: verbosity,
      onboardingDone: onboardingDone,
      disclaimerAccepted: disclaimerAccepted,
      locationConsent: locationConsent,
      sosCountdownSeconds: sosCountdownSeconds,
      userName: userName,
      role: role,
      universityId: universityId,
      speakOnStart: speakOnStart,
      saveSosHistory: saveSosHistory,
      wakeWordEnabled: wakeWordEnabled,
    ));
  }
}
