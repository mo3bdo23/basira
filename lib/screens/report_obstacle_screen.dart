import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/geo.dart';
import '../models/obstacle.dart';
import '../state/app_state.dart';
import '../widgets/app_scaffold.dart';

/// بلّغ عن عائق: نوع + وصف صوتي + موقع تلقائي + إرسال يعمل أوفلاين.
class ReportObstacleScreen extends StatefulWidget {
  const ReportObstacleScreen({super.key});

  static const String route = '/report';

  @override
  State<ReportObstacleScreen> createState() => _ReportObstacleScreenState();
}

class _ReportObstacleScreenState extends State<ReportObstacleScreen> {
  ObstacleType _type = ObstacleType.blockedSidewalk;
  int _severity = 2;
  bool _sending = false;
  bool _done = false;
  bool _listening = false;
  final TextEditingController _desc = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().speak(
        'شاشة الإبلاغ عن عائق. اختر نوع العائق، ثم أضف وصفًا صوتيًا إن أردت. '
        'موقعك يُسجَّل تلقائيًا. البلاغ يعمل بدون إنترنت ويُرسل عند عودته.',
        interrupt: true,
      );
    });
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _dictate() async {
    final AppState app = context.read<AppState>();
    if (_listening) {
      await app.stt.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await app.speak('تحدّث الآن لوصف العائق.', interrupt: true);
    await app.stt.listen(
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onResult: (String text) {
        setState(() {
          _desc.text = text;
          _listening = false;
        });
      },
    );
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _submit() async {
    if (_sending) return;
    final AppState app = context.read<AppState>();
    if (app.position == null && !app.s.locationConsent) {
      await app.speak(
        'لا يوجد موقع محدد. سنستخدم الموقع الافتراضي الآن، لكن فعّل الموقع لدقة أفضل.',
        interrupt: true,
      );
    }
    setState(() => _sending = true);
    try {
      final Obstacle o = await app.reportObstacle(
        type: _type,
        description: _desc.text.trim(),
        severity: _severity,
      );
      setState(() {
        _done = true;
        _sending = false;
      });
      await app.speak(
        'تم تسجيل البلاغ: ${o.type.labelAr}. '
        '${app.connectivity.isOnline ? 'جارٍ رفعه للمجتمع.' : 'سيُرفع تلقائيًا عندما يعود الإنترنت.'} '
        'شكرًا لك، بلاغك يحمي غيرك.',
        interrupt: true,
      );
    } catch (e) {
      setState(() => _sending = false);
      await app.speak('تعذّر حفظ البلاغ. حاول مرة أخرى.', interrupt: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double? distanceFromDefault = app.position == null
        ? null
        : Geo.distanceMeters(
            app.position!.latitude,
            app.position!.longitude,
            AppConfig.defaultLat,
            AppConfig.defaultLng,
          );

    return AppScaffold(
      title: 'بلّغ عن عائق',
      subtitle: 'بلاغك يساعد كل مستخدمي بصيرة',
      speakTitle: false,
      body: ListView(
        children: <Widget>[
          if (_done)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, color: scheme.onPrimaryContainer, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تم تسجيل بلاغك. ${app.connectivity.isOnline ? 'تم رفعه للمجتمع.' : 'سيُرفع عند عودة الإنترنت.'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Text('نوع العائق', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final ObstacleType t in ObstacleType.values)
                Semantics(
                  selected: _type == t,
                  button: true,
                  label: t.labelAr,
                  child: ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Text(
                        '${t.emoji}  ${t.labelAr}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    selected: _type == t,
                    onSelected: (_) {
                      setState(() {
                        _type = t;
                        _done = false;
                      });
                      context.read<AppState>().speak(t.labelAr, interrupt: false);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          Text('درجة الخطورة', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 1, label: Text('منخفضة'), icon: Icon(Icons.info_outline)),
              ButtonSegment<int>(value: 2, label: Text('متوسطة'), icon: Icon(Icons.report_gmailerrorred)),
              ButtonSegment<int>(value: 3, label: Text('خطرة'), icon: Icon(Icons.dangerous_outlined)),
            ],
            selected: <int>{_severity},
            onSelectionChanged: (Set<int> v) => setState(() => _severity = v.first),
          ),
          const SizedBox(height: 20),

          Text('وصف إضافي (اختياري)', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLines: 3,
            style: const TextStyle(fontSize: 19),
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'مثال: سلالم بدون درابزين عند مدخل المبنى',
              suffixIcon: IconButton(
                iconSize: 30,
                tooltip: 'إملاء صوتي',
                onPressed: _dictate,
                icon: Icon(_listening ? Icons.mic : Icons.mic_none_rounded),
              ),
            ),
          ),
          if (_listening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'يستمع الآن… تحدث بوضوح',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.place_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('الموقع', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  app.position == null
                      ? 'لا يوجد تحديد موقع حالي — سيُستخدم الموقع الافتراضي (شبين الكوم).'
                      : 'خط العرض ${app.position!.latitude.toStringAsFixed(5)}، '
                          'خط الطول ${app.position!.longitude.toStringAsFixed(5)}'
                          '${distanceFromDefault != null && distanceFromDefault < 50 ? ' — داخل نطاق شبين الكوم' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          ElevatedButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'جارٍ الحفظ…' : 'أرسل البلاغ'),
          ),
          const SizedBox(height: 8),
          Text(
            'يعمل بدون إنترنت — يُخزَّن البلاغ على جهازك ويُرفع تلقائيًا.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}
