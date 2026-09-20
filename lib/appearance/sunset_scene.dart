import 'package:flutter/material.dart';

enum DayPhase {
  dawn('First light'),
  day('Daylight'),
  golden('Golden hour'),
  dusk('Blue hour'),
  night('Moonlit hours');

  const DayPhase(this.label);
  final String label;
}

enum StudySeason {
  spring('Spring'),
  summer('Summer'),
  monsoon('Monsoon'),
  autumn('Autumn'),
  winter('Winter');

  const StudySeason(this.label);
  final String label;
}

enum SeasonCalendar { northern, southern, india }

enum SkyWeather {
  clear('Clear sky'),
  clouds('Cloudy'),
  rain('Rain'),
  fog('Mist'),
  snow('Snow'),
  storm('Rainstorm');

  const SkyWeather(this.label);
  final String label;

  static SkyWeather? fromCode(int code) => switch (code) {
    0 || 1 => clear,
    2 || 3 => clouds,
    45 || 48 => fog,
    71 || 73 || 75 || 77 || 85 || 86 => snow,
    95 || 96 || 99 => storm,
    51 ||
    53 ||
    55 ||
    56 ||
    57 ||
    61 ||
    63 ||
    65 ||
    66 ||
    67 ||
    80 ||
    81 ||
    82 => rain,
    _ => null,
  };
}

DayPhase phaseAt(double hour, {double sunrise = 6, double sunset = 18}) {
  if (hour < sunrise - 1 || hour >= sunset + 1.25) return DayPhase.night;
  if (hour < sunrise + 1) return DayPhase.dawn;
  if (hour < sunset - 1.5) return DayPhase.day;
  if (hour < sunset + .25) return DayPhase.golden;
  return DayPhase.dusk;
}

StudySeason seasonAt(int month, SeasonCalendar calendar) {
  if (calendar == SeasonCalendar.india) {
    if (month >= 6 && month <= 9) return StudySeason.monsoon;
    if (month >= 10 && month <= 11) return StudySeason.autumn;
    if (month == 12 || month == 1) return StudySeason.winter;
    return month <= 3 ? StudySeason.spring : StudySeason.summer;
  }
  if (calendar == SeasonCalendar.southern) month = (month + 5) % 12 + 1;
  return switch (month) {
    >= 3 && <= 5 => StudySeason.spring,
    >= 6 && <= 8 => StudySeason.summer,
    >= 9 && <= 11 => StudySeason.autumn,
    _ => StudySeason.winter,
  };
}

class SunsetScene {
  const SunsetScene({
    required this.phase,
    required this.season,
    this.weather = SkyWeather.clear,
    this.hour = 17,
  });
  final DayPhase phase;
  final StudySeason season;
  final SkyWeather weather;
  final double hour;
  bool get dark => phase == DayPhase.dusk || phase == DayPhase.night;
  SunsetPalette get palette => SunsetPalette(this);
}

class SunsetPalette {
  SunsetPalette(this.scene);
  final SunsetScene scene;
  Color _c(int value) => Color(0xff000000 | value);
  List<int> get _base => switch (scene.phase) {
    DayPhase.dawn => [
      0xf6e8e3,
      0xeddbd6,
      0xfff4ec,
      0xe5cdd0,
      0x49333d,
      0x775862,
      0x994e54,
      0x62618a,
    ],
    DayPhase.day => [
      0xf7eee2,
      0xece0cf,
      0xfff9ee,
      0xe7d7bf,
      0x493b32,
      0x74634f,
      0x905335,
      0x546856,
    ],
    DayPhase.golden => [
      0xf6e7dc,
      0xefdbce,
      0xfff3e9,
      0xe5cbbb,
      0x4c3338,
      0x76565c,
      0x9d4d45,
      0x626293,
    ],
    DayPhase.dusk => [
      0x2b293e,
      0x242135,
      0x373149,
      0x494057,
      0xf7e9e3,
      0xc4b4c6,
      0xedb19b,
      0xc2b7e3,
    ],
    DayPhase.night => [
      0x211e31,
      0x1b1929,
      0x2c283e,
      0x3e354b,
      0xf3e8e6,
      0xbdb0c8,
      0xeab99f,
      0xbdb6eb,
    ],
  };
  Color get wash => _c(switch (scene.season) {
    StudySeason.spring => 0xe2e8d7,
    StudySeason.summer => 0xffe7bd,
    StudySeason.monsoon => 0xb8c9c5,
    StudySeason.autumn => 0xefc2a6,
    StudySeason.winter => 0xd8deef,
  });
  Color get background =>
      Color.lerp(_c(_base[0]), wash, scene.dark ? 0.045 : 0.24)!;
  Color get sidebar =>
      Color.lerp(_c(_base[1]), wash, scene.dark ? 0.04 : 0.28)!;
  Color get surface =>
      Color.lerp(_c(_base[2]), wash, scene.dark ? 0.04 : 0.18)!;
  Color get elevated =>
      Color.lerp(_c(_base[3]), wash, scene.dark ? 0.07 : 0.26)!;
  Color get ink => _c(_base[4]);
  Color get muted => _c(_base[5]);
  Color get accent => _c(_base[6]);
  Color get secondary => _c(_base[7]);
  Color get onAccent => _c(scene.dark ? 0x302536 : 0xfff8ee);
  List<Color> get hills =>
      (switch (scene.season) {
            StudySeason.spring => [0xb6b68f, 0x8b9b83, 0x666d79],
            StudySeason.summer => [0xca9570, 0xa27573, 0x716582],
            StudySeason.monsoon => [0x93a6a0, 0x668786, 0x4e6676],
            StudySeason.autumn => [0xbd805c, 0x985f60, 0x665475],
            StudySeason.winter => [0xd5c8c5, 0xa8a3b5, 0x7d829e],
          })
          .map((v) => scene.dark ? Color.lerp(_c(v), background, .4)! : _c(v))
          .toList();
  List<Color> get sky {
    final colors = switch (scene.phase) {
      DayPhase.dawn => [0xc3abc9, 0xefb9aa, 0xffe1ae],
      DayPhase.day => [0xa9c9cc, 0xd6dfc5, 0xffe6ad],
      DayPhase.golden => [0xedab82, 0xf2d19e, 0xdfad94],
      DayPhase.dusk => [0x484b78, 0xa87c9c, 0xefb399],
      DayPhase.night => [0x232740, 0x43466d, 0x81738f],
    };
    final tint = switch (scene.weather) {
      SkyWeather.storm => _c(0x656879),
      SkyWeather.rain || SkyWeather.clouds => _c(0xaeb8c3),
      SkyWeather.fog || SkyWeather.snow => _c(0xd2d5df),
      _ => wash,
    };
    return colors
        .map(
          (v) => Color.lerp(
            _c(v),
            tint,
            scene.weather == SkyWeather.clear
                ? 0.09
                : scene.dark
                ? 0.18
                : 0.4,
          )!,
        )
        .toList();
  }
}
