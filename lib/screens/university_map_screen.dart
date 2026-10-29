import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/geo.dart';
import '../models/university.dart';
import '../state/app_state.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/campus_map.dart';
import 'navigation_screen.dart';

/// خريطة الجامعة: خريطة تخطيطية أوفلاين + دليل صوتي لكل مبنى.
class UniversityMapScreen extends StatefulWidget {
  const UniversityMapScreen({super.key});

  static const String route = '/campus';

  @override
  State<UniversityMapScreen> createState() => _UniversityMapScreenState();
}

class _UniversityMapScreenState extends State<UniversityMapScreen> {
  CampusBuilding? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AppState app = context.read<AppState>();
      await app.speak(_intro(app), interrupt: true);
    });
  }

  String _intro(AppState app) {
    final University? u = app.currentUniversity;
    if (u == null) return 'لا توجد بيانات جامعات محفوظة.';
    final String gate = u.mainGate?.name ?? 'غير محددة';
    return 'خريطة ${u.name}. فيها ${u.buildings.length} مبنى. '
        'البوابة الرئيسية: $gate. '
        'اسحب لأسفل لقائمة المباني، ولكل مبنى دليل صوتي وإرشاد.';
  }

  Future<void> _playGuide(AppState app, University u, CampusBuilding b) async {
    setState(() => _selected = b);
    final StringBuffer sb = StringBuffer('${b.name}. ${b.categoryLabelAr}. ');
    if (b.description.isNotEmpty) sb.write('${b.description} ');
    if (b.entranceNote.isNotEmpty) sb.write('المدخل: ${b.entranceNote} ');
    for (final String step in b.audioGuide) {
      sb.write('$step ');
    }
    if (app.position != null) {
      final double d = Geo.distanceMeters(
        app.position!.latitude,
        app.position!.longitude,
        b.lat,
        b.lng,
      );
      sb.write('يبعد عنك حوالي ${Geo.spokenDistance(d)}.');
    }
    await app.speak(sb.toString(), interrupt: true);
  }

  Future<void> _navigate(AppState app, University u, CampusBuilding b) async {
    if (app.position == null) {
      await app.speak(
        'لا يوجد موقع محدد. فعّل الموقع أولًا من الإعدادات، أو شغّل المحاكاة من شاشة التنقل.',
        interrupt: true,
      );
      return;
    }
    final route = app.routeToBuilding(u, b);
    if (route == null) return;
    app.startNavigation(route);
    await app.speak('بدأ الإرشاد إلى ${b.name}.', interrupt: true);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final University? university = app.currentUniversity;

    if (university == null) {
      return const AppScaffold(
        title: 'خريطة الجامعة',
        body: Center(child: Text('لا توجد بيانات جامعات.')),
      );
    }

    return AppScaffold(
      title: 'خريطة الجامعة',
      subtitle: university.name,
      speakTitle: false,
      actions: <Widget>[
        if (app.universityList.length > 1)
          Semantics(
            button: true,
            label: 'تغيير الجامعة',
            child: IconButton(
              iconSize: 30,
              tooltip: 'تغيير الجامعة',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () async {
                final University? chosen = await showModalBottomSheet<University>(
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
                          onTap: () => Navigator.of(context).pop(u),
                        ),
                    ],
                  ),
                );
                if (chosen != null) {
                  await app.selectUniversity(chosen.id);
                  await app.speak('تم اختيار ${chosen.name}.', interrupt: true);
                }
              },
            ),
          ),
      ],
      body: ListView(
        children: <Widget>[
          CampusMap(
            university: university,
            position: app.position,
            target: _selected?.position,
            height: 300,
          ),
          const SizedBox(height: 14),

          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final AppState app = context.read<AppState>();
                    await app.speak(_intro(app), interrupt: true);
                  },
                  icon: const Icon(Icons.hearing_rounded),
                  label: const Text('دليل صوتي للحرم'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: app.position == null
                      ? () async {
                          await app.speak('لا يوجد موقع محدد.', interrupt: true);
                        }
                      : () {
                          final CampusBuilding? nearest = university.nearestBuilding(
                            app.position!.latitude,
                            app.position!.longitude,
                          );
                          if (nearest != null) _playGuide(app, university, nearest);
                        },
                  icon: const Icon(Icons.near_me_rounded),
                  label: const Text('أقرب مبنى'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text('المباني والمرافق', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),

          ...university.buildings.map((CampusBuilding b) {
            final double? d = app.position == null
                ? null
                : Geo.distanceMeters(
                    app.position!.latitude, app.position!.longitude, b.lat, b.lng);
            final bool selected = _selected?.id == b.id;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: selected
                  ? scheme.primaryContainer.withOpacity(0.5)
                  : scheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _playGuide(app, university, b),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: scheme.secondary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_iconFor(b.category), color: scheme.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(b.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              '${b.categoryLabelAr}${d != null ? ' · ${Geo.shortDistance(d)}' : ''}',
                              style: TextStyle(
                                fontSize: 16,
                                color: scheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'إرشاد إلى ${b.name}',
                        child: IconButton(
                          iconSize: 30,
                          tooltip: 'إرشاد',
                          onPressed: () => _navigate(app, university, b),
                          icon: const Icon(Icons.navigation_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'gate':
        return Icons.door_front_door_rounded;
      case 'library':
        return Icons.local_library_rounded;
      case 'faculty':
        return Icons.school_rounded;
      case 'service':
        return Icons.local_hospital_rounded;
      default:
        return Icons.apartment_rounded;
    }
  }
}
