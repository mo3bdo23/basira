import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/geo.dart';
import '../models/safe_route.dart';
import '../services/navigation_engine.dart';
import '../services/voice_command_router.dart';
import '../state/app_state.dart';
import '../widgets/sos_button.dart';
import '../widgets/voice_orb.dart';
import 'navigation_screen.dart';
import 'report_obstacle_screen.dart';
import 'settings_screen.dart';
import 'sos_active_screen.dart';
import 'sos_contacts_screen.dart';
import 'university_map_screen.dart';
import 'where_am_i_screen.dart';

/// الشاشة الرئيسية المبسّطة: إجراء واحد أساسي «ابدأ المشي»، وثلاثة أزرار ثانوية.
/// كل عنصر له تسمية صوتية وتلميح، والأزرار كبيرة جدًا.
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
    await app.speak(
      'أهلًا بك في بصيرة. اضغط الزر الكبير للبدء. '
      'أو قل: ابدأ المشي. وفي أي وقت، زر الاستغاثة الأحمر في الأسفل.',
      interrupt: true,
    );
  }

  Future<void> _open(Widget screen) async {
    await context.read<AppState>().stt.stop();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  // ── الصوت ────────────────────────────────────────────────

  Future<void> _startVoice() async {
    final AppState app = context.read<AppState>();
    if (app.stt.listening.value) {
      await app.stt.stop();
      return;
    }
    await app.speak('أنا أسمعك.', interrupt: true);
    final bool ok = await app.stt.listen(
      listenFor: const Duration(seconds: 9),
      pauseFor: const Duration(seconds: 2),
      onResult: _onWords,
    );
    if (!ok && mounted) {
      await app.speak(
        'الميكروفون غير متاح. استخدم الأزرار، أو فعّل إذن الميكروفون من إعدادات الجهاز.',
        interrupt: true,
      );
    }
  }

  Future<void> _onWords(String words) async {
    final AppState app = context.read<AppState>();
    final VoiceCommand cmd = VoiceCommandRouter.parse(words);
    switch (cmd.intent) {
      case VoiceIntent.navigate:
        await _chooseDestination();
      case VoiceIntent.reportObstacle:
        await _open(const ReportObstacleScreen());
      case VoiceIntent.sos:
        await _open(const SosActiveScreen());
      case VoiceIntent.openUniversity:
        await _open(const UniversityMapScreen());
      case VoiceIntent.openSettings:
        await _open(const SettingsScreen());
      case VoiceIntent.whereAmI:
        await _open(const WhereAmIScreen());
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
        await app.speak('أسرع.');
      case VoiceIntent.slower:
        await app.setSpeechRate((app.s.speechRate - 0.1).clamp(0.2, 1.0));
        await app.speak('أبطأ.');
      case VoiceIntent.help:
        await app.speak(
          'يمكنك قول: ابدأ المشي، أين أنا، بلّغ عن عائق، طوارئ، توقف.',
          interrupt: true,
        );
      case VoiceIntent.goHome:
        await app.speak('أنت في الشاشة الرئيسية.', interrupt: true);
      case VoiceIntent.unknown:
        await app.speak(
          'لم أفهم. قل: ابدأ المشي، أو أين أنا.',
          interrupt: true,
        );
    }
  }

  // ── التنقل ───────────────────────────────────────────────

  /// «ابدأ المشي»: إن وُجد مسار قريب بدأ فورًا، وإلا نعرض القائمة.
  Future<void> _chooseDestination() async {
    final AppState app = context.read<AppState>();
    final LatLng from = app.position ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng);
    final List<SafeRoute> routes = app.routes.nearest(from);

    if (routes.isEmpty) {
      await app.speak(
        'لا يوجد مسار محفوظ قريب. يمكنك فتح خريطة الجامعة لاختيار مبنى.',
        interrupt: true,
      );
      return;
    }

    final SafeRoute first = routes.first;
    final double distanceToStart = app.position == null
        ? double.infinity
        : Geo.distanceMeters(
            app.position!.latitude,
            app.position!.longitude,
            first.start.latitude,
            first.start.longitude,
          );

    // مسار قريب جدًا: ابدأ فورًا بلا قوائم.
    if (distanceToStart < 120) {
      await _startRoute(first);
      return;
    }

    await _showRoutePicker(app, routes);
  }

  Future<void> _showRoutePicker(AppState app, List<SafeRoute> routes) async {
    await app.speak(
      'اختر مسارًا. اضغط على أول زر، أو اسمع التفاصيل ثم اختر.',
      interrupt: true,
    );
    if (!mounted) return;

    final SafeRoute? chosen = await showModalBottomSheet<SafeRoute>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int i) {
            final SafeRoute r = routes[i];
            final double d = app.position == null
                ? -1
                : Geo.distanceMeters(
                    app.position!.latitude, app.position!.longitude, r.start.latitude, r.start.longitude);
            return ListTile(
              minVerticalPadding: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              leading: const Icon(Icons.route_rounded, size: 34),
              title: Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${Geo.shortDistance(r.lengthMeters)} · ${r.safetyLabelAr}'
                '${d >= 0 ? ' · يبعد ${Geo.shortDistance(d)}' : ''}',
                style: const TextStyle(fontSize: 16),
              ),
              onTap: () => Navigator.of(context).pop(r),
            );
          },
        ),
      ),
    );

    if (chosen != null && mounted) await _startRoute(chosen);
  }

  Future<void> _startRoute(SafeRoute route) async {
    final AppState app = context.read<AppState>();
    final double? startDistance = app.position == null
        ? null
        : Geo.distanceMeters(
            app.position!.latitude, app.position!.longitude, route.start.latitude, route.start.longitude);

    SafeRoute toUse = route;
    if (startDistance != null && startDistance > 300) {
      toUse = SafeRouteFactory.between(
        from: app.position!,
        to: route.start,
        name: 'الوصول إلى بداية ${route.name}',
        city: route.city,
      );
    }

    app.startNavigation(toUse);
    await app.speak('بدأت. سأرشدك خطوة بخطوة.', interrupt: true);
    if (!mounted) return;
    await _open(const NavigationScreen());
  }

  Future<void> _speakStatus() async {
    final AppState app = context.read<AppState>();
    await app.speak(
      '${app.hasLocation ? 'الموقع يعمل. ' : 'لا يوجد موقع. '}'
      '${app.connectivity.isOnline ? 'متصل بالإنترنت.' : 'يعمل بدون إنترنت.'} '
      '${app.sync.pendingCount > 0 ? 'يوجد ${app.sync.pendingCount} بلاغ بانتظار الإرسال.' : ''}',
      interrupt: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String name = app.s.userName.trim();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: <Widget>[
            // ── رأس بسيط ─────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    name.isEmpty ? 'بصيرة' : 'أهلًا $name',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'الإعدادات',
                  child: IconButton(
                    iconSize: 32,
                    tooltip: 'الإعدادات',
                    onPressed: () => _open(const SettingsScreen()),
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Semantics(
              button: true,
              label: 'حالة التطبيق',
              hint: 'اضغط مرتين للاستماع إلى حالة الموقع والاتصال',
              child: InkWell(
                onTap: _speakStatus,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          app.statusLine,
                          style: TextStyle(
                            fontSize: 15,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── الكرة الصوتية ────────────────────────────
            Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: app.stt.listening,
                builder: (BuildContext context, bool listening, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: app.tts.speaking,
                    builder: (BuildContext context, bool speaking, _) {
                      return VoiceOrb(
                        size: 108,
                        listening: listening,
                        speaking: speaking,
                        onTap: _startVoice,
                        label: listening
                            ? 'يستمع الآن — قل أمرك'
                            : 'تحدّث إلى بصيرة — اضغط للتحدث',
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'قل: «ابدأ المشي» أو «أين أنا»',
                style: TextStyle(
                  fontSize: 16,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── الإجراء الأساسي: زر واحد كبير ───────────
            Semantics(
              button: true,
              label: 'ابدأ المشي',
              hint: 'أكبر زر في الشاشة — يبدأ الإرشاد الصوتي فورًا',
              child: Material(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: _chooseDestination,
                  child: Container(
                    height: 132,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.directions_walk_rounded, size: 52, color: scheme.onPrimary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'ابدأ المشي',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'إرشاد صوتي خطوة بخطوة',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: scheme.onPrimary.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── أزرار ثانوية كبيرة ──────────────────────
            _BigTile(
              icon: Icons.place_rounded,
              title: 'أين أنا؟',
              subtitle: 'وصف موقعك ومحيطك',
              onTap: () => _open(const WhereAmIScreen()),
            ),
            const SizedBox(height: 12),
            _BigTile(
              icon: Icons.report_problem_rounded,
              title: 'بلّغ عن عائق',
              subtitle: 'حفرة أو سلالم أو رصيف مسدود',
              onTap: () => _open(const ReportObstacleScreen()),
            ),
            const SizedBox(height: 14),

            // ── الاستغاثة: أوضح عنصر ─────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.error.withValues(alpha: 0.45), width: 2),
              ),
              child: Row(
                children: <Widget>[
                  SosButton(
                    size: 92,
                    onTap: () => _open(const SosActiveScreen()),
                    onLongPress: () => _open(const SosActiveScreen()),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('استغاثة',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('يرسل موقعك لمن تثق به', style: theme.textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => _open(const SosContactsScreen()),
                          child: const Text('جهات الاتصال'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── المزيد (ثانوي) ──────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _open(const UniversityMapScreen()),
                    icon: const Icon(Icons.account_balance_rounded, size: 22),
                    label: const Text('خرائط الجامعات'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _open(const SettingsScreen()),
                    icon: const Icon(Icons.tune_rounded, size: 22),
                    label: const Text('الإعدادات'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة إجراء كبيرة موحّدة.
class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 30, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title,
                          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 16, color: scheme.onSurface.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, size: 28, color: scheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
