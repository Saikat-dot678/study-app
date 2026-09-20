import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_app/appearance/appearance_controller.dart';
import 'package:study_app/appearance/sunset_scene.dart';
import 'package:study_app/appearance/weather_service.dart';

const _kolkata = WeatherCity(
  name: 'Kolkata',
  latitude: 22.57,
  longitude: 88.36,
  country: 'IN',
);
const _sydney = WeatherCity(
  name: 'Sydney',
  latitude: -33.87,
  longitude: 151.21,
  country: 'AU',
);
final _noon = DateTime.utc(2026, 9, 20, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'weather is optional and first launch works without any request',
    () async {
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();
      await controller.refreshWeather(force: true);

      expect(controller.followDay, isTrue);
      expect(controller.weatherEnabled, isFalse);
      expect(controller.city, isNull);
      expect(controller.hasWeather, isFalse);
      expect(controller.localTime, _noon);
      expect(controller.scene().phase, DayPhase.day);
      expect(controller.scene().season, StudySeason.autumn);
      expect(controller.scene().weather, SkyWeather.clear);
      expect(controller.weatherStatus, contains('offline'));
      expect(source.requests, isEmpty);
      expect(source.searches, isEmpty);
    },
  );

  test(
    'saved appearance and reduced motion restore without enabling weather',
    () async {
      _seed(
        settings: {
          'followDay': false,
          'reduceMotion': true,
          'mode': 'dark',
          'calendar': 'india',
          'season': 'winter',
          'weather': false,
        },
      );
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();

      expect(controller.followDay, isFalse);
      expect(controller.reduceMotion, isTrue);
      expect(controller.mode, ThemeMode.dark);
      expect(controller.calendar, SeasonCalendar.india);
      expect(controller.scene().season, StudySeason.winter);
      expect(controller.scene().phase, DayPhase.night);
      expect(controller.weatherEnabled, isFalse);
      expect(source.requests, isEmpty);
    },
  );

  test(
    'an enabled flag without a selected city cannot start weather requests',
    () async {
      _seed(settings: {'weather': true});
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();
      expect(controller.weatherEnabled, isFalse);
      expect(source.requests, isEmpty);
    },
  );

  test(
    'corrupt settings fall back as one complete default configuration',
    () async {
      _seed(
        settings: {
          'followDay': false,
          'reduceMotion': true,
          'mode': 'no-such-mode',
          'calendar': 'india',
          'weather': true,
          'city': _kolkata.toJson(),
        },
      );
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();

      expect(controller.followDay, isTrue);
      expect(controller.reduceMotion, isFalse);
      expect(controller.mode, ThemeMode.system);
      expect(controller.calendar, SeasonCalendar.northern);
      expect(controller.weatherEnabled, isFalse);
      expect(controller.city, isNull);
      expect(controller.error, contains('could not be loaded'));
      expect(source.requests, isEmpty);
    },
  );

  test(
    'preference changes round trip while temporary previews are never saved',
    () async {
      final controller = _controller(_FakeWeatherSource());
      await controller.initialize();
      controller.setPreviewHour(2);
      controller.setPreviewWeather(SkyWeather.snow);
      expect(
        await controller.update(
          follow: false,
          reduced: true,
          theme: ThemeMode.dark,
          seasonCalendar: SeasonCalendar.southern,
          season: StudySeason.summer,
        ),
        isTrue,
      );

      final restored = _controller(_FakeWeatherSource());
      await restored.initialize();
      expect(restored.followDay, isFalse);
      expect(restored.reduceMotion, isTrue);
      expect(restored.mode, ThemeMode.dark);
      expect(restored.calendar, SeasonCalendar.southern);
      expect(restored.seasonOverride, StudySeason.summer);
      expect(restored.previewing, isFalse);
      expect(restored.previewHour, isNull);
      expect(restored.previewWeather, isNull);
      expect(restored.scene().weather, SkyWeather.clear);

      await restored.update(useCalendar: true);
      expect(restored.seasonOverride, isNull);
      expect(restored.scene().season, StudySeason.spring);
    },
  );

  test(
    'an edit during initialization wins over previously saved settings',
    () async {
      _seed(
        settings: {'followDay': true, 'mode': 'light', 'reduceMotion': false},
      );
      final controller = _controller(_FakeWeatherSource());
      final initializing = controller.initialize();
      await controller.update(
        follow: false,
        theme: ThemeMode.dark,
        reduced: true,
      );
      await initializing;
      expect(controller.followDay, isFalse);
      expect(controller.mode, ThemeMode.dark);
      expect(controller.reduceMotion, isTrue);
    },
  );

  test(
    'fresh cache uses the selected city clock and avoids an immediate request',
    () async {
      _seed(settings: _enabledSettings(), weather: _weather());
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();

      expect(controller.hasWeather, isTrue);
      expect(controller.localTime, DateTime.utc(2026, 9, 20, 17, 30));
      expect(controller.scene().phase, DayPhase.golden);
      expect(controller.scene().season, StudySeason.monsoon);
      expect(controller.scene().weather, SkyWeather.rain);
      expect(controller.weatherStatus, contains('Kolkata'));
      expect(source.requests, isEmpty);
    },
  );

  test(
    'stale cache and failed refresh fall back to local clock and clear weather',
    () async {
      _seed(
        settings: _enabledSettings(),
        weather: _weather(
          observed: _noon.subtract(const Duration(hours: 3)),
          fetched: _noon.subtract(const Duration(hours: 3)),
        ),
      );
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();

      expect(source.requests, hasLength(1));
      expect(controller.hasWeather, isFalse);
      expect(controller.localTime, _noon);
      expect(controller.scene().phase, DayPhase.day);
      expect(controller.scene().weather, SkyWeather.clear);
      source.requests.single.result.completeError(StateError('Offline'));
      await _settle();
      expect(controller.busy, isFalse);
      expect(controller.error, contains('Could not refresh'));
      expect(controller.hasWeather, isFalse);
      expect(controller.scene().weather, SkyWeather.clear);
      await controller.refreshWeather();
      expect(
        source.requests,
        hasLength(1),
        reason: 'Offline retries are throttled.',
      );
    },
  );

  test(
    'cache for another city is ignored and cannot shift the local clock',
    () async {
      _seed(
        settings: _enabledSettings(),
        weather: _weather(city: _sydney),
      );
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();
      expect(controller.hasWeather, isFalse);
      expect(controller.localTime, _noon);
      expect(controller.scene().weather, SkyWeather.clear);
      source.requests.single.result.completeError(StateError('Offline'));
      await _settle();
    },
  );

  test('malformed weather cache preserves valid appearance settings', () async {
    _seed(settings: {..._enabledSettings(), 'reduceMotion': true});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppearanceController.weatherKey, '{broken json');
    final source = _FakeWeatherSource();
    final controller = _controller(source);
    await controller.initialize();
    expect(controller.reduceMotion, isTrue);
    expect(controller.city?.key, _kolkata.key);
    expect(controller.weather, isNull);
    expect(controller.hasWeather, isFalse);
    source.requests.single.result.completeError(StateError('Offline'));
    await _settle();
  });

  test(
    'disabling during a fetch discards its late result and persisted cache',
    () async {
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();
      final selecting = controller.selectCity(_kolkata);
      await _settle();
      expect(controller.busy, isTrue);
      expect(source.requests, hasLength(1));
      await controller.disableWeather();
      source.requests.single.result.complete(_weather());
      await selecting;

      expect(source.cancelCount, greaterThanOrEqualTo(2));
      expect(controller.weatherEnabled, isFalse);
      expect(controller.city, isNull);
      expect(controller.weather, isNull);
      expect(controller.busy, isFalse);
      expect(controller.error, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppearanceController.weatherKey), isNull);
      final saved = jsonDecode(
        prefs.getString(AppearanceController.settingsKey)!,
      ) as Map<String, dynamic>;
      expect(saved['weather'], isFalse);
      expect(saved['city'], isNull);
    },
  );

  test(
    'disabling during a city search discards late results and errors',
    () async {
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();
      final searching = controller.searchCities('  Kolkata  ');
      expect(source.searches.single.query, 'Kolkata');
      expect(controller.busy, isTrue);
      await controller.disableWeather();
      source.searches.single.result.complete([_kolkata]);
      expect(await searching, isEmpty);
      expect(controller.busy, isFalse);
      expect(controller.error, isNull);
      expect(controller.city, isNull);

      final failedSearch = controller.searchCities('Sydney');
      await controller.disableWeather();
      source.searches.last.result.completeError(
        StateError('Request cancelled'),
      );
      expect(await failedSearch, isEmpty);
      expect(controller.error, isNull);
    },
  );

  test(
    'selecting another city cannot be overwritten by an earlier fetch',
    () async {
      final source = _FakeWeatherSource();
      final controller = _controller(source);
      await controller.initialize();
      final first = controller.selectCity(_kolkata);
      await _settle();
      final second = controller.selectCity(_sydney);
      await _settle();
      expect(source.requests, hasLength(2));
      source.requests.last.result.complete(
        _weather(city: _sydney, kind: SkyWeather.clouds),
      );
      await second;
      source.requests.first.result.complete(_weather());
      await first;
      expect(controller.city?.key, _sydney.key);
      expect(controller.weather?.cityKey, _sydney.key);
      expect(controller.calendar, SeasonCalendar.southern);
      expect(controller.scene().weather, SkyWeather.clouds);
    },
  );

  test(
    'preview overrides appearance then returns to actual conditions',
    () async {
      _seed(settings: _enabledSettings(), weather: _weather());
      final controller = _controller(_FakeWeatherSource());
      await controller.initialize();
      controller.setPreviewHour(-4);
      controller.setPreviewWeather(SkyWeather.snow);
      expect(controller.previewing, isTrue);
      expect(controller.previewHour, 0);
      expect(controller.scene().phase, DayPhase.night);
      expect(controller.scene().weather, SkyWeather.snow);
      expect(controller.weather?.kind, SkyWeather.rain);
      controller.setPreviewHour(100);
      expect(controller.previewHour, 23.99);

      controller.clearPreview();
      expect(controller.previewing, isFalse);
      expect(controller.scene().phase, DayPhase.golden);
      expect(controller.scene().weather, SkyWeather.rain);
    },
  );

  test(
    'fixed mode follows theme brightness while time preview still works',
    () async {
      final controller = _controller(_FakeWeatherSource());
      await controller.initialize();
      await controller.update(follow: false, theme: ThemeMode.system);
      expect(
        controller.scene(systemBrightness: Brightness.dark).phase,
        DayPhase.night,
      );
      expect(
        controller.scene(systemBrightness: Brightness.light).phase,
        DayPhase.golden,
      );
      await controller.update(theme: ThemeMode.dark);
      expect(controller.scene().phase, DayPhase.night);
      controller.setPreviewHour(12);
      expect(controller.scene().phase, DayPhase.day);
      controller.clearPreview();
      expect(controller.scene().phase, DayPhase.night);
      await controller.update(follow: true);
      expect(controller.scene().phase, DayPhase.day);
    },
  );

  test(
    'inactive lifecycle stops ticks and resuming refreshes older weather',
    () async {
      var now = _noon;
      _seed(settings: _enabledSettings(), weather: _weather());
      final source = _FakeWeatherSource();
      final controller = _controller(source, clock: () => now);
      await controller.initialize();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.setActive(false);
      now = now.add(const Duration(minutes: 31));
      controller.tick();
      await controller.refreshWeather(force: true);
      expect(notifications, 0);
      expect(source.requests, isEmpty);

      controller.setActive(true);
      expect(notifications, greaterThan(0));
      expect(source.requests, hasLength(1));
      source.requests.single.result.complete(
        _weather(observed: now, fetched: now),
      );
      await _settle();
      expect(controller.hasWeather, isTrue);
      expect(controller.busy, isFalse);
    },
  );

  test(
    'disposed controller ignores a pending fetch and releases the source',
    () async {
      final source = _FakeWeatherSource();
      final controller = AppearanceController(
        weatherSource: source,
        clock: () => _noon,
      );
      await controller.initialize();
      final selecting = controller.selectCity(_kolkata);
      await _settle();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      source.requests.single.result.complete(_weather());
      await selecting;
      controller.tick();
      expect(source.disposed, isTrue);
      expect(notifications, 0);
      expect(controller.weather, isNull);
    },
  );
}

