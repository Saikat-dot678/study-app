import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sunset_scene.dart';
import 'weather_service.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController({
    WeatherSource? weatherSource,
    DateTime Function()? clock,
  }) : _source = weatherSource ?? OpenMeteoWeatherSource(),
       _clock = clock ?? DateTime.now;
  final WeatherSource _source;
  final DateTime Function() _clock;
  static const settingsKey = 'study.livingSunset.v1';
  static const weatherKey = 'study.livingSunset.weather.v1';
  bool followDay = true,
      reduceMotion = false,
      weatherEnabled = false,
      busy = false;
  ThemeMode mode = ThemeMode.system;
  SeasonCalendar calendar = SeasonCalendar.northern;
  StudySeason? seasonOverride;
  double? previewHour;
  SkyWeather? previewWeather;
  WeatherCity? city;
  LocalWeather? weather;
  String? error;
  bool _disposed = false, _active = true, _initialized = false;
  int _generation = 0, _revision = 0;
  DateTime? _lastAttempt;
  Timer? _timer;
  Future<void> _writes = Future.value();
  bool get previewing => previewHour != null || previewWeather != null;
  bool get hasWeather =>
      weatherEnabled && weather?.usable(city, _clock()) == true;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || revision != _revision) return;
      final raw = prefs.getString(settingsKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final savedMode = ThemeMode.values.byName(
          data['mode'] as String? ?? 'system',
        );
        final savedCalendar = SeasonCalendar.values.byName(
          data['calendar'] as String? ?? 'northern',
        );
        final savedSeason = data['season'] == null
            ? null
            : StudySeason.values.byName(data['season'] as String);
        final savedCity = data['city'] == null
            ? null
            : WeatherCity.fromJson(data['city'] as Map<String, dynamic>);
        followDay = data['followDay'] != false;
        reduceMotion = data['reduceMotion'] == true;
        mode = savedMode;
        calendar = savedCalendar;
        seasonOverride = savedSeason;
        city = savedCity;
        weatherEnabled = data['weather'] == true && savedCity != null;
      }
      try {
        final rawWeather = prefs.getString(weatherKey);
        if (rawWeather != null) {
          weather = LocalWeather.fromJson(
            jsonDecode(rawWeather) as Map<String, dynamic>,
          );
        }
      } catch (_) {
        weather = null;
      }
    } catch (_) {
      error = 'Saved appearance could not be loaded; using local defaults.';
    } finally {
      if (!_disposed) {
        _notify();
        _startTimer();
        unawaited(refreshWeather());
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_active && !_disposed) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => tick());
    }
  }

  void setActive(bool active) {
    if (_disposed) return;
    _active = active;
    if (!active) {
      _timer?.cancel();
    } else {
      _startTimer();
      tick();
    }
  }

  void tick() {
    if (_disposed || !_active) return;
    _notify();
    unawaited(refreshWeather());
  }

  DateTime get localTime => hasWeather ? weather!.clock(_clock()) : _clock();
  SunsetScene scene({Brightness systemBrightness = Brightness.light}) {
    final local = localTime;
    final hour = previewHour ?? local.hour + local.minute / 60;
    var sunrise = 6.0, sunset = 18.0;
    final data = hasWeather ? weather : null;
    bool sameDay(DateTime date) =>
        date.year == local.year &&
        date.month == local.month &&
        date.day == local.day;
    if (data?.sunrise != null && data?.sunset != null) {
      final rise = data!.clock(data.sunrise!), set = data.clock(data.sunset!);
      if (sameDay(rise) && sameDay(set)) {
        sunrise = rise.hour + rise.minute / 60;
        sunset = set.hour + set.minute / 60;
      }
    }
    var phase = phaseAt(hour, sunrise: sunrise, sunset: sunset);
    if (previewHour == null &&
        data != null &&
        (data.sunrise == null || data.sunset == null)) {
      phase = data.isDay ? DayPhase.day : DayPhase.night;
    }
    if (!followDay && previewHour == null) {
      final dark =
          mode == ThemeMode.dark ||
          mode == ThemeMode.system && systemBrightness == Brightness.dark;
      phase = dark ? DayPhase.night : DayPhase.golden;
    }
    return SunsetScene(
      phase: phase,
      season: seasonOverride ?? seasonAt(local.month, calendar),
      weather: previewWeather ?? data?.kind ?? SkyWeather.clear,
      hour: hour,
    );
  }

  String get weatherStatus {
    if (busy) return 'Checking Open-Meteo…';
    if (hasWeather) {
      final age = _clock().difference(weather!.fetchedAt).inMinutes;
      return '${error == null ? '' : '$error '}${city!.name} · ${weather!.temperature.round()}°C · ${weather!.kind.label} · updated ${age == 0 ? 'just now' : '$age min ago'}';
    }
    return error ??
        (weatherEnabled
            ? 'Weather unavailable. Clock & calendar are active.'
            : 'Weather off. Clock & calendar work offline.');
  }

  Future<bool> update({
    bool? follow,
    bool? reduced,
    ThemeMode? theme,
    SeasonCalendar? seasonCalendar,
    StudySeason? season,
    bool useCalendar = false,
  }) async {
    if (_disposed) return false;
    _revision++;
    followDay = follow ?? followDay;
    reduceMotion = reduced ?? reduceMotion;
    mode = theme ?? mode;
    calendar = seasonCalendar ?? calendar;
    if (useCalendar) {
      seasonOverride = null;
    } else if (season != null) {
      seasonOverride = season;
    }
    _notify();
    return _persist();
  }

  void setPreviewHour(double? value) {
    previewHour = value?.clamp(0, 23.99);
    _notify();
  }

  void setPreviewWeather(SkyWeather? value) {
    previewWeather = value;
    _notify();
  }

  void clearPreview() {
    previewHour = null;
    previewWeather = null;
    _notify();
  }

  Future<List<WeatherCity>> searchCities(String query) async {
    if (_disposed || query.trim().length < 2) return [];
    final token = ++_generation;
    _source.cancel();
    busy = true;
    error = null;
    _notify();
    try {
      final cities = await _source.search(query.trim());
      if (_disposed || token != _generation) return [];
      return cities;
    } catch (_) {
      if (!_disposed && token == _generation) {
        error = 'City search unavailable. Try again when connected.';
      }
      return [];
    } finally {
      if (!_disposed && token == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> selectCity(WeatherCity selected) async {
    if (_disposed) return;
    _generation++;
    _revision++;
    _source.cancel();
    busy = false;
    city = selected;
    calendar = selected.calendar;
    weatherEnabled = true;
    weather = null;
    error = null;
    _lastAttempt = null;
    _notify();
    await _persist();
    if (!_disposed) await refreshWeather(force: true);
  }

  Future<void> disableWeather() async {
    if (_disposed) return;
    _generation++;
    _revision++;
    _source.cancel();
    busy = false;
    city = null;
    weather = null;
    weatherEnabled = false;
    error = null;
    _lastAttempt = null;
    _notify();
    await _persist();
  }

  Future<void> refreshWeather({bool force = false}) async {
    if (_disposed || !_active || busy || !weatherEnabled || city == null) {
      return;
    }
    final now = _clock();
    if (!force &&
        hasWeather &&
        now.difference(weather!.fetchedAt) < const Duration(minutes: 30)) {
      return;
    }
    if (!force &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < const Duration(minutes: 10)) {
      return;
    }
    final token = ++_generation, selected = city!;
    _lastAttempt = now;
    busy = true;
    error = null;
    _notify();
    try {
      final value = await _source.current(selected, now);
      if (_disposed || token != _generation) return;
      if (!value.usable(selected, _clock())) {
        throw const FormatException('Outdated weather');
      }
      weather = value;
      await _persist();
    } catch (_) {
      if (!_disposed && token == _generation) {
        error = 'Could not refresh weather.';
      }
    } finally {
      if (!_disposed && token == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  Future<bool> _persist() async {
    final settings = jsonEncode({
      'followDay': followDay,
      'reduceMotion': reduceMotion,
      'mode': mode.name,
      'calendar': calendar.name,
      'season': seasonOverride?.name,
      'weather': weatherEnabled,
      'city': city?.toJson(),
    });
    final cached = weatherEnabled && weather != null
        ? jsonEncode(weather!.toJson())
        : null;
    var success = true;
    _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        success = await prefs.setString(settingsKey, settings);
        final saved = cached == null
            ? await prefs.remove(weatherKey)
            : await prefs.setString(weatherKey, cached);
        success = saved && success;
      } catch (_) {
        success = false;
      }
    });
    await _writes;
    if (!success && !_disposed) {
      error = 'Appearance is active for this session but could not be saved.';
      _notify();
    }
    return success;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _source.dispose();
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
