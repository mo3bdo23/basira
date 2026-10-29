import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/a11y_service.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// الشاشة الثانية: إخلاء المسؤولية — شرط أساسي للاستخدام.
class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  static const String route = '/disclaimer';

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _accepted = false;

  static const List<(String, String)> _sections = <(String, String)>[
    (
      'طبيعة التطبيق',
      '«بصيرة» أداة مساعدة صوتية للتنقل، وليست بديلًا عن العصا البيضاء أو الكلب المرشد '
          'أو مرافقة شخص آخر. استخدمها مع وسائل التنقل المعتادة لديك.',
    ),
    (
      'دقة تحديد الموقع',
      'يعتمد التطبيق على نظام GPS الذي قد يخطئ من 5 إلى 30 مترًا، وتزيد الأخطاء داخل '
          'المباني والأنفاق والممرات المسقوفة. لا تعتمد على الموقع وحده عند عبور الطرق.',
    ),
    (
      'المسارات والإشارات',
      'المسارات الآمنة وأماكن إشارات المرور بيانات إرشادية قد تتغير بسبب أعمال الطرق أو '
          'العوائق الطارئة. تحقّق دائمًا من محيطك قبل التحرك.',
    ),
    (
      'الطوارئ',
      'زر SOS يفتح تطبيق الرسائل والهاتف لإرسال موقعك لجهات اتصالك الطارئة، ولا يضمن '
          'وصول الرسالة إن لم تتوفر شبكة اتصال. في الخطر المباشر اتصل بالنجدة 122.',
    ),
    (
      'الخصوصية',
      'موقعك يُستخدم أثناء استخدامك للتطبيق فقط، ويُخزَّن مشفّرًا على جهازك. لا نشارك '
          'موقعك مع أي طرف ثالث دون موافقتك الصريحة، ويمكنك حذف بياناتك في أي وقت.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().speak(
            'قبل البدء، إخلاء مسؤولية. بصيرة أداة مساعدة وليست بديلًا عن العصا البيضاء. '
            'التطبيق لا يضمن دقة الموقع دائمًا. يمكنك الاستماع للنص كاملًا ثم الموافقة.',
            interrupt: true,
          );
    });
  }

  Future<void> _readAll() async {
    final AppState app = context.read<AppState>();
    final StringBuffer sb = StringBuffer('نص إخلاء المسؤولية. ');
    for (final (String title, String body) in _sections) {
      sb.write('$title. $body ');
    }
    sb.write('للموافقة، اضغط زر أوافق. للخروج اضغط لا أوافق.');
    await app.speak(sb.toString(), interrupt: true);
  }

  Future<void> _accept() async {
    if (_accepted) return;
    setState(() => _accepted = true);
    final AppState app = context.read<AppState>();
    await app.patchSettings(disclaimerAccepted: true);
    await A11yService.haptic('success', enabled: app.s.haptics);
    if (!mounted) return;
    final Widget next = app.s.onboardingDone ? const HomeScreen() : const OnboardingScreen();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إخلاء المسؤولية'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: <Widget>[
                  Icon(Icons.shield_outlined, size: 64, color: scheme.primary),
                  const SizedBox(height: 10),
                  Text(
                    'قبل أن تبدأ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'يرجى قراءة هذه النقاط والموافقة عليها لاستخدام التطبيق.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface.withOpacity(0.75)),
                  ),
                  const SizedBox(height: 14),
                  for (final (String title, String body) in _sections)
                    Card(
                      elevation: 0,
                      color: scheme.surfaceContainerHighest.withOpacity(0.35),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(title,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(body, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _readAll,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('استمع إلى النص كاملًا'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _accept,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(_accepted ? 'جارٍ البدء…' : 'أوافق على الإخلاء وأبدأ'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => SystemNavigator.pop(),
                    child: Text(
                      'لا أوافق — إغلاق التطبيق',
                      style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
