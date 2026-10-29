import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../state/app_state.dart';
import '../widgets/app_scaffold.dart';

/// إعدادات الصوت المتقدمة: السرعة، الحِدّة، مستوى الصوت، واختيار الصوت العربي.
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  static const String route = '/voice-settings';

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  List<Map<String, String>>? _voices;

  static const String _sample =
      'هذا اختبار للصوت. امشِ أربعين مترًا ثم انعطف يمينًا، وبعدها ستصل إلى المكتبة.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AppState app = context.read<AppState>();
      final List<Map<String, String>> voices = await app.availableVoices();
      if (mounted) setState(() => _voices = voices);
      await app.speak('إعدادات الصوت. حرّك المؤشرات لتغيير السرعة والنبرة ومستوى الصوت.');
    });
  }

  Future<void> _test(AppState app) async {
    await app.speak(_sample, interrupt: true);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final AppSettings s = app.s;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return AppScaffold(
      title: 'إعدادات الصوت',
      subtitle: 'تحكّم كامل في نطق التطبيق',
      speakTitle: false,
      body: ListView(
        children: <Widget>[
          _card(
            theme,
            title: 'سرعة النطق',
            value: '${(s.speechRate * 100).round()}%',
            child: Slider(
              value: s.speechRate,
              min: 0.2,
              max: 1.0,
              divisions: 16,
              label: '${(s.speechRate * 100).round()}%',
              onChanged: (double v) => app.setSpeechRate(v),
              onChangeEnd: (_) => _test(app),
            ),
          ),
          _card(
            theme,
            title: 'حِدّة الصوت (النبرة)',
            value: s.pitch.toStringAsFixed(1),
            child: Slider(
              value: s.pitch,
              min: 0.6,
              max: 1.6,
              divisions: 10,
              label: s.pitch.toStringAsFixed(1),
              onChanged: (double v) => app.setPitch(v),
              onChangeEnd: (_) => _test(app),
            ),
          ),
          _card(
            theme,
            title: 'مستوى الصوت',
            value: '${(s.volume * 100).round()}%',
            child: Slider(
              value: s.volume,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${(s.volume * 100).round()}%',
              onChanged: (double v) => app.setVolume(v),
              onChangeEnd: (_) => _test(app),
            ),
          ),

          // ── اختيار الصوت ────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('صوت النطق',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  s.voiceName.isEmpty
                      ? 'الصوت التلقائي (أفضل صوت عربي متاح)'
                      : '${s.voiceName} — ${s.voiceLocale}',
                  style: TextStyle(fontSize: 15, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 8),
                if (_voices == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                else if (_voices!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'لا توجد أصوات عربية إضافية على هذا الجهاز. يمكنك تثبيت أصوات من إعدادات النظام.',
                      style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  )
                else
                  RadioGroup<String>(
                    groupValue: s.voiceName.isEmpty ? '__auto__' : '${s.voiceName}|${s.voiceLocale}',
                    onChanged: (String? value) async {
                      if (value == null) return;
                      if (value == '__auto__') {
                        await app.resetVoiceSettings();
                      } else {
                        final List<String> parts = value.split('|');
                        await app.selectVoice(parts[0], parts[1]);
                      }
                      await _test(app);
                    },
                    child: Column(
                      children: <Widget>[
                        const RadioListTile<String>(
                          value: '__auto__',
                          contentPadding: EdgeInsets.zero,
                          title: Text('تلقائي', style: TextStyle(fontSize: 17)),
                        ),
                        for (final Map<String, String> v in _voices!)
                          RadioListTile<String>(
                            value: '${v['name']}|${v['locale']}',
                            contentPadding: EdgeInsets.zero,
                            title: Text(v['name']!, style: const TextStyle(fontSize: 17)),
                            subtitle: Text(v['locale']!, style: const TextStyle(fontSize: 14)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── الإرشاد ─────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('أسلوب الإرشاد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SegmentedButton<GuidanceVerbosity>(
                  segments: <ButtonSegment<GuidanceVerbosity>>[
                    for (final GuidanceVerbosity v in GuidanceVerbosity.values)
                      ButtonSegment<GuidanceVerbosity>(value: v, label: Text(v.labelAr)),
                  ],
                  selected: <GuidanceVerbosity>{s.verbosity},
                  onSelectionChanged: (Set<GuidanceVerbosity> v) {
                    app.patchSettings(verbosity: v.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  s.verbosity.descriptionAr,
                  style: TextStyle(fontSize: 15, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),

          ElevatedButton.icon(
            onPressed: () => _test(app),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('تجربة الصوت'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await app.resetVoiceSettings();
              await app.speak('تمت إعادة إعدادات الصوت إلى الوضع الافتراضي.');
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('إعادة إلى الافتراضي'),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required String title, required String value, required Widget child}) {
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: scheme.primary)),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
