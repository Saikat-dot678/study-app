import 'package:flutter/material.dart';

import '../appearance/appearance_controller.dart';
import '../appearance/sunset_scene.dart';
import '../appearance/weather_service.dart';

class SunsetSettings extends StatelessWidget {
  const SunsetSettings({super.key, required this.appearance});
  final AppearanceController appearance;
  Future<void> _city(BuildContext context) async {
    final selected = await showModalBottomSheet<WeatherCity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CityPicker(appearance: appearance),
    );
    if (selected != null) await appearance.selectCity(selected);
  }

  @override
  Widget build(BuildContext context) {
    final a = appearance, scheme = Theme.of(context).colorScheme;
    final scene = a.scene(
      systemBrightness: MediaQuery.platformBrightnessOf(context),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_twilight_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Living Sunset',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${scene.phase.label} · ${scene.season.label}${a.previewing ? ' · Preview' : ''}',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'From first light to moonlight. A familiar desk, changing gently with your day.',
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Follow the time of day'),
              subtitle: const Text(
                'Dawn, daylight, golden hour, blue hour and night.',
              ),
              value: a.followDay,
              onChanged: (value) => a.update(follow: value),
            ),
            if (!a.followDay)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final mode in ThemeMode.values)
                    ChoiceChip(
                      label: Text(switch (mode) {
                        ThemeMode.system => 'System',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      }),
                      selected: a.mode == mode,
                      onSelected: (_) => a.update(theme: mode),
                    ),
                ],
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('season-${a.seasonOverride}'),
              initialValue: a.seasonOverride?.name ?? 'auto',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Season'),
              items: [
                const DropdownMenuItem(
                  value: 'auto',
                  child: Text('Follow the calendar'),
                ),
                for (final season in StudySeason.values)
                  DropdownMenuItem(
                    value: season.name,
                    child: Text(season.label),
                  ),
              ],
              onChanged: (value) => value == 'auto'
                  ? a.update(useCalendar: true)
                  : a.update(season: StudySeason.values.byName(value!)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<SeasonCalendar>(
              key: ValueKey(a.calendar),
              initialValue: a.calendar,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Season calendar'),
              items: [
                for (final calendar in SeasonCalendar.values)
                  DropdownMenuItem(
                    value: calendar,
                    child: Text(switch (calendar) {
                      SeasonCalendar.northern => 'Northern hemisphere',
                      SeasonCalendar.southern => 'Southern hemisphere',
                      SeasonCalendar.india => 'India · includes monsoon',
                    }),
                  ),
              ],
              onChanged: (value) => a.update(seasonCalendar: value),
            ),
            const SizedBox(height: 6),
            Text(
              'Calendar colors are an approximation. Choose any season you prefer.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Follow local weather'),
              subtitle: const Text(
                'Optional. Choose a city; no account, key or location permission.',
              ),
              value: a.weatherEnabled,
              onChanged: (value) => value ? _city(context) : a.disableWeather(),
            ),
            if (a.weatherEnabled || a.busy || a.error != null) ...[
              const SizedBox(height: 6),
              Text(
                a.weatherStatus,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: a.busy ? null : () => _city(context),
                    icon: const Icon(Icons.location_city_outlined),
                    label: const Text('Change city'),
                  ),
                  TextButton.icon(
                    onPressed: a.busy
                        ? null
                        : () => a.refreshWeather(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Weather by Open-Meteo · free for personal / non-commercial use. Your city coordinates are sent only when enabled; weather is cached for offline fallback.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SelectableText(
              'open-meteo.com',
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion'),
              subtitle: const Text('Keep the sky still and transitions quiet.'),
              value: a.reduceMotion,
              onChanged: (value) => a.update(reduced: value),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Try another atmosphere'),
              subtitle: const Text(
                'Preview only — return to your day when finished.',
              ),
              children: [
                Text(
                  'Preview time: ${(scene.hour.floor()).toString().padLeft(2, '0')}:${((scene.hour % 1) * 60).round().clamp(0, 59).toString().padLeft(2, '0')}',
                ),
                Slider(
                  value: a.previewHour ?? scene.hour,
                  min: 0,
                  max: 23.99,
                  divisions: 96,
                  semanticFormatterCallback: (value) =>
                      '${value.floor()} hours',
                  onChanged: a.setPreviewHour,
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('preview-${a.previewWeather}'),
                  initialValue: a.previewWeather?.name ?? 'auto',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Preview weather',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'auto',
                      child: Text('Actual weather / offline sky'),
                    ),
                    for (final weather in SkyWeather.values)
                      DropdownMenuItem(
                        value: weather.name,
                        child: Text(weather.label),
                      ),
                  ],
                  onChanged: (value) => a.setPreviewWeather(
                    value == 'auto' ? null : SkyWeather.values.byName(value!),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: a.clearPreview,
                  child: const Text('Return to my day'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.appearance});
  final AppearanceController appearance;
  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  final query = TextEditingController();
  List<WeatherCity> results = [];
  bool searching = false;
  String? message;
  Future<void> search() async {
    if (query.text.trim().length < 2) {
      setState(() => message = 'Enter at least two letters.');
      return;
    }
    setState(() {
      searching = true;
      message = null;
      results = [];
    });
    final found = await widget.appearance.searchCities(query.text);
    if (mounted) {
      setState(() {
        searching = false;
        results = found;
        message = found.isEmpty
            ? widget.appearance.error ?? 'No city found. Try a nearby city.'
            : null;
      });
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      14,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let the weather in.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Search sends the city name to Open-Meteo. Choosing a result enables weather for that city. No precise device location is collected.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: query,
              maxLength: 80,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'e.g. Kolkata',
              ),
              onSubmitted: searching ? null : (_) => search(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: searching ? null : search,
              icon: const Icon(Icons.search),
              label: Text(searching ? 'Searching…' : 'Find city'),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(message!),
              ),
            for (final city in results)
              ListTile(
                title: Text(city.name),
                leading: const Icon(Icons.location_city_outlined),
                onTap: () => Navigator.pop(context, city),
              ),
          ],
        ),
      ),
    ),
  );
}
