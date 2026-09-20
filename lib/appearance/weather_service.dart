import 'dart:convert';
import 'dart:io';

import 'sunset_scene.dart';

class WeatherCity {
  const WeatherCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country = '',
  });
  final String name, country;
  final double latitude, longitude;
  String get key => '$latitude,$longitude';
  SeasonCalendar get calendar => latitude < 0
      ? SeasonCalendar.southern
      : country == 'IN'
      ? SeasonCalendar.india
      : SeasonCalendar.northern;
  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'country': country,
  };
  factory WeatherCity.fromJson(Map<String, dynamic> data) {
    final lat = (data['latitude'] as num).toDouble();
    final lon = (data['longitude'] as num).toDouble();
    final name = data['name'] as String;
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        name.trim().isEmpty) {
      throw const FormatException('Invalid weather location');
    }
    return WeatherCity(
      name: name,
      latitude: lat,
      longitude: lon,
      country: data['country'] as String? ?? '',
    );
  }
}

class LocalWeather {
  const LocalWeather({
    required this.cityKey,
    required this.kind,
    required this.temperature,
    required this.observedAt,
    required this.fetchedAt,
    required this.utcOffset,
    required this.isDay,
    this.sunrise,
    this.sunset,
  });
  final String cityKey;
  final SkyWeather kind;
  final double temperature;
  final DateTime observedAt, fetchedAt;
  final int utcOffset;
  final bool isDay;
  final DateTime? sunrise, sunset;
  DateTime clock(DateTime now) => now.toUtc().add(Duration(seconds: utcOffset));
  bool usable(WeatherCity? city, DateTime now) =>
      cityKey.isNotEmpty &&
      temperature.isFinite &&
      utcOffset.abs() <= 14 * 3600 &&
      city?.key == cityKey &&
      !now.isBefore(fetchedAt) &&
      now.difference(fetchedAt) < const Duration(hours: 2) &&
      observedAt.difference(now) <= const Duration(minutes: 15) &&
      now.difference(observedAt) < const Duration(hours: 2);
  Map<String, dynamic> toJson() => {
    'city': cityKey,
    'kind': kind.name,
    'temperature': temperature,
    'observed': observedAt.toIso8601String(),
    'fetched': fetchedAt.toIso8601String(),
    'offset': utcOffset,
    'day': isDay,
    'sunrise': sunrise?.toIso8601String(),
    'sunset': sunset?.toIso8601String(),
  };
  factory LocalWeather.fromJson(Map<String, dynamic> data) {
    final cityKey = data['city'] as String;
    final temperature = (data['temperature'] as num).toDouble();
    final offset = data['offset'] as int;
    if (cityKey.trim().isEmpty ||
        !temperature.isFinite ||
        offset.abs() > 14 * 3600) {
      throw const FormatException('Invalid cached weather');
    }
    return LocalWeather(
      cityKey: cityKey,
      kind: SkyWeather.values.byName(data['kind'] as String),
      temperature: temperature,
      observedAt: DateTime.parse(data['observed'] as String).toUtc(),
      fetchedAt: DateTime.parse(data['fetched'] as String).toUtc(),
      utcOffset: offset,
      isDay: data['day'] as bool,
      sunrise: DateTime.tryParse(data['sunrise'] as String? ?? '')?.toUtc(),
      sunset: DateTime.tryParse(data['sunset'] as String? ?? '')?.toUtc(),
    );
  }
  factory LocalWeather.fromForecast(
    Map<String, dynamic> data,
    WeatherCity city,
    DateTime now,
  ) {
    final current = data['current'] as Map<String, dynamic>;
    final kind = SkyWeather.fromCode(current['weather_code'] as int);
    final temperature = (current['temperature_2m'] as num).toDouble();
    final offset = data['utc_offset_seconds'] as int;
    final isDay = current['is_day'] as int;
    DateTime timestamp(num seconds) => DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    );
    DateTime? solar(String key) {
      final values = (data['daily'] as Map<String, dynamic>?)?[key] as List?;
      return values != null && values.isNotEmpty && values.first is num
          ? timestamp(values.first as num)
          : null;
    }

    if (kind == null ||
        !temperature.isFinite ||
        offset.abs() > 14 * 3600 ||
        (isDay != 0 && isDay != 1)) {
      throw const FormatException('Incomplete weather');
    }
    final result = LocalWeather(
      cityKey: city.key,
      kind: kind,
      temperature: temperature,
      observedAt: timestamp(current['time'] as num),
      fetchedAt: now.toUtc(),
      utcOffset: offset,
      isDay: isDay == 1,
      sunrise: solar('sunrise'),
      sunset: solar('sunset'),
    );
    if (!result.usable(city, now)) {
      throw const FormatException('Outdated weather');
    }
    return result;
  }
}

abstract class WeatherSource {
  Future<List<WeatherCity>> search(String query);
  Future<LocalWeather> current(WeatherCity city, DateTime now);
  void cancel();
  void dispose();
}

/// No API key; free Open-Meteo endpoint is for personal/non-commercial use.
class OpenMeteoWeatherSource implements WeatherSource {
  HttpClient? _client;
  Future<Map<String, dynamic>> _json(Uri uri) async {
    final client = _client ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    return (() async {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != 200) {
        throw const HttpException('Weather unavailable');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) {
          throw const FormatException('Weather response too large');
        }
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    })().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        client.close(force: true);
        if (identical(_client, client)) _client = null;
        throw const HttpException('Weather request timed out');
      },
    );
  }

  @override
  Future<List<WeatherCity>> search(String query) async {
    final data = await _json(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '5',
        'language': 'en',
        'format': 'json',
      }),
    );
    return (data['results'] as List? ?? []).map((value) {
      final item = value as Map<String, dynamic>;
      return WeatherCity.fromJson({
        ...item,
        'name': [
          item['name'],
          item['admin1'],
          item['country'],
        ].whereType<String>().join(', '),
        'country': item['country_code'] ?? '',
      });
    }).toList();
  }

  @override
  Future<LocalWeather> current(WeatherCity city, DateTime now) async {
    final data = await _json(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': city.latitude.toString(),
        'longitude': city.longitude.toString(),
        'current': 'temperature_2m,weather_code,is_day',
        'daily': 'sunrise,sunset',
        'timezone': 'auto',
        'timeformat': 'unixtime',
        'forecast_days': '1',
      }),
    );
    return LocalWeather.fromForecast(data, city, now);
  }

  @override
  void cancel() {
    _client?.close(force: true);
    _client = null;
  }

  @override
  void dispose() => cancel();
}
