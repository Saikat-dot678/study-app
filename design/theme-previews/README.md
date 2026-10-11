# Study: five theme concepts

The selected design is now in the Flutter app. [Desktop screenshot](flutter-sunset-desktop.png) and [phone screenshot](flutter-sunset-phone.png) show the actual connected Home layout rendered with representative test library data. The HTML lab below remains a separate design playground.

Open `index.html` for the live atmosphere lab. It includes working theme switching, original animated hero artwork, hover depth, a responsive phone composition, a sample library, reader surface, notebook, search, focus timer, starring, and local sample-space creation. Every prototype action is isolated to the browser; it does not read or modify the Flutter app or the user's files.

`static-gallery.html` preserves the quieter comparison-board gallery with Desktop, Phone, and Comparison board views, enlarged previews, and PNG downloads. Both pages work offline after the repository is served locally.

Each theme includes:

- A 2520 × 1740 presentation board (`<theme>.png`).
- A 2424 × 1520 desktop preview (`<theme>-desktop.png`).
- A 704 × 1520 phone preview (`<theme>-phone.png`).

1. **Aurora Focus:** midnight indigo, lavender, mint, flowing orbital line art.
2. **Paper Studio:** warm ivory, forest ink, editorial serif headings, paper illustration.
3. **Neon Night Lab:** charcoal, lime, ice blue, geometric technical illustration.
4. **Forest Desk:** evergreen, cream, amber, botanical illustration.
5. **Sunset Scholar:** sand, terracotta, plum, architectural sunset illustration.

These are standalone visual concepts using representative library content, not screenshots of implemented theme options. The sample files, counts, and dates are illustrative. Shared content makes comparison easier; the phone arrangement is composed separately from desktop. The live lab demonstrates proposed motion; the PNGs remain static. Turn on Effects and move across the hero to see the pointer light, parallax depth, scanline, magnetic CTA, click ripples, and each direction's signature details: drifting aurora motes, graphite flecks, neon signal pulses, forest light, and sunset glints. All effects respect the browser's Reduce Motion preference and the lab's Effects on/off control.

The preview renderer explicitly loads the bundled Manrope and Editorial fonts and Material icons. It uses a Material baseline and a keyed capture boundary, settles each theme before capture, and checks each layout for Flutter rendering exceptions. This replaces the earlier previews with fallback test-font boxes.

Capture the implemented Flutter Sunset artwork from the repository root:

```powershell
flutter test test/sunset_widgets_test.dart --no-pub
```

Sunset is now the selected direction for further design work. The live preview opens its **Living Sunset** edition with clock-driven dawn, daylight, golden hour, blue hour, and moonlight. The time slider and season/weather controls let you inspect combinations immediately. Seasonal palettes include spring, summer, monsoon, autumn, and winter, with northern, southern, and India calendar profiles. Calendar seasons are a visual approximation and can be overridden.

Optional weather uses the [Open-Meteo forecast](https://open-meteo.com/en/docs) and [geocoding](https://open-meteo.com/en/docs/geocoding-api) APIs. No account or API key is needed for the [free non-commercial service](https://open-meteo.com/en/terms); subscriptions, advertising, or commercial distribution would require reevaluating the provider. City searches send the entered city; location lookup requires an explicit button press and browser permission, rounds coordinates to two decimal places, and sends them to Open-Meteo. Settings and recent weather are kept in browser storage. Turning weather off cancels requests and clears the stored location and weather.

Weather refreshes at most every 30 minutes automatically while the preview is active. Failed automatic requests back off for 10 minutes; weather older than two hours falls back to clock/calendar colors. The selected city's timezone and available sunrise/sunset determine the daily light cycle; offline without solar data, the preview uses 06:00/18:00. Manual conditions are explicitly labeled as previews. Storms use clouds and rain without flashing lightning.

Serve the repository locally and open `http://127.0.0.1:8765/design/theme-previews/index.html` for weather/browser-location support. The time, season, and simulated conditions also work without an internet connection.

Validate the HTML atmosphere rules with `node --test design/theme-previews/sunset-core.test.cjs`. Living Sunset is now implemented in the Flutter app, with app-wide time/season colors, a painted animated landscape, optional city weather, and controls under Settings. The native app uses city search rather than device geolocation. `flutter test test/sunset_scene_test.dart test/appearance_controller_test.dart test/sunset_widgets_test.dart test/sunset_integration_test.dart --no-pub` checks the native rules, weather, preferences, layout, motion, and navigation. Screenshot captures go to ignored `build/qa/`; the older five-theme PNGs remain concept previews.
