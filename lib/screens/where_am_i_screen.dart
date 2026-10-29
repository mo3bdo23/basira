import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/geo.dart';
import '../models/obstacle.dart';
import '../models/university.dart';
import '../services/traffic_signal_service.dart';
import '../state/app_state.dart';
import '../widgets/app_scaffold.dart';
import 'university_map_screen.dart';

/// شاشة «أين أنا؟»: وصف كامل للموقع الحالي بصوت وبنص كبير.
class WhereAmIScreen extends StatefulWidget {
  const WhereAmIScreen({super.key});

  static const String route = '/where-am-i';

  @override
  State<WhereAmIScreen> createState() => _WhereAmIScreenState();
}

class _WhereAmIScreenState extends State<WhereAmIScreen> {
  bool _spoken = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _describe(speak: true));
  }

  String _describe({bool speak = false}) {
    final AppState app = context.read<AppState>();
    final LatLng? pos = app.position;
    if (pos == null) {
      return 'لا يوجد تحديد موقع حاليًا. اسمح بالوصول إلى الموقع من الإعدادات، '
          'أو استخدم وضع المحاكاة من شاشة التنقل.';
    }

    final StringBuffer sb = StringBuffer();
    sb.write('أنت الآن عند خط العرض ${pos.latitude.toStringAsFixed(5)}، '
        'وخط الطول ${pos.longitude.toStringAsFixed(5)}. ');

    if (app.location.accuracyMeters.value > 0) {
      sb.write('دقة التحديد حوالي ${app.location.accuracyMeters.value.round()} متر. ');
    }

    final University? u = app.currentUniversity;
    if (u != null) {
      final CampusBuilding? nearest = u.nearestBuilding(pos.latitude, pos.longitude);
      if (nearest != null) {
        final double d =
            Geo.distanceMeters(pos.latitude, pos.longitude, nearest.lat, nearest.lng);
        sb.write('أقرب مبنى في ${u.shortName.isEmpty ? u.name : u.shortName}: '
            '${nearest.name}، على بعد ${Geo.spokenDistance(d)}. ');
      }
    }

    final SignalSnapshot? signal = app.nearestSignal(radius: 150);
    if (signal != null) {
      sb.write('${signal.toSpeech()} ');
    } else {
      sb.write('لا توجد إشارة مرور مسجّلة قريبة. ');
    }

    final List<Obstacle> obstacles = app.nearbyObstacles(radius: 80);
    if (obstacles.isEmpty) {
      sb.write('لا توجد عوائق مجتمعية مسجّلة قريبة منك.');
    } else {
      sb.write('يوجد ${obstacles.length} بلاغ قريب: ');
      sb.write(obstacles.take(3).map((Obstacle o) => o.type.labelAr).join('، '));
      sb.write('.');
    }
    return sb.toString();
  }

  Future<void> _share(AppState app) async {
    final LatLng? pos = app.position;
    if (pos == null) {
      await app.speak('لا يوجد موقع لمشاركته.', interrupt: true);
      return;
    }
    final contact = app.sos.primary;
    if (contact == null) {
      await app.speak('أضف جهة اتصال أولًا من إعدادات الطوارئ.', interrupt: true);
      return;
    }
    final String message = app.sos.buildMessage(userName: app.s.userName, position: pos);
    final bool ok = await app.sos.openSms(contact.dialablePhone, message);
    await app.speak(
      ok
          ? 'تم تجهيز رسالة إلى ${contact.name} بها موقعك. اضغط إرسال.'
          : 'تعذّر فتح تطبيق الرسائل.',
      interrupt: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final LatLng? pos = app.position;
    final String description = _describe();

    if (!_spoken && pos != null) {
      _spoken = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) app.speak(description, interrupt: true);
      });
    }

    final University? u = app.currentUniversity;
    final CampusBuilding? nearest =
        (u != null && pos != null) ? u.nearestBuilding(pos.latitude, pos.longitude) : null;
    final double? nearestDistance = (nearest != null && pos != null)
        ? Geo.distanceMeters(pos.latitude, pos.longitude, nearest.lat, nearest.lng)
        : null;
    final SignalSnapshot? signal = app.nearestSignal(radius: 150);
    final List<Obstacle> obstacles = app.nearbyObstacles(radius: 80);

    return AppScaffold(
      title: 'أين أنا؟',
      subtitle: 'وصف موقعك ومحيطك',
      speakTitle: false,
      body: ListView(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[scheme.primary, scheme.primary.withValues(alpha: 0.78)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.my_location_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text('موقعك الآن',
                        style: TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (nearest != null)
            _InfoTile(
              icon: Icons.account_balance_rounded,
              title: nearest.name,
              subtitle:
                  '${nearest.categoryLabelAr}${nearestDistance != null ? ' · ${Geo.shortDistance(nearestDistance)}' : ''}',
              onTap: () => app.speak(
                '${nearest.name}. ${nearest.description} ${nearest.entranceNote}',
                interrupt: true,
              ),
            ),

          if (signal != null)
            _InfoTile(
              icon: Icons.traffic_rounded,
              title: signal.signal.name,
              subtitle:
                  '${signal.isGreen ? 'أخضر' : 'أحمر'} · ${signal.secondsRemaining} ثانية · ${Geo.shortDistance(signal.distanceMeters)}',
              onTap: () => app.speak(signal.toSpeech(), interrupt: true),
            ),

          if (obstacles.isNotEmpty)
            _InfoTile(
              icon: Icons.warning_amber_rounded,
              title: '${obstacles.length} بلاغ قريب',
              subtitle: obstacles.take(3).map((Obstacle o) => o.type.labelAr).join(' · '),
              onTap: () => app.speak(
                obstacles.take(5).map((Obstacle o) => o.toSpeech()).join('. '),
                interrupt: true,
              ),
            ),

          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => app.speak(description, interrupt: true),
            icon: const Icon(Icons.record_voice_over_rounded),
            label: const Text('اسمع الوصف مرة أخرى'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _share(app),
            icon: const Icon(Icons.share_location_rounded),
            label: const Text('شارك موقعي مع جهة اتصال'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const UniversityMapScreen()),
            ),
            icon: const Icon(Icons.map_rounded),
            label: const Text('افتح خريطة الجامعة'),
          ),
          const SizedBox(height: 14),
          Text(
            'حدود النظام: دقة GPS قد تصل إلى 30 مترًا خارج المباني، '
            'ولا تتوفر داخل الأنفاق. لا تعتمد على الوصف وحده عند عبور الطرق.',
            style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(icon, size: 30, color: scheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 15)),
        trailing: const Icon(Icons.volume_up_rounded),
        onTap: onTap,
      ),
    );
  }
}
