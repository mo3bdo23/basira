import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/home_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/report_obstacle_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sos_active_screen.dart';
import 'screens/sos_contacts_screen.dart';
import 'screens/university_map_screen.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await StorageService.instance.init();
    final AppState state = AppState();
    await state.init();
    runApp(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const BasiraApp(),
    ));
  } catch (e, st) {
    debugPrint('Fatal init error: $e\n$st');
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

class BasiraApp extends StatelessWidget {
  const BasiraApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final bool contrast = app.s.highContrast;

    return MaterialApp(
      title: 'بصيرة — Basira',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const <Locale>[Locale('ar', 'EG'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: BasiraTheme.light(),
      darkTheme: contrast ? BasiraTheme.highContrast() : BasiraTheme.dark(),
      themeMode: contrast ? ThemeMode.dark : app.s.themeMode,
      builder: (BuildContext context, Widget? child) {
        // لا نسمح بتصغير الخطوط تحت 90% (إتاحة)، ونحدّ التكبير عند 160%.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.6,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
      routes: <String, WidgetBuilder>{
        HomeScreen.route: (_) => const HomeScreen(),
        OnboardingScreen.route: (_) => const OnboardingScreen(),
        DisclaimerScreen.route: (_) => const DisclaimerScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
        SosContactsScreen.route: (_) => const SosContactsScreen(),
        SosActiveScreen.route: (_) => const SosActiveScreen(),
        NavigationScreen.route: (_) => const NavigationScreen(),
        ReportObstacleScreen.route: (_) => const ReportObstacleScreen(),
        UniversityMapScreen.route: (_) => const UniversityMapScreen(),
      },
    );
  }
}

/// شاشة إقلاع: تُعلن اسم التطبيق، ثم توجّه حسب اكتمال الإخلاء والتدريب.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final AppState app = context.read<AppState>();
    await app.speak('بصيرة. طريقك الآمن بصوتك.', interrupt: true);

    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final Widget next;
    if (!app.s.disclaimerAccepted) {
      next = const DisclaimerScreen();
    } else if (!app.s.onboardingDone) {
      next = const OnboardingScreen();
    } else {
      next = const HomeScreen();
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Semantics(
        label: 'بصيرة. تطبيق التنقل الصوتي لذوي الإعاقة البصرية. جارٍ التحميل.',
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[scheme.primary, scheme.primary.withValues(alpha: 0.75)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.4), width: 3),
                  ),
                  child: Icon(Icons.visibility_rounded, size: 88, color: scheme.onPrimary),
                ),
                const SizedBox(height: 28),
                Text(
                  'بصيرة',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'طريقك الآمن.. بصوتك',
                  style: TextStyle(fontSize: 22, color: scheme.onPrimary.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: scheme.onPrimary.withValues(alpha: 0.85),
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

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 72, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('تعذّر تشغيل التطبيق', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
