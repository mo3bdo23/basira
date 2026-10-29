import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/geo.dart';
import '../models/obstacle.dart';
import '../models/safe_route.dart';
import '../services/navigation_engine.dart';
import '../services/traffic_signal_service.dart';
import '../services/voice_command_router.dart';
import '../state/app_state.dart';
import '../widgets/route_map.dart';
import '../widgets/sos_button.dart';

/// شاشة التنقل: إرشاد صوتي لحظي + إشارات + تنبيه عوائق + SOS.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  static const String route = '/navigation';

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  NavUpdate? _update;
  final Set<String> _announcedSignals = <String>{};
  final Set<String> _announcedObstacles = <String>{};
  bool _arrivalShown = false;
  bool _listening = false;
  String _lastSpoken = '';
  late final AppState _state;

  AppState get _app => _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state.location.position.addListener(_onPositionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    final AppState app = _app;
    final SafeRoute? route = app.activeRoute;
    if (route == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    final LatLng from = app.position ?? route.start;
    final NavUpdate? update = app.navUpdate ?? app.onPositionUpdate(from);
    if (update != null && mounted) {
      setState(() => _update = update);
    }
    await app.speak(
      'أنت على مسار ${route.name}. ${update?.instruction ?? 'ابدأ السير.'}',
      interrupt: true,
    );
  }

  void _onPositionChanged() {
    final AppState app = _app;
    final LatLng? pos = app.location.position.value;
    if (pos == null || app.activeRoute == null) return;
    final NavUpdate? update = app.onPositionUpdate(pos);
    if (update == null || !mounted) return;

    setState(() => _update = update);

    if (update.phase == NavPhase.arrived) {
      _handleArrival();
      return;
    }

    if (NavigationEngine.shouldAnnounce(update) && update.instruction != _lastSpoken) {
      _lastSpoken = update.instruction;
      app.speak(update.instruction, interrupt: true);
    }

    _checkSignals(pos);
    _checkObstacles(pos);
  }

  void _checkSignals(LatLng pos) {
    final SignalSnapshot? snapshot = _app.nearestSignal();
    if (snapshot == null) return;
    if (_announcedSignals.contains(snapshot.signal.id)) return;
    _announcedSignals.add(snapshot.signal.id);
    _app.speak(snapshot.toSpeech(), interrupt: false);
  }

  void _checkObstacles(LatLng pos) {
    final List<Obstacle> near = _app.nearbyObstacles(radius: AppConfig.obstacleAlertRadiusMeters);
    for (final Obstacle o in near) {
      if (_announcedObstacles.contains(o.id)) continue;
      _announcedObstacles.add(o.id);
      final double d = Geo.distanceMeters(pos.latitude, pos.longitude, o.lat, o.lng);
      _app.speak(
        'انتبه. ${o.type.labelAr} على بعد ${Geo.spokenDistance(d)}.',
        interrupt: false,
      );
    }
  }

  Future<void> _handleArrival() async {
    if (_arrivalShown) return;
    _arrivalShown = true;
    final AppState app = _app;
    app.speak('وصلت إلى وجهتك. ${app.activeRoute?.name ?? ''}.', interrupt: true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.flag_circle_rounded, size: 56, color: Colors.green),
        title: const Text('وصلت بسلام'),
        content: Text(
          'وصلت إلى ${app.activeRoute?.name ?? 'وجهتك'}. يمكنك إنهاء التنقل أو العودة للشاشة الرئيسية.',
          style: const TextStyle(fontSize: 19),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _endNavigation();
            },
            child: const Text('إنهاء التنقل'),
          ),
        ],
      ),
    );
  }

  Future<void> _endNavigation() async {
    _app.stopNavigation();
    _app.location.stopSimulation();
    await _app.speak('تم إنهاء التنقل.', interrupt: true);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _repeat() async {
    final String text = _update?.instruction ?? _app.lastGuidance;
    await _app.speak(text.isEmpty ? 'لا يوجد إرشاد حالي.' : text, interrupt: true);
  }

  Future<void> _whereAmI() async {
    await _app.speak(_app.describeSurroundings(), interrupt: true);
  }

  Future<void> _startListening() async {
    if (_listening) {
      await _app.stt.stop();
      return;
    }
    setState(() => _listening = true);
    await _app.speak('أنا أسمعك.', interrupt: true);
    await _app.stt.listen(
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      onResult: (String words) async {
        setState(() => _listening = false);
        final VoiceCommand cmd = VoiceCommandRouter.parse(words);
        switch (cmd.intent) {
          case VoiceIntent.stopNavigation:
            await _endNavigation();
          case VoiceIntent.repeat:
            await _repeat();
          case VoiceIntent.whereAmI:
            await _whereAmI();
          case VoiceIntent.faster:
            await _app.setSpeechRate((_app.s.speechRate + 0.1).clamp(0.2, 1.0));
            await _app.speak('أسرع.');
          case VoiceIntent.slower:
            await _app.setSpeechRate((_app.s.speechRate - 0.1).clamp(0.2, 1.0));
            await _app.speak('أبطأ.');
          case VoiceIntent.sos:
            await _app.speak('اضغط زر الاستغاثة الأحمر أسفل الشاشة.', interrupt: true);
          case VoiceIntent.help:
            await _app.speak('يمكنك قول: توقف، كرر، أين أنا، أسرع، أبطأ.', interrupt: true);
          default:
            await _app.speak('لم أفهم. قل توقف أو كرر أو أين أنا.', interrupt: true);
        }
      },
    );
    if (mounted) setState(() => _listening = false);
  }

  void _startSimulation() {
    final SafeRoute? route = _app.activeRoute;
    if (route == null) return;
    _app.location.simulateWalk(route.points);
    _app.speak('بدأ وضع المحاكاة. سأمشي على المسار تلقائيًا لعرض الإرشاد.', interrupt: true);
  }

  @override
  void dispose() {
    _app.location.position.removeListener(_onPositionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final SafeRoute? route = app.activeRoute;
    final NavUpdate? update = _update ?? app.navUpdate;

    if (route == null) {
      return const Scaffold(body: Center(child: Text('لا يوجد تنقل نشط.')));
    }

    final String instruction = update?.instruction ?? 'جارٍ تحديد موقعك…';
    final double remaining = update?.remainingMeters ?? route.lengthMeters;
    final int eta = (remaining / AppConfig.walkingSpeedMps / 60).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإرشاد الصوتي'),
        actions: <Widget>[
          Semantics(
            button: true,
            label: 'محاكاة التنقل',
            child: IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 30),
              tooltip: 'محاكاة',
              onPressed: _startSimulation,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // بطاقة الإرشاد.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: <Color>[scheme.primary, scheme.primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      instruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        _MiniStat(
                          icon: Icons.straighten,
                          value: Geo.shortDistance(remaining),
                          label: 'المتبقي',
                        ),
                        const SizedBox(width: 14),
                        _MiniStat(
                          icon: Icons.timer_outlined,
                          value: '$eta د',
                          label: 'الزمن',
                        ),
                        const SizedBox(width: 14),
                        _MiniStat(
                          icon: Icons.percent,
                          value: '${((update?.progress ?? 0) * 100).round()}%',
                          label: 'التقدم',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: update?.progress ?? 0,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (update?.phase == NavPhase.offRoute)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.wrong_location_rounded, color: scheme.onErrorContainer, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'أنت خارج المسار بـ ${Geo.shortDistance(update?.offRouteDistance ?? 0)}. اتجه للعودة.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              RouteMap(route: route.points, position: app.position, height: 230),
              const SizedBox(height: 8),
              Text(
                '${route.name} · ${route.safetyLabelAr}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),

              // أزرار التحكم.
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.replay_rounded,
                      label: 'كرر',
                      onTap: _repeat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.my_location_rounded,
                      label: 'أين أنا',
                      onTap: _whereAmI,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ControlButton(
                      icon: _listening ? Icons.mic : Icons.mic_none_rounded,
                      label: _listening ? 'يستمع' : 'أمر صوتي',
                      onTap: _startListening,
                      highlight: _listening,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (!app.hasLocation)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.location_off, color: scheme.onSecondaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'لا يوجد GPS. شغّل المحاكاة لتجربة الإرشاد.',
                          style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 17),
                        ),
                      ),
                      TextButton(onPressed: _startSimulation, child: const Text('محاكاة')),
                    ],
                  ),
                ),

              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _endNavigation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error, width: 2.5),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('إنهاء التنقل'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SosButton(
                    size: 76,
                    onTap: () async {
                      await _app.speak('جارٍ فتح شاشة الاستغاثة.', interrupt: true);
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamed('/sos');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: highlight ? scheme.primary : scheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 30, color: highlight ? scheme.onPrimary : scheme.onSurface),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: highlight ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
