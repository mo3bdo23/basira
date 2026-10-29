import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../state/app_state.dart';
import '../services/a11y_service.dart';

/// زر إجراء كبير (≥ 88dp) مع دعم كامل لقارئ الشاشة:
/// - label منطوق، hint إرشادي، وزر حقيقي في شجرة الـ Semantics.
/// - يقرأ نفسه عند وصول focus إليه (مثل مرور TalkBack).
class BigActionButton extends StatefulWidget {
  const BigActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.color,
    this.foreground,
    this.emphasize = false,
    this.semanticsLabel,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final Color? color;
  final Color? foreground;
  final bool emphasize;
  final String? semanticsLabel;
  final Widget? trailing;

  @override
  State<BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<BigActionButton> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = _focus.hasFocus);
    if (_focus.hasFocus) {
      final AppState app = context.read<AppState>();
      if (app.s.announceOnFocus) {
        final String text = widget.semanticsLabel ?? widget.label;
        app.speak(widget.hint == null ? text : '$text. ${widget.hint}');
      }
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color bg = widget.color ?? scheme.surfaceContainerHighest.withOpacity(0.5);
    final Color fg = widget.foreground ?? scheme.onSurface;
    final Color iconBg = widget.emphasize ? scheme.primary : scheme.primary.withOpacity(0.14);
    final Color iconFg = widget.emphasize ? scheme.onPrimary : scheme.primary;

    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticsLabel ?? widget.label,
      hint: widget.hint ?? 'اضغط مرتين للتنفيذ',
      onTap: widget.onTap,
      child: Focus(
        focusNode: _focus,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: () {
              A11yService.haptic(
                widget.emphasize ? 'double' : 'tap',
                enabled: context.read<AppState>().s.haptics,
              );
              widget.onTap();
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: AppConfig.largeTouchTargetDp),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _focused
                      ? scheme.primary
                      : scheme.outlineVariant.withOpacity(0.7),
                  width: _focused ? 4 : 1.5,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(widget.icon, size: 32, color: iconFg),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.label,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: fg,
                            fontSize: widget.emphasize ? 26 : 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.hint != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            widget.hint!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: fg.withOpacity(0.75),
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  widget.trailing ??
                      Icon(Icons.chevron_left, size: 32, color: fg.withOpacity(0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
