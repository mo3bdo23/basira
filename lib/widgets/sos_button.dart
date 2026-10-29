import 'package:flutter/material.dart';

/// زر الاستغاثة SOS — أحمر، ضخم، ومقروء بوضوح في قارئ الشاشة.
class SosButton extends StatelessWidget {
  const SosButton({
    super.key,
    required this.onTap,
    this.onLongPress,
    this.size = 108,
    this.label = 'استغاثة',
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'زر الاستغاثة SOS. $label',
      hint: 'اضغط مطولًا لإرسال موقعك فورًا، أو اضغط لبدء العد التنازلي',
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[Color(0xFFE53935), Color(0xFF8E0000)],
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.error.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.emergency_share_rounded, color: Colors.white, size: 36),
              const SizedBox(height: 2),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
