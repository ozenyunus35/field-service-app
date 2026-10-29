import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Design tokens shared with the other demos: neutral greys and one indigo accent.
@immutable
class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color bg, surface, surface2, border, text, muted, faint, accent, accentSoft, onAccent, success, warning, danger;

  static const light = Tokens(
    bg: Color(0xFFFBFBFC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F3F5),
    border: Color(0xFFE4E4E8),
    text: Color(0xFF17181C),
    muted: Color(0xFF6B6E76),
    faint: Color(0xFF9A9DA5),
    accent: Color(0xFF5B5BD6),
    accentSoft: Color(0xFFEEEEFB),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF2F8A5B),
    warning: Color(0xFFA86A12),
    danger: Color(0xFFC94545),
  );

  static const dark = Tokens(
    bg: Color(0xFF0C0D0F),
    surface: Color(0xFF131417),
    surface2: Color(0xFF1B1C20),
    border: Color(0xFF26272B),
    text: Color(0xFFEDEDEF),
    muted: Color(0xFF8B8D98),
    faint: Color(0xFF5F616B),
    accent: Color(0xFF7C82EE),
    accentSoft: Color(0xFF1E1F33),
    onAccent: Color(0xFF0C0D0F),
    success: Color(0xFF5FB889),
    warning: Color(0xFFD6A54A),
    danger: Color(0xFFE36A6A),
  );

  @override
  Tokens copyWith() => this;

  @override
  Tokens lerp(ThemeExtension<Tokens>? other, double t) {
    if (other is! Tokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Tokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      border: l(border, other.border),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
    );
  }
}

extension TokensX on BuildContext {
  Tokens get t => Theme.of(this).extension<Tokens>()!;
}

ThemeData buildTheme(Brightness b) {
  final t = b == Brightness.light ? Tokens.light : Tokens.dark;
  final base = ThemeData(brightness: b, useMaterial3: true, fontFamily: 'Inter');
  final text = base.textTheme.apply(bodyColor: t.text, displayColor: t.text);
  final radius = BorderRadius.circular(8);
  return base.copyWith(
    extensions: [t],
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    dividerColor: t.border,
    splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: b,
    ).copyWith(primary: t.accent, onPrimary: t.onAccent, surface: t.surface, onSurface: t.text, outline: t.border, outlineVariant: t.border, error: t.danger),
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.6, height: 1.15),
      titleLarge: text.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.15),
      titleSmall: text.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12.5, color: t.muted, height: 1.35),
      labelLarge: text.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: text.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, color: t.text, letterSpacing: -0.2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: t.accentSoft,
      height: 64,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w500, color: s.contains(WidgetState.selected) ? t.text : t.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 20, color: s.contains(WidgetState.selected) ? t.accent : t.muted)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        disabledBackgroundColor: t.surface2,
        disabledForegroundColor: t.faint,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.border),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.accent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(color: t.faint),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.accent, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.text,
      contentTextStyle: TextStyle(fontFamily: 'Inter', color: t.bg, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: radius),
      insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: t.border,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onAccent : t.faint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accent : t.surface2),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accent : t.border),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: t.faint, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accent : Colors.transparent),
      checkColor: WidgetStatePropertyAll(t.onAccent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: t.surface,
        selectedBackgroundColor: t.accentSoft,
        selectedForegroundColor: t.text,
        foregroundColor: t.muted,
        side: BorderSide(color: t.border),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
