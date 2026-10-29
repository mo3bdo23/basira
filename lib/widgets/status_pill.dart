import 'package:flutter/material.dart';

/// شريط حالة صغير: الاتصال + GPS + البلاغات المعلّقة.
/// غير تفاعلي، ويُقرأ كسطر واحد في قارئ الشاشة.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.online,
    required this.gps,
    this.pending = 0,
    this.simulated = false,
  });

  final bool online;
  final bool gps;
  final int pending;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> parts = <String>[
      online ? 'متصل بالإنترنت' : 'يعمل بدون إنترنت',
      gps ? 'تحديد الموقع يعمل' : 'لا يوجد تحديد موقع',
      if (simulated) 'وضع محاكاة',
      if (pending > 0) '$pending بلاغ بانتظار المزامنة',
    ];

    return Semantics(
      label: parts.join('، '),
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _Chip(
            icon: online ? Icons.wifi : Icons.wifi_off,
            label: online ? 'متصل' : 'أوفلاين',
            color: online ? scheme.primary : scheme.error,
          ),
          _Chip(
            icon: gps ? Icons.my_location : Icons.location_off,
            label: gps ? 'GPS' : 'بدون GPS',
            color: gps ? scheme.primary : scheme.outline,
          ),
          if (simulated)
            _Chip(icon: Icons.play_circle_outline, label: 'محاكاة', color: scheme.tertiary),
          if (pending > 0)
            _Chip(icon: Icons.cloud_upload_outlined, label: '$pending', color: scheme.secondary),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
