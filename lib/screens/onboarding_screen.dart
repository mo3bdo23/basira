import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/a11y_service.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'sos_contacts_screen.dart';

class _OnboardPage {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.speech,
  });

  final IconData icon;
  final String title;
  final String body;
  final String speech;
}

/// التدريب الصوتي الأولي: أربع خطوات تُقرأ تلقائيًا، مع طلب الأذونات.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String route = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _micAsked = false;
  bool _locationAsked = false;

  static const List<_OnboardPage> _pages = <_OnboardPage>[
    _OnboardPage(
      icon: Icons.visibility_rounded,
      title: 'أهلًا بك في بصيرة',
      body: 'تطبيق يتحدث معك ويسمعك، ليمنحك طريقًا آمنًا في الشارع والجامعة.\n'
          'كل شيء هنا يعمل بالصوت، ويمكنك استخدامه بدون إنترنت.',
      speech: 'أهلًا بك في بصيرة. تطبيق يتحدث معك ويسمعك ليمنحك طريقًا آمنًا. '
          'كل شيء يعمل بالصوت، ويمكن استخدامه بدون إنترنت. '
          'اسحب لليسار أو اضغط زر التالي للاستمرار.',
    ),
    _OnboardPage(
      icon: Icons.mic_rounded,
      title: 'دع التطبيق يسمعك',
      body: 'قل أوامرك مثل: «ابدأ التنقل»، «أين أنا»، «بلّغ عن عائق»، «توقف».\n'
          'اسمح بالوصول إلى الميكروفون حتى نستمع لأوامرك.',
      speech: 'الخطوة الثانية: الأوامر الصوتية. قل ابدأ التنقل، أين أنا، بلغ عن عائق، توقف. '
          'اسمح بالوصول إلى الميكروفون من الزر الموجود.',
    ),
    _OnboardPage(
      icon: Icons.my_location_rounded,
      title: 'حدد موقعك',
      body: 'نستخدم موقعك لرسم مسارك الآمن، وتنبيهك بالإشارات والعوائق القريبة، '
          'وإرساله لجهة اتصالك عند الطوارئ.',
      speech: 'الخطوة الثالثة: الموقع. نستخدم موقعك لرسم مسارك الآمن وتنبيهك بالإشارات والعوائق. '
          'موقعك لا يُشارك مع أي طرف ثالث دون موافقتك.',
    ),
    _OnboardPage(
      icon: Icons.emergency_share_rounded,
      title: 'جهة اتصال للطوارئ',
      body: 'أضف شخصًا تثق به. عند الضغط على زر SOS يُرسل التطبيق موقعك له برسالة، '
          'ويمكنه الاتصال بك مباشرة.',
      speech: 'الخطوة الرابعة: جهة اتصال للطوارئ. أضف شخصًا تثق به ليصله موقعك عند الضغط على زر الاستغاثة. '
          'يمكنك تخطي هذه الخطوة الآن وإضافتها لاحقًا من الإعدادات.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  Future<void> _speakCurrent() async {
    if (!mounted) return;
    await context.read<AppState>().speak(_pages[_index].speech, interrupt: true);
  }

  Future<void> _finish() async {
    final AppState app = context.read<AppState>();
    await app.patchSettings(onboardingDone: true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
  }

  Future<void> _next() async {
    if (_index < _pages.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _askMic() async {
    if (_micAsked) return;
    setState(() => _micAsked = true);
    final AppState app = context.read<AppState>();
    final bool ok = await app.stt.init();
    await A11yService.haptic(ok ? 'success' : 'danger', enabled: app.s.haptics);
    if (!mounted) return;
    await app.speak(
      ok
          ? 'تم تفعيل الميكروفون. جرّب قول: أين أنا.'
          : 'لم يتم تفعيل الميكروفون. يمكنك تفعيله من إعدادات الجهاز، وستظل كل الأزرار تعمل باللمس.',
      interrupt: true,
    );
  }

  Future<void> _askLocation() async {
    if (_locationAsked) return;
    setState(() => _locationAsked = true);
    final AppState app = context.read<AppState>();
    await app.requestLocationAccess();
    if (!mounted) return;
    await app.speak(
      app.hasLocation
          ? 'تم تحديد موقعك بنجاح.'
          : 'لم نتمكن من تحديد الموقع. يمكنك متابعة استخدام التطبيق، وسيعمل وضع المحاكاة في التنقل.',
      interrupt: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLast = _index == _pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('البداية — ${_index + 1} من ${_pages.length}'),
        automaticallyImplyLeading: false,
        actions: <Widget>[
          TextButton(
            onPressed: _finish,
            child: const Text('تخطي'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (int i) {
                  setState(() => _index = i);
                  _speakCurrent();
                },
                itemBuilder: (BuildContext context, int i) {
                  final _OnboardPage page = _pages[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.13),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 68, color: scheme.primary),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                        ),
                        const SizedBox(height: 22),
                        if (i == 1)
                          ElevatedButton.icon(
                            onPressed: _askMic,
                            icon: const Icon(Icons.mic),
                            label: Text(_micAsked ? 'تم طلب الإذن' : 'السماح بالميكروفون'),
                          ),
                        if (i == 2)
                          ElevatedButton.icon(
                            onPressed: _askLocation,
                            icon: const Icon(Icons.my_location),
                            label: Text(_locationAsked ? 'تم طلب الإذن' : 'السماح بالموقع'),
                          ),
                        if (i == 3)
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SosContactsScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('إضافة جهة اتصال'),
                          ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _speakCurrent,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('أعد الاستماع'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 30 : 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: i == _index ? scheme.primary : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _next,
                    icon: Icon(isLast ? Icons.check_circle_outline : Icons.arrow_back_rounded),
                    label: Text(isLast ? 'ابدأ الاستخدام' : 'التالي'),
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
