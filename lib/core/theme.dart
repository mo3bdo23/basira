import 'package:flutter/material.dart';

/// لغة التصميم: أخضر داكن عالي التباين + خلفيات صلبة + خطوط كبيرة.
/// كل الألوان مُختبرة لتحقيق نسبة تباين ≥ 4.5:1 مع النص.
class BasiraTheme {
  const BasiraTheme._();

  static const Color primary = Color(0xFF0B6B3A);
  static const Color primaryDark = Color(0xFF064A28);
  static const Color accent = Color(0xFFF5A524);
  static const Color danger = Color(0xFFB3261E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF101613);

  // الوضع عالي التباين (أصفر على أسود) — مطلوب لضعاف البصر.
  static const Color hcBackground = Color(0xFF000000);
  static const Color hcForeground = Color(0xFFFFEB3B);

  static ThemeData light() => _base(
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: accent,
          error: danger,
          surface: surface,
        ),
        Brightness.light,
      );

  static ThemeData dark() => _base(
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF5BD08D),
          secondary: accent,
          error: const Color(0xFFFF8A80),
        ),
        Brightness.dark,
      );

  static ThemeData highContrast() {
    return _base(
      const ColorScheme.highContrastLight(primary: hcForeground, secondary: hcForeground)
          .copyWith(
        primary: hcForeground,
        onPrimary: hcBackground,
        surface: hcBackground,
        onSurface: hcForeground,
        secondary: hcForeground,
        onSecondary: hcBackground,
        error: const Color(0xFFFF5252),
        onError: hcBackground,
      ),
      Brightness.dark,
      forceBackground: hcBackground,
      forceForeground: hcForeground,
    );
  }

  static ThemeData _base(
    ColorScheme scheme,
    Brightness brightness, {
    Color? forceBackground,
    Color? forceForeground,
  }) {
    final Color bg = forceBackground ?? scheme.surface;
    final Color fg = forceForeground ?? scheme.onSurface;
    const TextTheme text = TextTheme(
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.2),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.2),
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.25),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.3),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.35),
      titleMedium: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, height: 1.5),
      bodyMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.5),
      labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: text.apply(bodyColor: fg, displayColor: fg),
      fontFamilyFallback: const ['Tajawal', 'Cairo', 'Noto Naskh Arabic', 'Segoe UI'],
      visualDensity: VisualDensity.comfortable,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 72,
        titleTextStyle: text.titleLarge?.copyWith(color: fg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 64),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size(double.infinity, 64),
          side: BorderSide(color: scheme.primary, width: 2.5),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(80, 56),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        labelStyle: text.titleMedium,
        hintStyle: text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 3),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 10,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 16),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 34),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.surfaceContainerHighest,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1.5),
    );
  }
}
