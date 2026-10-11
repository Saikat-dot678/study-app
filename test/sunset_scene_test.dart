import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/appearance/sunset_scene.dart';
import 'package:study_app/appearance/weather_service.dart';

const _kolkata = WeatherCity(
  name: 'Kolkata',
  latitude: 22.57,
  longitude: 88.36,
  country: 'IN',
);
final _now = DateTime.utc(2026, 9, 20, 12);

void main() {
  group('daily phases', () {
    test('default clock moves through all five phases at the boundaries', () {
      expect(phaseAt(0), DayPhase.night);
      expect(phaseAt(4.999), DayPhase.night);
      expect(phaseAt(5), DayPhase.dawn);
      expect(phaseAt(6.999), DayPhase.dawn);
      expect(phaseAt(7), DayPhase.day);
      expect(phaseAt(16.499), DayPhase.day);
      expect(phaseAt(16.5), DayPhase.golden);
      expect(phaseAt(18.249), DayPhase.golden);
      expect(phaseAt(18.25), DayPhase.dusk);
      expect(phaseAt(19.249), DayPhase.dusk);
      expect(phaseAt(19.25), DayPhase.night);
      expect(phaseAt(23.999), DayPhase.night);
    });

    for (final schedule in <String, (double, double)>{
      'Kolkata': (5.4, 17.8),
      'London summer': (4.7, 21.3),
      'Sydney winter': (7.2, 17.1),
    }.entries) {
      test('${schedule.key} follows its supplied sunrise and sunset', () {
        final (sunrise, sunset) = schedule.value;
        DayPhase at(double hour) =>
            phaseAt(hour, sunrise: sunrise, sunset: sunset);
        expect(at(sunrise - 1.001), DayPhase.night);
        expect(at(sunrise - 1), DayPhase.dawn);
        expect(at(sunrise + 1), DayPhase.day);
        expect(at(sunset - 1.501), DayPhase.day);
        expect(at(sunset - 1.5), DayPhase.golden);
        expect(at(sunset + .25), DayPhase.dusk);
        expect(at(sunset + 1.25), DayPhase.night);
      });
    }
  });

  group('season calendars', () {
    test('northern and southern months are six months apart', () {
      const north = [
        StudySeason.winter,
        StudySeason.winter,
        StudySeason.spring,
        StudySeason.spring,
        StudySeason.spring,
        StudySeason.summer,
        StudySeason.summer,
        StudySeason.summer,
        StudySeason.autumn,
        StudySeason.autumn,
        StudySeason.autumn,
        StudySeason.winter,
      ];
      const south = [
        StudySeason.summer,
        StudySeason.summer,
        StudySeason.autumn,
        StudySeason.autumn,
        StudySeason.autumn,
        StudySeason.winter,
        StudySeason.winter,
        StudySeason.winter,
        StudySeason.spring,
        StudySeason.spring,
        StudySeason.spring,
        StudySeason.summer,
      ];
      for (var month = 1; month <= 12; month++) {
        expect(
          seasonAt(month, SeasonCalendar.northern),
          north[month - 1],
          reason: 'Northern month $month',
        );
        expect(
          seasonAt(month, SeasonCalendar.southern),
          south[month - 1],
          reason: 'Southern month $month',
        );
      }
    });

    test('India includes its monsoon and shorter winter', () {
      const expected = [
        StudySeason.winter,
        StudySeason.spring,
        StudySeason.spring,
        StudySeason.summer,
        StudySeason.summer,
        StudySeason.monsoon,
        StudySeason.monsoon,
        StudySeason.monsoon,
        StudySeason.monsoon,
        StudySeason.autumn,
        StudySeason.autumn,
        StudySeason.winter,
      ];
      for (var month = 1; month <= 12; month++) {
        expect(
          seasonAt(month, SeasonCalendar.india),
          expected[month - 1],
          reason: 'India month $month',
        );
      }
    });

    test('saved cities choose the correct season calendar', () {
      expect(_kolkata.calendar, SeasonCalendar.india);
      expect(
        const WeatherCity(
          name: 'Sydney',
          latitude: -33.87,
          longitude: 151.21,
          country: 'AU',
        ).calendar,
        SeasonCalendar.southern,
      );
      expect(
        const WeatherCity(
          name: 'London',
          latitude: 51.5,
          longitude: -.12,
          country: 'GB',
        ).calendar,
        SeasonCalendar.northern,
      );
    });
  });

  group('weather validation', () {
    test('all supported WMO codes map to the intended atmosphere', () {
      const codes = <SkyWeather, List<int>>{
        SkyWeather.clear: [0, 1],
        SkyWeather.clouds: [2, 3],
        SkyWeather.fog: [45, 48],
        SkyWeather.snow: [71, 73, 75, 77, 85, 86],
        SkyWeather.storm: [95, 96, 99],
        SkyWeather.rain: [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82],
      };
      for (final entry in codes.entries) {
        for (final code in entry.value) {
          expect(SkyWeather.fromCode(code), entry.key, reason: 'WMO $code');
        }
      }
      for (final code in [-1, 4, 50, 60, 70, 90, 100]) {
        expect(SkyWeather.fromCode(code), isNull, reason: 'Unknown WMO $code');
      }
    });

    test('city JSON preserves its location and calendar', () {
      final restored = WeatherCity.fromJson(
        jsonDecode(jsonEncode(_kolkata.toJson())) as Map<String, dynamic>,
      );
      expect(restored.name, _kolkata.name);
      expect(restored.key, _kolkata.key);
      expect(restored.calendar, SeasonCalendar.india);
    });

    test('invalid city coordinates and missing identity are rejected', () {
      for (final change in <Map<String, dynamic>>[
        {'latitude': 90.01},
        {'latitude': -90.01},
        {'longitude': 180.01},
        {'longitude': -180.01},
        {'latitude': double.nan},
        {'longitude': double.infinity},
        {'latitude': '22.57'},
        {'name': ''},
        {'name': '   '},
        {'name': null},
      ]) {
        expect(
          () => WeatherCity.fromJson({..._kolkata.toJson(), ...change}),
          throwsA(anything),
          reason: 'Invalid location $change',
        );
      }
    });

    test(
      'forecast epochs stay UTC and location offset is applied only to clock',
      () {
        final weather = LocalWeather.fromForecast(_forecast(), _kolkata, _now);
        expect(weather.observedAt, _now.subtract(const Duration(minutes: 15)));
        expect(weather.observedAt.isUtc, isTrue);
        expect(weather.sunrise, DateTime.utc(2026, 9, 20, 0, 30));
        expect(weather.sunset, DateTime.utc(2026, 9, 20, 12, 30));
        expect(weather.sunrise!.isUtc, isTrue);
        expect(weather.sunset!.isUtc, isTrue);
        expect(weather.clock(_now), DateTime.utc(2026, 9, 20, 17, 30));
        expect(weather.kind, SkyWeather.rain);
        expect(weather.temperature, 28.5);
        expect(weather.isDay, isTrue);
        expect(weather.usable(_kolkata, _now), isTrue);
      },
    );

    test('location clock crosses midnight in either direction', () {
      expect(
        _weather(offset: 19800).clock(DateTime.utc(2026, 12, 31, 22)),
        DateTime.utc(2027, 1, 1, 3, 30),
      );
      expect(
        _weather(offset: -14400).clock(DateTime.utc(2026, 1, 1, 1)),
        DateTime.utc(2025, 12, 31, 21),
      );
    });

    test('missing optional solar data still permits current weather', () {
      final payload = _forecast()..remove('daily');
      final weather = LocalWeather.fromForecast(payload, _kolkata, _now);
      expect(weather.sunrise, isNull);
      expect(weather.sunset, isNull);
      expect(weather.usable(_kolkata, _now), isTrue);
    });

    test(
      'cache JSON round trip retains UTC timestamps and weather identity',
      () {
        final source = LocalWeather.fromForecast(_forecast(), _kolkata, _now);
        final restored = LocalWeather.fromJson(
          jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), source.toJson());
        expect(restored.observedAt.isUtc, isTrue);
        expect(restored.fetchedAt.isUtc, isTrue);
        expect(restored.usable(_kolkata, _now), isTrue);
      },
    );

    test('cached timestamps with explicit offsets normalize to UTC', () {
      final restored = LocalWeather.fromJson({
        ..._weather().toJson(),
        'observed': '2026-09-20T17:30:00+05:30',
        'fetched': '2026-09-20T17:30:00+05:30',
        'sunrise': '2026-09-20T06:00:00+05:30',
        'sunset': '2026-09-20T18:00:00+05:30',
      });
      expect(restored.observedAt, _now);
      expect(restored.fetchedAt, _now);
      expect(restored.observedAt.isUtc, isTrue);
      expect(restored.sunrise, DateTime.utc(2026, 9, 20, 0, 30));
      expect(restored.sunset, DateTime.utc(2026, 9, 20, 12, 30));
      expect(restored.usable(_kolkata, _now), isTrue);
    });

    test('a zero day flag correctly represents nighttime', () {
      final payload = _forecast();
      (payload['current'] as Map<String, dynamic>)['is_day'] = 0;
      expect(LocalWeather.fromForecast(payload, _kolkata, _now).isDay, isFalse);
    });

    test('cache expires at two hours after fetch', () {
      final weather = _weather();
      expect(
        weather.usable(
          _kolkata,
          _now
              .add(const Duration(hours: 2))
              .subtract(const Duration(microseconds: 1)),
        ),
        isTrue,
      );
      expect(
        weather.usable(_kolkata, _now.add(const Duration(hours: 2))),
        isFalse,
      );
    });

    test('freshly fetched data cannot revive a stale observation', () {
      expect(
        _weather(observed: _now.subtract(const Duration(hours: 2)))
            .usable(_kolkata, _now),
        isFalse,
      );
      expect(
        _weather(observed: _now.subtract(const Duration(hours: 3)))
            .usable(_kolkata, _now),
        isFalse,
      );
    });

    test('cache rejects another location or no selected city', () {
      final weather = _weather();
      expect(weather.usable(null, _now), isFalse);
      expect(
        weather.usable(
          const WeatherCity(
            name: 'Nearby',
            latitude: 22.58,
            longitude: 88.36,
            country: 'IN',
          ),
          _now,
        ),
        isFalse,
      );
      expect(
        weather.usable(
          const WeatherCity(
            name: 'Nearby',
            latitude: 22.57,
            longitude: 88.37,
            country: 'IN',
          ),
          _now,
        ),
        isFalse,
      );
    });

    test(
      'future fetch and excessively future observation invalidate cache',
      () {
        expect(
          _weather(fetched: _now.add(const Duration(microseconds: 1)))
              .usable(_kolkata, _now),
          isFalse,
        );
        expect(
          _weather(observed: _now.add(const Duration(minutes: 15)))
              .usable(_kolkata, _now),
          isTrue,
        );
        expect(
          _weather(
            observed: _now.add(const Duration(minutes: 15, microseconds: 1)),
          ).usable(_kolkata, _now),
          isFalse,
        );
      },
    );

    for (final invalid in <String, Map<String, dynamic>>{
      'unknown weather code': {'weather_code': 500},
      'non-numeric temperature': {'temperature_2m': 'warm'},
      'non-finite temperature': {'temperature_2m': double.nan},
      'missing timestamp': {'time': null},
      'stale observation': {
        'time': _epoch(_now.subtract(const Duration(hours: 2))),
      },
      'future observation': {
        'time': _epoch(_now.add(const Duration(minutes: 16))),
      },
      'invalid day flag': {'is_day': 2},
      'missing day flag': {'is_day': null},
    }.entries) {
      test('forecast rejects ${invalid.key}', () {
        final payload = _forecast();
        (payload['current'] as Map<String, dynamic>).addAll(invalid.value);
        expect(
          () => LocalWeather.fromForecast(payload, _kolkata, _now),
          throwsA(anything),
        );
      });
    }

    test(
      'forecast rejects an invalid offset or missing current conditions',
      () {
        expect(
          () => LocalWeather.fromForecast(
            _forecast()..['utc_offset_seconds'] = 15 * 3600,
            _kolkata,
            _now,
          ),
          throwsA(anything),
        );
        expect(
          () => LocalWeather.fromForecast(
            _forecast()..remove('current'),
            _kolkata,
            _now,
          ),
          throwsA(anything),
        );
      },
    );

    for (final invalid in <String, Map<String, dynamic>>{
      'unknown kind': {'kind': 'volcanic'},
      'missing temperature': {'temperature': null},
      'invalid observation date': {'observed': 'yesterday'},
      'invalid fetched date': {'fetched': 'next week'},
      'invalid day flag': {'day': 'yes'},
      'non-finite temperature': {'temperature': double.infinity},
      'out-of-range UTC offset': {'offset': 15 * 3600},
      'empty city identity': {'city': ''},
    }.entries) {
      test('cache rejects ${invalid.key}', () {
        expect(
          () =>
              LocalWeather.fromJson({..._weather().toJson(), ...invalid.value}),
          throwsA(anything),
        );
      });
    }
  });

  test(
    'text and primary buttons retain AA contrast across 150 scene combinations',
    () {
      var combinations = 0;
      for (final phase in DayPhase.values) {
        for (final season in StudySeason.values) {
          for (final weather in SkyWeather.values) {
            final scene = SunsetScene(
              phase: phase,
              season: season,
              weather: weather,
            );
            final palette = scene.palette;
            final label = '${phase.name}/${season.name}/${weather.name}';
            expect(
              _contrast(palette.ink, palette.background),
              greaterThanOrEqualTo(4.5),
              reason: '$label body text',
            );
            expect(
              _contrast(palette.muted, palette.background),
              greaterThanOrEqualTo(4.5),
              reason: '$label secondary text',
            );
            expect(
              _contrast(palette.onAccent, palette.accent),
              greaterThanOrEqualTo(4.5),
              reason: '$label button text',
            );
            expect(palette.sky, hasLength(3));
            expect(palette.hills, hasLength(3));
            combinations++;
          }
        }
      }
      expect(combinations, 150);
    },
  );
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

int _epoch(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> _forecast() => {
  'utc_offset_seconds': 19800,
  'current': <String, dynamic>{
    'weather_code': 63,
    'temperature_2m': 28.5,
    'time': _epoch(_now.subtract(const Duration(minutes: 15))),
    'is_day': 1,
  },
  'daily': <String, dynamic>{
    'sunrise': [_epoch(DateTime.utc(2026, 9, 20, 0, 30))],
    'sunset': [_epoch(DateTime.utc(2026, 9, 20, 12, 30))],
  },
};

LocalWeather _weather({
  DateTime? observed,
  DateTime? fetched,
  int offset = 19800,
}) => LocalWeather(
  cityKey: _kolkata.key,
  kind: SkyWeather.clear,
  temperature: 28,
  observedAt: observed ?? _now,
  fetchedAt: fetched ?? _now,
  utcOffset: offset,
  isDay: true,
);
