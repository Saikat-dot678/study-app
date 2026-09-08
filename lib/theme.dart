import 'package:flutter/material.dart';

@immutable
class StudyColors extends ThemeExtension<StudyColors> {
  const StudyColors({
    required this.ambientStart,
    required this.ambientEnd,
    required this.ambientAccent,
    required this.pdf,
    required this.slides,
    required this.note,
    required this.document,
    required this.sheet,
    required this.audio,
    required this.video,
    required this.image,
    required this.folder,
    required this.research,
    required this.exam,
    required this.project,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color ambientStart;
  final Color ambientEnd;
  final Color ambientAccent;
  final Color pdf;
  final Color slides;
  final Color note;
  final Color document;
  final Color sheet;
  final Color audio;
  final Color video;
  final Color image;
  final Color folder;
  final Color research;
  final Color exam;
  final Color project;
  final Color success;
  final Color warning;
  final Color danger;

  static StudyColors of(BuildContext context) =>
      Theme.of(context).extension<StudyColors>()!;

  @override
  StudyColors copyWith({
    Color? ambientStart,
    Color? ambientEnd,
    Color? ambientAccent,
    Color? pdf,
    Color? slides,
    Color? note,
    Color? document,
    Color? sheet,
    Color? audio,
    Color? video,
    Color? image,
    Color? folder,
    Color? research,
    Color? exam,
    Color? project,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return StudyColors(
      ambientStart: ambientStart ?? this.ambientStart,
      ambientEnd: ambientEnd ?? this.ambientEnd,
      ambientAccent: ambientAccent ?? this.ambientAccent,
      pdf: pdf ?? this.pdf,
      slides: slides ?? this.slides,
      note: note ?? this.note,
      document: document ?? this.document,
      sheet: sheet ?? this.sheet,
      audio: audio ?? this.audio,
      video: video ?? this.video,
      image: image ?? this.image,
      folder: folder ?? this.folder,
      research: research ?? this.research,
      exam: exam ?? this.exam,
      project: project ?? this.project,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  StudyColors lerp(covariant StudyColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return StudyColors(
      ambientStart: mix(ambientStart, other.ambientStart),
      ambientEnd: mix(ambientEnd, other.ambientEnd),
      ambientAccent: mix(ambientAccent, other.ambientAccent),
      pdf: mix(pdf, other.pdf),
      slides: mix(slides, other.slides),
      note: mix(note, other.note),
      document: mix(document, other.document),
      sheet: mix(sheet, other.sheet),
      audio: mix(audio, other.audio),
      video: mix(video, other.video),
      image: mix(image, other.image),
      folder: mix(folder, other.folder),
      research: mix(research, other.research),
      exam: mix(exam, other.exam),
      project: mix(project, other.project),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => lightFor(const DateTime(2026, 6, 15, 12));
  static ThemeData get dark => darkFor(const DateTime(2026, 6, 15, 21));

  static ThemeData lightFor(DateTime now) => _build(now, dark: false);
  static ThemeData darkFor(DateTime now) => _build(now, dark: true);

  static ThemeData _build(DateTime now, {required bool dark}) {
    final palette = _adaptivePalette(now, dark: dark);
    final scheme = dark ? _darkScheme(palette) : _lightScheme(palette);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      extensions: [palette],
    );
    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.45,
          height: 1.02,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.15,
          height: 1.04,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.72,
          height: 1.08,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.28,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: scheme.surfaceContainerLowest,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
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
          borderRadius: BorderRadius.circular(9),
        ),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 420),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFF3F5F8) : const Color(0xFF20262E),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: dark ? const Color(0xFF1B232D) : Colors.white,
          fontSize: 12,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 3,
        foregroundColor: scheme.onPrimary,
        backgroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerColor: scheme.outlineVariant,
    );
  }

  static ColorScheme _lightScheme(StudyColors palette) {
    return ColorScheme.fromSeed(
      seedColor: palette.ambientAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF155EEF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDCE8FF),
      onPrimaryContainer: const Color(0xFF0D3376),
      secondary: const Color(0xFF087D69),
      secondaryContainer: const Color(0xFFD9F5EC),
      tertiary: const Color(0xFFD84A2F),
      tertiaryContainer: const Color(0xFFFFE2D9),
      surface: const Color(0xFFF5F7FA),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFAFBFC),
      surfaceContainer: const Color(0xFFF0F3F7),
      surfaceContainerHigh: const Color(0xFFE8ECF2),
      surfaceContainerHighest: const Color(0xFFDDE3EB),
      onSurface: const Color(0xFF17202A),
      onSurfaceVariant: const Color(0xFF5D6978),
      outline: const Color(0xFF8995A5),
      outlineVariant: const Color(0xFFD6DCE5),
    );
  }