AppearanceController _controller(
  _FakeWeatherSource source, {
  DateTime Function()? clock,
}) {
  final controller = AppearanceController(
    weatherSource: source,
    clock: clock ?? () => _noon,
  );
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void _seed({required Map<String, dynamic> settings, LocalWeather? weather}) {
  SharedPreferences.setMockInitialValues({
    AppearanceController.settingsKey: jsonEncode(settings),
    if (weather != null)
      AppearanceController.weatherKey: jsonEncode(weather.toJson()),
  });
}

Map<String, dynamic> _enabledSettings() => {
  'weather': true,
  'city': _kolkata.toJson(),
  'calendar': 'india',
};

LocalWeather _weather({
  WeatherCity city = _kolkata,
  SkyWeather kind = SkyWeather.rain,
  DateTime? observed,
  DateTime? fetched,
}) => LocalWeather(
  cityKey: city.key,
  kind: kind,
  temperature: 28,
  observedAt: observed ?? _noon,
  fetchedAt: fetched ?? _noon,
  utcOffset: 19800,
  isDay: true,
  sunrise: DateTime.utc(2026, 9, 20, 0, 30),
  sunset: DateTime.utc(2026, 9, 20, 12, 30),
);

class _FakeWeatherSource implements WeatherSource {
  final requests =
      <({WeatherCity city, DateTime now, Completer<LocalWeather> result})>[];
  final searches = <({String query, Completer<List<WeatherCity>> result})>[];
  int cancelCount = 0;
  bool disposed = false;

  @override
  Future<LocalWeather> current(WeatherCity city, DateTime now) {
    final result = Completer<LocalWeather>();
    requests.add((city: city, now: now, result: result));
    return result.future;
  }

  @override
  Future<List<WeatherCity>> search(String query) {
    final result = Completer<List<WeatherCity>>();
    searches.add((query: query, result: result));
    return result.future;
  }

  @override
  void cancel() => cancelCount++;

  @override
  void dispose() => disposed = true;
}
