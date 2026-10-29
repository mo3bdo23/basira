import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../models/sos_contact.dart';
import '../services/a11y_service.dart';
import '../state/app_state.dart';
import '../widgets/sos_button.dart';

/// شاشة الاستغاثة: عدّ تنازلي، إلغاء واضح، وإرسال الموقع برسالة + اتصال.
class SosActiveScreen extends StatefulWidget {
  const SosActiveScreen({super.key});

  static const String route = '/sos';

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _remaining = 5;
  bool _sent = false;
  late final AppState _state;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _remaining = _state.s.sosCountdownSeconds;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final int count = _remaining;
    await _state.speak(
      'وضع الاستغاثة. سيُرسل موقعك إلى جهات اتصالك خلال $count ثوان. '
      'اضغط زر الإلغاء لإيقاف الإرسال.',
      interrupt: true,
    );
    A11yService.haptic('danger', enabled: _state.s.haptics);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 3 && _remaining > 0) {
        A11yService.haptic('tap', enabled: _state.s.haptics);
      }
      if (_remaining <= 0) {
        t.cancel();
        _send();
      }
    });
  }

  Future<void> _send() async {
    if (_sent) return;
    setState(() => _sent = true);
    final AppState app = _state;
    final List<SosContact> contacts = app.sos.contacts();
    final LatLng position =
        app.position ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng);

    if (contacts.isEmpty) {
      await app.speak(
        'لا توجد جهات اتصال مسجلة. أضف جهة اتصال الآن ليصله موقعك.',
        interrupt: true,
      );
      return;
    }

    await app.sos.logEvent(
      position: position,
      contactsNotified: contacts.length,
      persist: app.s.saveSosHistory,
    );

    final SosContact primary = contacts.first;
    final String message = app.sos.buildMessage(
      userName: app.s.userName,
      position: position,
    );

    final bool ok = await app.sos.openSms(primary.dialablePhone, message);
    await app.speak(
      ok
          ? 'تم تجهيز رسالة الاستغاثة إلى ${primary.name} وفيها موقعك. اضغط إرسال في تطبيق الرسائل.'
          : 'تعذّر فتح تطبيق الرسائل. سأحاول الاتصال بـ ${primary.name}.',
      interrupt: true,
    );
    if (!ok) {
      await app.sos.call(primary.dialablePhone);
    }
    if (mounted) setState(() {});
  }

  void _cancel() {
    _timer?.cancel();
    final AppState app = _state;
    app.sos.logEvent(
      position: app.position ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
      contactsNotified: 0,
      cancelled: true,
      persist: app.s.saveSosHistory,
    );
    app.speak('تم إلغاء الاستغاثة. لم يُرسل موقعك.', interrupt: true);
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final SosContact? primary = app.sos.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0505),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    iconSize: 32,
                    color: Colors.white,
                    tooltip: 'رجوع',
                    onPressed: _cancel,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'وضع الاستغاثة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _pulse,
                builder: (BuildContext context, _) {
                  final double scale = _sent ? 1 : 1 + _pulse.value * 0.05;
                  return Transform.scale(
                    scale: scale,
                    child: SosButton(
                      size: 190,
                      onTap: _sent ? _send : () {},
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              Text(
                _sent
                    ? 'تم تجهيز رسالة الاستغاثة'
                    : (_remaining > 0 ? '$_remaining' : 'جارٍ الإرسال…'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _sent ? 28 : 96,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _sent
                    ? 'أرسل الموقع من تطبيق الرسائل، أو اتصل الآن.'
                    : 'سيُرسل موقعك إلى جهات اتصالك الطارئة',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 19),
              ),
              const SizedBox(height: 8),
              if (primary != null)
                Text(
                  'جهة الاتصال الأساسية: ${primary.name}',
                  style: const TextStyle(color: Colors.white70, fontSize: 17),
                ),
              const Spacer(),
              if (_sent && primary != null)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF8E0000),
                        ),
                        onPressed: () => app.sos.openSms(
                          primary.dialablePhone,
                          app.sos.buildMessage(
                            userName: app.s.userName,
                            position: app.position ??
                                const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
                          ),
                        ),
                        icon: const Icon(Icons.sms_rounded),
                        label: const Text('رسالة'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => app.sos.call(primary.dialablePhone),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('اتصال'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 68,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2.5),
                  ),
                  onPressed: _cancel,
                  icon: const Icon(Icons.cancel_rounded, size: 28),
                  label: const Text('إلغاء الاستغاثة', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'في الخطر المباشر اتصل بالنجدة 122 أو الإسعاف 123',
                style: TextStyle(color: Colors.white54, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
