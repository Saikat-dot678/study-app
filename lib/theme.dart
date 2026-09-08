import 'package:flutter/material.dart';

/// Study's "quiet editorial" visual system.
///
/// Neutral paper/ink surfaces keep long reading and planning sessions calm;
/// indigo carries primary actions and coral is reserved for urgency/progress.
class AppTheme {
  static const _indigo = Color(0xFF4D55CC);

  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: _indigo,
      brightness: Brightness.light,
    );
    return _build(
      base.copyWith(
        primary: const Color(0xFF4650C7),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE3E5FF),
        onPrimaryContainer: const Color(0xFF20266F),
        secondary: const Color(0xFF236B63),
        secondaryContainer: const Color(0xFFD4F3EC),
        tertiary: const Color(0xFFC45645),
        tertiaryContainer: const Color(0xFFFFDDD7),
        surface: const Color(0xFFF5F5F2),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFFAFAF7),
        surfaceContainer: const Color(0xFFF0F0EC),
        surfaceContainerHigh: const Color(0xFFE8E8E3),
        surfaceContainerHighest: const Color(0xFFDEDED8),
        onSurface: const Color(0xFF202124),
        onSurfaceVariant: const Color(0xFF62636A),
        outline: const Color(0xFF8B8C94),
        outlineVariant: const Color(0xFFD6D6D1),
      ),
      dark: false,
    );
  }

  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFAEB2FF),
      brightness: Brightness.dark,
    );
    return _build(
      base.copyWith(
        primary: const Color(0xFFB7BAFF),
        onPrimary: const Color(0xFF242A78),
        primaryContainer: const Color(0xFF343B8D),
        onPrimaryContainer: const Color(0xFFE1E2FF),
        secondary: const Color(0xFF84D5C8),
        secondaryContainer: const Color(0xFF174E48),
        tertiary: const Color(0xFFFFB4A7),
        tertiaryContainer: const Color(0xFF71372F),
        surface: const Color(0xFF151619),
        surfaceContainerLowest: const Color(0xFF1B1C20),
        surfaceContainerLow: const Color(0xFF202125),
        surfaceContainer: const Color(0xFF26272B),
        surfaceContainerHigh: const Color(0xFF303136),
        surfaceContainerHighest: const Color(0xFF3A3B40),
        onSurface: const Color(0xFFE8E8E8),
        onSurfaceVariant: const Color(0xFFB9BAC1),
        outline: const Color(0xFF8E9099),
        outlineVariant: const Color(0xFF3D3E44),
      ),
      dark: true,
    );
  }

  static ThemeData _build(ColorScheme scheme, {required bool dark}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );
    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          height: 1.04,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.05,
          height: 1.08,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainerLowest,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFF0F0F0) : const Color(0xFF25262A),
          borderRadius: BorderRadius.circular(7),
        ),
        textStyle: TextStyle(
          color: dark ? const Color(0xFF202124) : Colors.white,
          fontSize: 12,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        foregroundColor: scheme.onPrimary,
        backgroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerColor: scheme.outlineVariant,
    );
  }
}
