import 'package:flutter/material.dart';

/// Фирменные цвета из UI-kit (макет Figma) — одинаковые в светлой и тёмной теме.
class AppColors {
  static const dark = Color(0xFF0F3D3E);
  static const teal = Color(0xFF2EC4B6);
  static const coral = Color(0xFFFF7A59);
  static const yellow = Color(0xFFF5B700);

  /// Палитра для категорий.
  static const categoryPalette = [
    teal, coral, yellow, dark, Color(0xFF7C6FE0), Color(0xFF4A90D9), Color(0xFFE05A8A), Color(0xFFB9CCCA),
  ];
}

/// Нейтральные цвета, которые меняются вместе с темой (ФТ-16).
/// В виджетах берутся так: `context.pal.ink`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.tealLight,
    required this.checkbox,
    required this.strong,
    required this.onTealLight,
  });

  final Color bg; // фон экранов
  final Color card; // карточки, поля, нижняя панель
  final Color ink; // основной текст
  final Color muted; // второстепенный текст, иконки
  final Color line; // рамки и разделители
  final Color tealLight; // светлая подложка активных элементов
  final Color checkbox; // рамка пустого чекбокса, «Без категории»
  final Color strong; // выбранный чип, переключатель, выбранный день
  final Color onTealLight; // текст на подложке tealLight

  static const light = AppPalette(
    bg: Color(0xFFF1F6F5),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF12292B),
    muted: Color(0xFF6B7F80),
    line: Color(0xFFD5E3E1),
    tealLight: Color(0xFFE3F6F4),
    checkbox: Color(0xFFB9CCCA),
    strong: Color(0xFF0F3D3E),
    onTealLight: Color(0xFF0F3D3E),
  );

  static const darkPalette = AppPalette(
    bg: Color(0xFF0D1919),
    card: Color(0xFF172526),
    ink: Color(0xFFE4EEED),
    muted: Color(0xFF8FA5A4),
    line: Color(0xFF2B3D3E),
    tealLight: Color(0xFF133B38),
    checkbox: Color(0xFF4E6566),
    strong: Color(0xFF1F7069),
    onTealLight: Color(0xFF8BE3D9),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? card,
    Color? ink,
    Color? muted,
    Color? line,
    Color? tealLight,
    Color? checkbox,
    Color? strong,
    Color? onTealLight,
  }) =>
      AppPalette(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        tealLight: tealLight ?? this.tealLight,
        checkbox: checkbox ?? this.checkbox,
        strong: strong ?? this.strong,
        onTealLight: onTealLight ?? this.onTealLight,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      tealLight: Color.lerp(tealLight, other.tealLight, t)!,
      checkbox: Color.lerp(checkbox, other.checkbox, t)!,
      strong: Color.lerp(strong, other.strong, t)!,
      onTealLight: Color.lerp(onTealLight, other.onTealLight, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

Color colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x2EC4B6;
  return Color(0xFF000000 | value);
}

String colorToHex(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final p = isDark ? AppPalette.darkPalette : AppPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
    primary: isDark ? AppColors.teal : AppColors.dark,
    secondary: AppColors.teal,
    tertiary: AppColors.coral,
    surface: p.card,
    onSurface: p.ink,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.card,
    dividerColor: p.line,
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(p.line),
      enabledBorder: border(p.line),
      focusedBorder: border(AppColors.teal, 1.6),
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.coral,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.tealLight,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? p.onTealLight : p.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.onTealLight : p.muted,
          )),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent, dragHandleColor: p.line),
    popupMenuTheme: PopupMenuThemeData(color: p.card, surfaceTintColor: Colors.transparent),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.checkbox),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.teal : p.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
