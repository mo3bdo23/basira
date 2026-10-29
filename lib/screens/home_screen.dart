import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/geo.dart';
import '../models/safe_route.dart';
import '../services/voice_command_router.dart';
import '../state/app_state.dart';
import '../widgets/big_action_button.dart';
import '../widgets/sos_button.dart';
import '../widgets/status_pill.dart';
import '../widgets/voice_orb.dart';
import 'navigation_screen.dart';
import 'report_obstacle_screen.dart';
import 'settings_screen.dart';
import 'sos_active_screen.dart';
import 'sos_contacts_screen.dart';
import 'university_map_screen.dart';

/// الشاشة الرئيسية: ثلاثة أزرار كبيرة + كرة الصوت + زر الاستغاثة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _welcomed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  Future<void> _welcome() async {
    if (_welcomed || !mounted) return;
    _welcomed = true;
    final AppState app = context.read<AppState>();
    final String name = app.s.userName.trim();
    await app.speak(
      '${name.isEmpty ? 'أهلًا بك' : 'أهلًا $name'}. أنت في الشاشة الرئيسية. '
      'ثلاثة أزرار: التنقل، الإبلاغ عن عائق، خريطة الجامعة. '
      'وللأوامر الصوتية اضغط على كرة الصوت، أو اضغط ضغطًا مطولًا في أي مكان وأثناء التنقل.',
      interrupt: true,
    );
  }

  Future<void> _open(Widget screen) async {
    await context.read<AppState>().stt.stop();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (!mounted) return;
    // إعادة قراءة الحالة عند العودة.
    setState(() {});
  }

  Future<void> _startVoice() async {
    final AppState app = context.read<AppState>();
    if (app.stt.listening.value) {
      await app.stt.stop();
      return;
    }
    await app.speak('أنا أسمعك. قل أمرك.', interrupt: true);
    final bool ok = await app.stt.listen(
      listenFor: const Duration(seconds: 9),
      pauseFor: const Duration(seconds: 2),
      onResult: _onWords,
    );
    if (!mounted) return;
    if (!ok) {
      await app.speak(
        'الميكروفون غير متاح. يمكنك استخدام الأزرار، أو فعّل إذن الميكروفون من إعدادات الجهاز.',
        interrupt: true,
      );
    }
  }

  Future<void> _onWords(String words) async {
    final AppState app = context.read<AppState>();
    final VoiceCommand cmd = VoiceCommandRouter.parse(words);
    switch (cmd.intent) {
      case VoiceIntent.navigate:
        await _pickRoute();
      case VoiceIntent.reportObstacle:
        await _open(const ReportObstacleScreen());
      case VoiceIntent.sos:
        await _open(const SosActiveScreen());
      case VoiceIntent.openUniversity:
        await _open(const UniversityMapScreen());
      case VoiceIntent.openSettings:
        await _open(const SettingsScreen());
      case VoiceIntent.whereAmI:
        await app.speak(app.describeSurroundings(), interrupt: true);
      case VoiceIntent.repeat:
        await app.repeatLast();
      case VoiceIntent.stopNavigation:
        await app.speak('لا يوجد تنقل جارٍ الآن.', interrupt: true);
      case VoiceIntent.trafficStatus:
        final snapshot = app.nearestSignal(radius: 150);
        await app.speak(
          snapshot?.toSpeech() ?? 'لا توجد إشارة مرور مسجلة قريبة منك.',
          interrupt: true,
        );
      case VoiceIntent.faster:
        await app.setSpeechRate((app.s.speechRate + 0.1).clamp(0.2, 1.0));
        await app.speak('سرعة النطق أصبحت ${(app.s.speechRate * 100).round()} بالمئة.');
      case VoiceIntent.slower:
        await app.setSpeechRate((app.s.speechRate - 0.1).clamp(0.2, 1.0));
        await app.speak('سرعة النطق أصبحت ${(app.s.speechRate * 100).round()} بالمئة.');
      case VoiceIntent.help:
        await app.speak(
          'الأوامر المتاحة: ${VoiceCommandRouter.helpPhrases.join('، ')}.',
          interrupt: true,
        );
      case VoiceIntent.goHome:
        await app.speak('أنت في الشاشة الرئيسية.', interrupt: true);
      case VoiceIntent.unknown:
        await app.speak(
          'لم أفهم الأمر. جرّب: ابدأ التنقل، أو أين أنا، أو بلّغ عن عائق.',
          interrupt: true,
        );
    }
  }

  Future<void> _pickRoute() async {
    final AppState app = context.read<AppState>();
    final List<SafeRoute> list = app.routes.nearest(
      app.position ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
    );

    if (list.isEmpty) {
      await app.speak('لا توجد مسارات محفوظة بعد. يمكنك التنقل من خريطة الجامعة.', interrupt: true);
      return;
    }

    await app.speak('اختر أحد المسارات الآمنة. عندك ${list.length} مسارات.', interrupt: true);
    if (!mounted) return;

    final SafeRoute? chosen = await showModalBottomSheet<SafeRoute>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Semantics(
          label: 'قائمة المسارات الآمنة',
          child: SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int i) {
                final SafeRoute r = list[i];
                final double d = app.position == null
                    ? -1
                    : Geo.distanceMeters(
                        app.position!.latitude,
                        app.position!.longitude,
                        r.start.latitude,
                        r.start.longitude,
                      );
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  leading: const Icon(Icons.route_rounded, size: 34),
                  title: Text(r.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${Geo.shortDistance(r.lengthMeters)} · ${r.safetyLabelAr}'
                    '${d >= 0 ? ' · يبعد عنك ${Geo.shortDistance(d)}' : ''}',
                    style: const TextStyle(fontSize: 17),
                  ),
                  onTap: () => Navigator.of(context).pop(r),
                );
              },
            ),
          ),
        );
      },
    );

    if (chosen == null || !mounted) return;
    await _startRoute(chosen);
  }

  Future<void> _startRoute(SafeRoute route) async {
    final AppState app = context.read<AppState>();
    final double? startDistance = app.position == null
        ? null
        : Geo.distanceMeters(
            app.position!.latitude,
            app.position!.longitude,
            route.start.latitude,
            route.start.longitude,
          );

    SafeRoute toUse = route;
    if (startDistance != null && startDistance > 300) {
      // المستخدم بعيد عن بداية المسار: نرشده أولًا إليها.
      toUse = RouteFactory.between(
        from: app.position!,
        to: route.start,
        name: 'الوصول إلى بداية ${route.name}',
        city: route.city,
      );
    }

    app.startNavigation(toUse);
    await app.speak(
      'بدأ التنقل إلى ${toUse.name}. ${toUse.summaryAr}. سأرشدك خطوة بخطوة.',
      interrupt: true,
    );
    if (!mounted) return;
    await _open(const NavigationScreen());
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String name = app.s.userName.trim();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await app.connectivity.check();
            await app.sync.flush();
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name.isEmpty ? 'مرحبًا بك' : 'مرحبًا، $name',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.statusLine,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'الإعدادات',
                    child: IconButton(
                      iconSize: 34,
                      tooltip: 'الإعدادات',
                      onPressed: () => _open(const SettingsScreen()),
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: app.connectivity.online,
                builder: (BuildContext context, bool online, _) {
                  return StatusPill(
                    online: online,
                    gps: app.hasLocation,
                    pending: app.sync.pendingCount,
                    simulated: app.location.simulating.value,
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: app.stt.listening,
                  builder: (BuildContext context, bool listening, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: app.tts.speaking,
                      builder: (BuildContext context, bool speaking, _) {
                        return VoiceOrb(
                          listening: listening,
                          speaking: speaking,
                          onTap: _startVoice,
                          label: listening
                              ? 'يستمع الآن — قل أمرك'
                              : 'الأوامر الصوتية — اضغط للتحدث',
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'قل: «ابدأ التنقل» أو «أين أنا»',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              BigActionButton(
                icon: Icons.navigation_rounded,
                label: 'ابدأ التنقل',
                hint: 'مسارات آمنة موثّقة مع إرشاد صوتي خطوة بخطوة',
                emphasize: true,
                onTap: _pickRoute,
              ),
              const SizedBox(height: 14),
              BigActionButton(
                icon: Icons.report_problem_rounded,
                label: 'بلّغ عن عائق',
                hint: 'سلالم، حفر، أو رصيف مسدود — بلاغك يحمي غيرك',
                onTap: () => _open(const ReportObstacleScreen()),
              ),
              const SizedBox(height: 14),
              BigActionButton(
                icon: Icons.account_balance_rounded,
                label: 'خريطة الجامعة',
                hint: 'خرائط صوتية للمباني والبوابات داخل الحرم الجامعي',
                onTap: () => _open(const UniversityMapScreen()),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.error.withOpacity(0.35)),
                ),
                child: Row(
                  children: <Widget>[
                    SosButton(
                      onTap: () => _open(const SosActiveScreen()),
                      onLongPress: () => _open(const SosActiveScreen()),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('في خطر؟',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            'اضغط زر الاستغاثة ليُرسل موقعك لجهات اتصالك الطارئة.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => _open(const SosContactsScreen()),
                            child: const Text('إدارة جهات اتصال SOS'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final AppState app = context.read<AppState>();
                        await app.speak(app.describeSurroundings(), interrupt: true);
                      },
                      icon: const Icon(Icons.my_location_rounded, size: 26),
                      label: const Text('أين أنا؟'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final AppState app = context.read<AppState>();
                        final List<String> near = app
                            .nearbyObstacles(radius: AppConfig.obstacleAlertRadiusMeters * 3)
                            .map((o) => o.type.labelAr)
                            .toSet()
                            .toList();
                        await app.speak(
                          near.isEmpty
                              ? 'لا توجد عوائق مجتمعية مسجلة قريبة منك.'
                              : 'يوجد قريب منك: ${near.join('، ')}.',
                          interrupt: true,
                        );
                      },
                      icon: const Icon(Icons.warning_amber_rounded, size: 26),
                      label: const Text('العوائق القريبة'),
                    ),
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
