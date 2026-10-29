import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../models/app_settings.dart';
import '../models/university.dart';
import '../models/user.dart';
import '../services/a11y_service.dart';
import '../services/storage_service.dart';
import '../services/voice_command_router.dart';
import '../state/app_state.dart';
import '../widgets/app_scaffold.dart';
import 'disclaimer_screen.dart';
import 'onboarding_screen.dart';
import 'sos_contacts_screen.dart';
import 'voice_settings_screen.dart';

/// الإعدادات: الصوت، الإرشاد، الإتاحة، الطوارئ، الخصوصية، عن التطبيق.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String route = '/settings';

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final AppSettings s = app.s;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return AppScaffold(
      title: 'الإعدادات',
      subtitle: 'تحكّم كامل في الصوت والإتاحة والخصوصية',
      body: ListView(
        children: <Widget>[
          // ── الصوت ──────────────────────────────────────────
          _Section(
            icon: Icons.record_voice_over_rounded,
            title: 'الصوت',
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_rounded, size: 30),
                title: const Text('إعدادات صوت متقدمة', style: TextStyle(fontSize: 19)),
                subtitle: const Text('اختيار الصوت · مستوى الصوت · أسلوب الإرشاد'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const VoiceSettingsScreen()),
                ),
              ),
              const Divider(height: 20),
              _LabelValue(label: 'سرعة النطق', value: '${(s.speechRate * 100).round()}%'),
              Slider(
                value: s.speechRate,
                min: 0.2,
                max: 1.0,
                divisions: 16,
                label: '${(s.speechRate * 100).round()}%',
                onChanged: (double v) => app.setSpeechRate(v),
                onChangeEnd: (double v) async {
                  await app.speak('بهذه السرعة سأتحدث معك.', interrupt: true);
                },
              ),
              _LabelValue(label: 'حِدّة الصوت', value: s.pitch.toStringAsFixed(1)),
              Slider(
                value: s.pitch,
                min: 0.6,
                max: 1.6,
                divisions: 10,
                label: s.pitch.toStringAsFixed(1),
                onChanged: (double v) => app.setPitch(v),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => app.speak(
                  'مرحبًا، أنا بصيرة. سأرشدك إلى وجهتك خطوة بخطوة، وسأنبهك عند الإشارات والعوائق.',
                  interrupt: true,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('تجربة الصوت'),
              ),
            ],
          ),

          // ── الإرشاد ────────────────────────────────────────
          _Section(
            icon: Icons.route_rounded,
            title: 'أسلوب الإرشاد',
            children: <Widget>[
              SegmentedButton<GuidanceVerbosity>(
                segments: <ButtonSegment<GuidanceVerbosity>>[
                  for (final GuidanceVerbosity v in GuidanceVerbosity.values)
                    ButtonSegment<GuidanceVerbosity>(value: v, label: Text(v.labelAr)),
                ],
                selected: <GuidanceVerbosity>{s.verbosity},
                onSelectionChanged: (Set<GuidanceVerbosity> v) {
                  app.patchSettings(verbosity: v.first);
                  A11yService.announce(v.first.descriptionAr);
                },
              ),
              const SizedBox(height: 8),
              Text(
                s.verbosity.descriptionAr,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),

          // ── الإتاحة ────────────────────────────────────────
          _Section(
            icon: Icons.accessibility_new_rounded,
            title: 'الإتاحة',
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('القراءة عند التحديد', style: TextStyle(fontSize: 19)),
                subtitle: const Text('يُقرأ العنصر تلقائيًا عند وصول قارئ الشاشة إليه'),
                value: s.announceOnFocus,
                onChanged: (bool v) => app.patchSettings(announceOnFocus: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('الاهتزاز الدلالي', style: TextStyle(fontSize: 19)),
                subtitle: const Text('اهتزاز مختلف للتنبيه والخطر'),
                value: s.haptics,
                onChanged: (bool v) => app.patchSettings(haptics: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('وضع التباين العالي', style: TextStyle(fontSize: 19)),
                subtitle: const Text('أصفر على أسود — لمن لديهم بقايا بصر'),
                value: s.highContrast,
                onChanged: (bool v) => app.patchSettings(highContrast: v),
              ),
              const SizedBox(height: 6),
              const Text('المظهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode)),
                  ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode)),
                  ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text('النظام'), icon: Icon(Icons.settings_suggest)),
                ],
                selected: <ThemeMode>{s.themeMode},
                onSelectionChanged: (Set<ThemeMode> v) => app.patchSettings(themeMode: v.first),
              ),
            ],
          ),

          // ── الطوارئ ────────────────────────────────────────
          _Section(
            icon: Icons.emergency_rounded,
            title: 'الطوارئ (SOS)',
            children: <Widget>[
              _LabelValue(label: 'مدة العد التنازلي', value: '${s.sosCountdownSeconds} ثانية'),
              Slider(
                value: s.sosCountdownSeconds.toDouble(),
                min: 3,
                max: 15,
                divisions: 12,
                label: '${s.sosCountdownSeconds} ث',
                onChanged: (double v) => app.patchSettings(sosCountdownSeconds: v.round()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حفظ سجل أحداث الاستغاثة', style: TextStyle(fontSize: 19)),
                subtitle: const Text('يبقى على جهازك فقط، ويُحذف تلقائيًا بعد 30 حدثًا'),
                value: s.saveSosHistory,
                onChanged: (bool v) => app.patchSettings(saveSosHistory: v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.contacts_rounded, size: 30),
                title: const Text('جهات اتصال الطوارئ', style: TextStyle(fontSize: 19)),
                subtitle: Text('${app.sos.contacts().length} جهة مسجلة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SosContactsScreen()),
                ),
              ),
            ],
          ),

          // ── الخصوصية والبيانات ─────────────────────────────
          _Section(
            icon: Icons.privacy_tip_rounded,
            title: 'الخصوصية والبيانات',
            children: <Widget>[
              _InfoRow(
                icon: Icons.lock_rounded,
                label: 'تشفير التخزين المحلي',
                value: StorageService.instance.encrypted ? 'مفعّل (AES)' : 'غير متاح على هذا الجهاز',
              ),
              _InfoRow(
                icon: Icons.location_on_rounded,
                label: 'الوصول إلى الموقع',
                value: s.locationConsent ? 'مسموح أثناء الاستخدام' : 'غير مسموح',
              ),
              _InfoRow(
                icon: Icons.cloud_off_rounded,
                label: 'البلاغات المعلّقة',
                value: '${app.sync.pendingCount}',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('السماح باستخدام الموقع', style: TextStyle(fontSize: 19)),
                subtitle: const Text('مطلوب للتنقل والتنبيهات وإرسال الموقع في الطوارئ'),
                value: s.locationConsent,
                onChanged: (bool v) async {
                  if (v) {
                    await app.requestLocationAccess();
                    await app.speak(
                      app.hasLocation ? 'تم تفعيل الموقع.' : 'لم يتم تفعيل الموقع. تحقق من أذونات الجهاز.',
                      interrupt: true,
                    );
                  } else {
                    await app.patchSettings(locationConsent: false);
                    await app.location.stop();
                    await app.speak('تم إيقاف استخدام الموقع.');
                  }
                },
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  await app.connectivity.check();
                  final int n = await app.sync.flush();
                  await app.speak(
                    'تمت المزامنة. رُفع $n بلاغًا.',
                    interrupt: true,
                  );
                },
                icon: const Icon(Icons.sync_rounded),
                label: const Text('مزامنة البلاغات الآن'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error, width: 2),
                ),
                onPressed: () => _confirmWipe(context, app),
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('حذف كل بياناتي'),
              ),
            ],
          ),

          // ── الحساب والدور ──────────────────────────────────
          _Section(
            icon: Icons.person_rounded,
            title: 'الحساب',
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.person, color: scheme.onPrimaryContainer, size: 30),
                ),
                title: Text(
                  s.userName.isEmpty ? 'مستخدم بصيرة' : s.userName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(s.role.labelAr),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => _editProfile(context, app),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_rounded, size: 30),
                title: const Text('الجامعة الحالية', style: TextStyle(fontSize: 19)),
                subtitle: Text(app.currentUniversity?.name ?? 'غير محددة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _pickUniversity(context, app),
              ),
            ],
          ),

          // ── المساعدة وعن التطبيق ───────────────────────────
          _Section(
            icon: Icons.info_outline_rounded,
            title: 'المساعدة وعن التطبيق',
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over_rounded, size: 30),
                title: const Text('الأوامر الصوتية المتاحة', style: TextStyle(fontSize: 19)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _showCommands(context, app),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.replay_rounded, size: 30),
                title: const Text('إعادة التدريب الصوتي', style: TextStyle(fontSize: 19)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  await app.patchSettings(onboardingDone: false);
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamed(OnboardingScreen.route);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined, size: 30),
                title: const Text('إخلاء المسؤولية', style: TextStyle(fontSize: 19)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DisclaimerScreen()),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'بصيرة ${AppConfig.version} — تطبيق تنقل صوتي مفتوح المصدر.\n'
                'يعمل بدون إنترنت · يدعم TalkBack و VoiceOver · MIT License',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, AppState app) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف كل البيانات؟'),
        content: const Text(
          'سيتم حذف الإعدادات وجهات اتصال الطوارئ والبلاغات المحلية نهائيًا. '
          'لا يمكن التراجع عن هذه الخطوة.',
          style: TextStyle(fontSize: 18),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.speak('جارٍ حذف البيانات.', interrupt: true);
    await StorageService.instance.wipe();
    await app.settings.load();
    await app.speak('تم حذف كل البيانات. سيُعاد تشغيل التطبيق من البداية.', interrupt: true);
  }

  Future<void> _editProfile(BuildContext context, AppState app) async {
    final TextEditingController name = TextEditingController(text: app.s.userName);
    UserRole role = app.s.role;
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('الملف الشخصي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: name,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'نوع المستخدم'),
                items: <DropdownMenuItem<UserRole>>[
                  for (final UserRole r in UserRole.values)
                    DropdownMenuItem<UserRole>(value: r, child: Text(r.labelAr)),
                ],
                onChanged: (UserRole? v) => setState(() => role = v ?? UserRole.blind),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (save == true) {
      await app.patchSettings(userName: name.text.trim(), role: role);
      await app.speak('تم حفظ بياناتك.');
    }
    name.dispose();
  }

  Future<void> _pickUniversity(BuildContext context, AppState app) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => ListView(
        shrinkWrap: true,
        children: <Widget>[
          for (final University u in app.universityList)
            ListTile(
              leading: const Icon(Icons.account_balance_rounded),
              title: Text(u.name, style: const TextStyle(fontSize: 20)),
              subtitle: Text(u.city, style: const TextStyle(fontSize: 16)),
              onTap: () => Navigator.of(context).pop(u.id),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await app.selectUniversity(chosen);
      await app.speak('تم اختيار الجامعة.');
    }
  }

  Future<void> _showCommands(BuildContext context, AppState app) async {
    await app.speak('الأوامر المتاحة: ${VoiceCommandRouter.helpPhrases.join('، ')}.', interrupt: true);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('الأوامر الصوتية'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String c in VoiceCommandRouter.helpPhrases)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $c', style: const TextStyle(fontSize: 19)),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('حسنًا')),
        ],
      ),
    );
  }
}

/// عنوان قسم قابل للقراءة كعنصر واحد.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Row(
              children: <Widget>[
                Icon(icon, color: scheme.primary, size: 28),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 24, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 17)),
          ),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
