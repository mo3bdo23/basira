import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/a11y_service.dart';
import '../state/app_state.dart';

/// كرة الصوت: تعرض حالة الاستماع/النطق، وتُشغّل الأمر الصوتي بالضغط.
/// مصممة لتُقرأ كعنصر واحد واضح في TalkBack.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key,
    required this.onTap,
    this.listening = false,
    this.speaking = false,
    this.size = 132,
    this.label,
  });

  final VoidCallback onTap;
  final bool listening;
  final bool speaking;
  final double size;
  final String? label;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening || widget.speaking) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening || widget.speaking) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String state = widget.listening
        ? 'يستمع الآن'
        : widget.speaking
            ? 'يتحدث الآن'
            : 'اضغط للتحدث';
    final String semantics = widget.label ?? 'الأوامر الصوتية — $state';

    return Semantics(
      button: true,
      liveRegion: true,
      label: semantics,
      hint: 'اضغط مرتين لبدء الاستماع ثم قل أمرك',
      child: GestureDetector(
        onTap: () {
          A11yService.haptic('double', enabled: context.read<AppState>().s.haptics);
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (BuildContext context, Widget? child) {
            final double scale = 1 + (_pulse.value * 0.06);
            return SizedBox(
              width: widget.size + 40,
              height: widget.size + 40,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.size + 26,
                        height: widget.size + 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary.withOpacity(0.14),
                        ),
                      ),
                    ),
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: <Color>[
                            scheme.primary,
                            scheme.primary.withOpacity(0.78),
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: scheme.primary.withOpacity(0.35),
                            blurRadius: 26,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.listening
                            ? Icons.mic
                            : widget.speaking
                                ? Icons.volume_up_rounded
                                : Icons.mic_none_rounded,
                        size: 58,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
