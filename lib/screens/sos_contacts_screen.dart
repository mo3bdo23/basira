import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../models/sos_contact.dart';
import '../state/app_state.dart';
import '../widgets/app_scaffold.dart';

/// إدارة جهات اتصال الطوارئ: إضافة، تعديل، حذف، اختيار الأساسية، وتجربة الإرسال.
class SosContactsScreen extends StatelessWidget {
  const SosContactsScreen({super.key});

  static const String route = '/sos-contacts';

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<SosContact> contacts = app.sos.contacts();

    return AppScaffold(
      title: 'جهات اتصال الطوارئ',
      subtitle: 'يُرسل موقعك لهذه الجهات عند الضغط على SOS',
      body: Column(
        children: <Widget>[
          if (contacts.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.contacts_rounded, size: 88, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('لا توجد جهات اتصال بعد',
                        style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'أضف شخصًا تثق به ليصله موقعك عند الطوارئ.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _editDialog(context, app),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('إضافة جهة اتصال'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int i) {
                  final SosContact c = contacts[i];
                  return Card(
                    elevation: 0,
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: c.isPrimary ? scheme.primary : scheme.outlineVariant,
                        width: c.isPrimary ? 2.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          c.initial,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(c.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          ),
                          if (c.isPrimary) ...<Widget>[
                            const SizedBox(width: 6),
                            Icon(Icons.star_rounded, size: 22, color: scheme.primary),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${c.relation.isEmpty ? 'جهة اتصال' : c.relation} · ${c.phone}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: PopupMenuButton<String>(
                        iconSize: 28,
                        tooltip: 'خيارات',
                        onSelected: (String v) => _onAction(context, app, c, v),
                        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(value: 'edit', child: Text('تعديل', style: TextStyle(fontSize: 18))),
                          PopupMenuItem<String>(value: 'primary', child: Text('تعيين كأساسية', style: TextStyle(fontSize: 18))),
                          PopupMenuItem<String>(value: 'test', child: Text('رسالة تجريبية', style: TextStyle(fontSize: 18))),
                          PopupMenuItem<String>(value: 'delete', child: Text('حذف', style: TextStyle(fontSize: 18))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (contacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton.icon(
                onPressed: () => _editDialog(context, app),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة جهة اتصال'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    AppState app,
    SosContact contact,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await _editDialog(context, app, existing: contact);
      case 'primary':
        await app.sos.save(
          id: contact.id,
          name: contact.name,
          phone: contact.phone,
          relation: contact.relation,
          isPrimary: true,
        );
        await app.speak('${contact.name} أصبحت جهة الاتصال الأساسية.');
      case 'test':
        final String message = app.sos.buildMessage(
          userName: app.s.userName,
          position: app.position ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
          note: 'رسالة تجريبية من تطبيق بصيرة',
        );
        final bool ok = await app.sos.openSms(contact.dialablePhone, message);
        await app.speak(
          ok
              ? 'تم فتح تطبيق الرسائل برسالة تجريبية إلى ${contact.name}. اضغط إرسال.'
              : 'تعذر فتح تطبيق الرسائل على هذا الجهاز.',
        );
      case 'delete':
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('حذف ${contact.name}؟'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('حذف')),
            ],
          ),
        );
        if (ok == true) {
          await app.sos.delete(contact.id);
          await app.speak('تم حذف ${contact.name}.');
        }
    }
  }

  Future<void> _editDialog(
    BuildContext context,
    AppState app, {
    SosContact? existing,
  }) async {
    final TextEditingController name = TextEditingController(text: existing?.name ?? '');
    final TextEditingController phone = TextEditingController(text: existing?.phone ?? '');
    final TextEditingController relation = TextEditingController(text: existing?.relation ?? '');
    bool primary = existing?.isPrimary ?? (app.sos.contacts().isEmpty);
    String? error;

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text(existing == null ? 'إضافة جهة اتصال' : 'تعديل جهة الاتصال'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: name,
                  style: const TextStyle(fontSize: 20),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '01xxxxxxxxx',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relation,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(labelText: 'صفة الجهة (أب، صديق، مشرف…)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('جهة الاتصال الأساسية', style: TextStyle(fontSize: 18)),
                  value: primary,
                  onChanged: (bool v) => setState(() => primary = v),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () {
                final String digits = phone.text.replaceAll(RegExp(r'[^0-9]'), '');
                if (name.text.trim().isEmpty) {
                  setState(() => error = 'اكتب الاسم');
                  return;
                }
                if (digits.length < 8) {
                  setState(() => error = 'رقم غير صالح');
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      await app.sos.save(
        id: existing?.id,
        name: name.text.trim(),
        phone: phone.text.trim(),
        relation: relation.text.trim(),
        isPrimary: primary,
      );
      await app.speak('تم حفظ ${name.text.trim()} في جهات اتصال الطوارئ.');
    }
    name.dispose();
    phone.dispose();
    relation.dispose();
  }
}
