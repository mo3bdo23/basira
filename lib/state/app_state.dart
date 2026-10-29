import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_config.dart';
import '../core/geo.dart';
import '../models/app_settings.dart';
import '../models/obstacle.dart';
import '../models/safe_route.dart';
import '../models/university.dart';
import '../models/user.dart';
import '../services/a11y_service.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/navigation_engine.dart';
import '../services/obstacle_service.dart';
import '../services/route_service.dart';
import '../services/settings_service.dart';
import '../services/sos_service.dart';
import '../services/stt_service.dart';
import '../services/sync_service.dart';
import '../services/traffic_signal_service.dart';
import '../services/tts_service.dart';
import '../services/university_service.dart';

/// الحالة المركزية للتطبيق: تملك الخدمات وتنسّق بينها.
class AppState extends ChangeNotifier {
  AppState({
    SettingsService? settings,
    TtsService? tts,
    SttService? stt,
    LocationService? location,
    ConnectivityService? connectivity,
    ObstacleService? obstacles,
    UniversityService? universities,
    TrafficSignalService? signals,
    SosService? sos,
    SyncService? sync,
    RouteService? routes,
  })  : settings = settings ?? SettingsService(),
        tts = tts ?? TtsService(),
        stt = stt ?? SttService(),
        location = location ?? LocationService(),
        connectivity = connectivity ?? ConnectivityService(),
        obstacles = obstacles ?? ObstacleService(),
        universities = universities ?? UniversityService(),
        signals = signals ?? TrafficSignalService(),
        sos = sos ?? SosService(),
        sync = sync ?? SyncService(),
        routes = routes ?? RouteService();

  final SettingsService settings;
  final TtsService tts;
  final SttService stt;
  final LocationService location;
  final ConnectivityService connectivity;
  final ObstacleService obstacles;
  final UniversityService universities;
  final TrafficSignalService signals;
  final SosService sos;
  final SyncService sync;
  final RouteService routes;

  AppUser user = AppUser.guest;

  SafeRoute? activeRoute;
  NavigationEngine? _engine;
  NavUpdate? navUpdate;
  University? activeUniversity;
  String lastGuidance = '';
  bool initialized = false;

  AppSettings get s => settings.settings;
  LatLng? get position => location.position.value;
  bool get hasLocation => position != null;

  Future<void> init() async {
    await settings.load();
    await tts.init(rate: s.speechRate, pitch: s.pitch);
    await tts.useBestArabicVoice();
    unawaited(FirebaseService.instance.init());
    connectivity.start();
    unawaited(sync.flush());
    initialized = true;
    notifyListeners();
  }

  // ── الصوت ────────────────────────────────────────────────
  Future<void> speak(String text, {bool interrupt = false, bool announce = true}) async {
    if (text.trim().isEmpty) return;
    lastGuidance = text;
    await tts.speak(text, interrupt: interrupt);
    if (announce) await A11yService.announce(text);
  }

  Future<void> repeatLast() async {
    if (lastGuidance.isEmpty) {
      await speak('لا يوجد إرشاد سابق. اضغط على التنقل للبدء.', interrupt: true);
      return;
    }
    await speak(lastGuidance, interrupt: true);
  }

  Future<void> setSpeechRate(double rate) async {
    await settings.patch(speechRate: rate);
    await tts.setRate(rate);
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    await settings.patch(pitch: pitch);
    await tts.setPitch(pitch);
    notifyListeners();
  }

  // ── التفضيلات ────────────────────────────────────────────
  Future<void> patchSettings({
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
  }) async {
    await settings.patch(
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
    );
    notifyListeners();
  }

  ThemeMode get themeMode => s.highContrast ? ThemeMode.dark : s.themeMode;

  // ── التنقل ───────────────────────────────────────────────
  Future<void> requestLocationAccess() async {
    final LocationAccess access = await location.ensureAccess();
    if (access == LocationAccess.granted) {
      await patchSettings(locationConsent: true);
      await location.start();
    }
    notifyListeners();
  }

  void startNavigation(SafeRoute route) {
    activeRoute = route;
    _engine = NavigationEngine(
      route: route,
      verbosity: s.verbosity.name,
    );
    final LatLng from = position ?? route.start;
    navUpdate = _engine!.initial(from);
    notifyListeners();
  }

  void stopNavigation() {
    activeRoute = null;
    _engine = null;
    navUpdate = null;
    notifyListeners();
  }