  static ColorScheme _darkScheme(StudyColors palette) {
    return ColorScheme.fromSeed(
      seedColor: palette.ambientAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF8FB8FF),
      onPrimary: const Color(0xFF071B3F),
      primaryContainer: const Color(0xFF173C73),
      onPrimaryContainer: const Color(0xFFDCE8FF),
      secondary: const Color(0xFF62D6B5),
      secondaryContainer: const Color(0xFF123F35),
      tertiary: const Color(0xFFFF9A76),
      tertiaryContainer: const Color(0xFF5D2C20),
      surface: const Color(0xFF111419),
      surfaceContainerLowest: const Color(0xFF171B21),
      surfaceContainerLow: const Color(0xFF1C2128),
      surfaceContainer: const Color(0xFF222831),
      surfaceContainerHigh: const Color(0xFF2B323C),
      surfaceContainerHighest: const Color(0xFF343C47),
      onSurface: const Color(0xFFF2F4F8),
      onSurfaceVariant: const Color(0xFFB8C0CC),
      outline: const Color(0xFF747F8D),
      outlineVariant: const Color(0xFF333B46),
    );
  }

  static StudyColors _adaptivePalette(DateTime now, {required bool dark}) {
    final accents = switch (_season(now.month)) {
      _Season.spring => const [Color(0xFF18A66A), Color(0xFF2D7FF9)],
      _Season.summer => const [Color(0xFF008E9B), Color(0xFF1677FF)],
      _Season.monsoon => const [Color(0xFF087F8C), Color(0xFF315CEB)],
      _Season.autumn => const [Color(0xFFE17018), Color(0xFFB84061)],
      _Season.winter => const [Color(0xFF3973D7), Color(0xFF7557D3)],
    };
    final mood = switch (_dayPart(now.hour)) {
      _DayPart.dawn => dark ? const Color(0xFF263044) : const Color(0xFFEFF4FF),
      _DayPart.morning => dark ? const Color(0xFF172B36) : const Color(0xFFF5FAFF),
      _DayPart.day => dark ? const Color(0xFF161C26) : const Color(0xFFF7F9FC),
      _DayPart.evening => dark ? const Color(0xFF251B2B) : const Color(0xFFFFF5EF),
      _DayPart.night => dark ? const Color(0xFF121724) : const Color(0xFFF1F4FA),
      _DayPart.deepNight => dark ? const Color(0xFF0C111A) : const Color(0xFFEFF3F8),
    };
    return StudyColors(
      ambientStart: mood,
      ambientEnd: Color.lerp(mood, accents[0], dark ? 0.16 : 0.07)!,
      ambientAccent: accents[1],
      pdf: const Color(0xFFE5484D),
      slides: const Color(0xFFF07B24),
      note: const Color(0xFF1598D2),
      document: const Color(0xFF3B6FD8),
      sheet: const Color(0xFF159B67),
      audio: const Color(0xFFD84D9B),
      video: const Color(0xFF7656D6),
      image: const Color(0xFF2F9E76),
      folder: accents[1],
      research: const Color(0xFF008C7A),
      exam: const Color(0xFF7A52D1),
      project: const Color(0xFFE36A2E),
      success: const Color(0xFF159B67),
      warning: const Color(0xFFE69B18),
      danger: const Color(0xFFE5484D),
    );
  }

  static _Season _season(int month) => switch (month) {
    2 || 3 => _Season.spring,
    4 || 5 || 6 => _Season.summer,
    7 || 8 || 9 => _Season.monsoon,
    10 || 11 => _Season.autumn,
    _ => _Season.winter,
  };

  static _DayPart _dayPart(int hour) => switch (hour) {
    >= 5 && < 7 => _DayPart.dawn,
    >= 7 && < 11 => _DayPart.morning,
    >= 11 && < 16 => _DayPart.day,
    >= 16 && < 19 => _DayPart.evening,
    >= 19 && < 23 => _DayPart.night,
    _ => _DayPart.deepNight,
  };
}

enum _Season { spring, summer, monsoon, autumn, winter }
enum _DayPart { dawn, morning, day, evening, night, deepNight }
