import 'package:flutter/material.dart';

import '../services/a11y_service.dart';

/// هيكل موحّد للشاشات: عنوان كبير، زر رجوع واضح، وإعلان صوتي للعنوان.
class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.speakTitle = true,
    this.bottomBar,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool speakTitle;
  final Widget? bottomBar;
  final EdgeInsets padding;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  @override
  void initState() {
    super.initState();
    if (widget.speakTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        A11yService.announce(
          widget.subtitle == null ? widget.title : '${widget.title}. ${widget.subtitle}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: Semantics(
          button: true,
          label: 'رجوع',
          child: IconButton(
            iconSize: 32,
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(widget.title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: widget.actions,
      ),
      body: SafeArea(
        child: Padding(padding: widget.padding, child: widget.body),
      ),
      bottomNavigationBar: widget.bottomBar,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