  /// يُستدعى مع كل تحديث موقع أثناء الملاحة.
  NavUpdate? onPositionUpdate(LatLng pos) {
    if (_engine == null) return null;
    final NavUpdate update = _engine!.update(pos);
    navUpdate = update;
    notifyListeners();
    return update;
  }

  /// هل يحتاج هذا التحديث نطقًا؟ (خطوة جديدة أو مستوى مسافة جديد)
  bool shouldAnnounce(NavUpdate update) => NavigationEngine.shouldAnnounce(update);

  // ── الإشارات ─────────────────────────────────────────────
  SignalSnapshot? nearestSignal({double radius = AppConfig.signalAlertRadiusMeters}) {
    final LatLng? p = position;
    if (p == null) return null;
    return signals.nearest(p.latitude, p.longitude, radiusMeters: radius);
  }

  // ── البلاغات ─────────────────────────────────────────────
  Future<Obstacle> reportObstacle({
    required ObstacleType type,
    String description = '',
    int severity = 2,
    LatLng? at,
  }) async {
    final LatLng pos = at ?? position ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng);
    final Obstacle obstacle = await obstacles.report(
      type: type,
      lat: pos.latitude,
      lng: pos.longitude,
      description: description,
      reporterId: user.id,
      severity: severity,
    );
    sync.refreshPending();
    unawaited(sync.flush());
    notifyListeners();
    return obstacle;
  }

  List<Obstacle> nearbyObstacles({double radius = 300}) {
    final LatLng? p = position;
    if (p == null) return obstacles.active();
    return obstacles.nearby(p.latitude, p.longitude, radiusMeters: radius);
  }

  // ── الجامعات ─────────────────────────────────────────────
  List<University> get universityList => universities.all();

  University? get currentUniversity {
    final String id = s.universityId;
    if (id.isNotEmpty) {
      final University? u = universities.byId(id);
      if (u != null) return u;
    }
    return universities.defaultUniversity;
  }

  Future<void> selectUniversity(String id) async {
    await patchSettings(universityId: id);
    activeUniversity = universities.byId(id);
    notifyListeners();
  }

  /// إرشاد إلى مبنى داخل الحرم: يمرّ بالبوابة الرئيسية إن أمكن.
  SafeRoute? routeToBuilding(University university, CampusBuilding building) {
    final LatLng? from = position;
    if (from == null) return null;
    final CampusBuilding? gate = university.mainGate;
    final LatLng? via = (gate != null && gate.id != building.id) ? gate.position : null;
    return SafeRouteFactory.between(
      from: from,
      to: building.position,
      via: via,
      name: 'الطريق إلى ${building.name}',
      city: university.city,
    );
  }

  // ── الأوامر الصوتية ──────────────────────────────────────

  String describeSurroundings() {
    final LatLng? p = position;
    if (p == null) return 'لا يوجد تحديد موقع بعد. فعّل الموقع من الإعدادات.';
    final StringBuffer sb = StringBuffer('أنت الآن عند ');
    sb.write('${p.latitude.toStringAsFixed(5)}، ${p.longitude.toStringAsFixed(5)}. ');
    final University? u = currentUniversity;
    if (u != null) {
      final CampusBuilding? nearest = u.nearestBuilding(p.latitude, p.longitude);
      if (nearest != null) {
        sb.write('أقرب مبنى في ${u.shortName.isEmpty ? u.name : u.shortName} هو ');
        sb.write('${nearest.name}. ');
      }
    }
    final SignalSnapshot? sig = nearestSignal(radius: 120);
    if (sig != null) {
      sb.write(sig.toSpeech());
      sb.write(' ');
    }
    final List<Obstacle> near = nearbyObstacles(radius: 60);
    if (near.isNotEmpty) {
      sb.write('يوجد ${near.length} عائق قريب: ${near.first.type.labelAr}.');
    } else {
      sb.write('لا توجد عوائق مسجّلة قريبة منك.');
    }
    return sb.toString();
  }

  String get statusLine {
    final String gps = hasLocation ? 'الموقع متاح' : 'لا يوجد موقع';
    final String net = connectivity.isOnline ? 'متصل' : 'أوفلاين';
    final int pend = sync.pendingCount;
    return '$net · $gps${pend > 0 ? ' · $pend بلاغ معلّق' : ''}';
  }

  double distanceTo(LatLng target) {
    final LatLng? p = position;
    if (p == null) return -1;
    return Geo.distanceMeters(p.latitude, p.longitude, target.latitude, target.longitude);
  }

  @override
  void dispose() {
    connectivity.dispose();
    location.dispose();
    stt.dispose();
    super.dispose();
  }
}
