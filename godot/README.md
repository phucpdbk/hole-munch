# Hole Munch — Earth Invasion (Godot playtest)

An alien saucer drops a black hole on Earth. Swallow each city, grow, then swallow
its landmark or defeat its defence unit to conquer it.

- **6 continents × 8 cities = 48 levels** (Asia, Europe, Africa, North America,
  South America, Oceania). Each continent has its own palette, houses, trees and
  weather. Odd cities end with a landmark (24 in total); even cities with a
  defence unit (tank, helicopter, combat robot) and every finale with a Titan.
  Defence units flee the hole and drop soldiers/drones as bonus food.
- **Map size follows difficulty**: 3×3 blocks at the start, 5×3, then 5×5;
  continent finales use the next size up (5×7 from the fourth continent).
  The boss size comes from the map's own food (3.0–5.6, finales up to 6.2).
- **Timer** = par time of the deterministic test route × 1.8 early, falling to
  ×1.35 late (about 110–205 s). Par times live in `campaign.gd`
  (`PAR_SECONDS`); regenerate them from `--campaign-smoke` output (`PAR` lines)
  after changing map contents.
- **Upgrades** (NÂNG CẤP): coins from every round buy start size, speed, time,
  magnet and coin bonus, ported from the 2D game (cost ×1.6 per level).
- Save version 4 stores progress, coins and upgrades. Older native saves keep best
  score and cosmetics; their stars become 25 coins each.

All 48 levels are temporarily selectable via
`application_custom/testing/unlock_all_levels=true` in `project.godot`.
Set it to `false` to restore normal locks.

This is a separate, mobile-first native prototype. Open `project.godot` with
Godot **4.7.1** and press F5. The original JavaScript game remains in the parent
project and its saves are not touched.

## Ported from the 2D game

- Traffic: 44 cars drive both directions on the inner roads and wrap at the map
  edge, like the 2D lanes. Crossings have alternating signals with an all-red
  clearing phase; cars queue behind each other and never overlap.
- Pedestrians stroll around their sidewalk spot, facing where they walk. The city
  keeps moving on the menu and result screens; pause freezes it.
- Combos: bites within 1 second chain; 8/16/30 bites give 1.5x/2x/3x score.
  Completion and stars use original points (2 stars at 75%, 3 at 90%).
- Duck boss: sprints away from a nearby hole for 0.85 s, rests 3 s, drops up to
  8 ducklings (bonus food, not counted in completion) and stays in the plaza.
- Score popups, a pulsing rim on each bite, size-up callouts, and larger objects
  sinking more slowly while spinning into the hole.

## Architecture and performance

Compatibility rendering targets a broad range of Android hardware. Toy models
are baked into vertex-colored meshes and grouped into MultiMesh batches
(at most 24 in campaign checks, including the new farm scenes).
One directional light supplies shadows. A ground shader cuts a real opening at
the hole; swallowed objects sink below the surface and are clipped there.
There are no per-frame CanvasTexture uploads or per-object physics bodies.

The original single-level desktop capture measured **49 draw calls including shadows**, a 16.675 ms
median frame interval and approximately 17 ms p95 at 486 × 864 on an NVIDIA RTX 2060 SUPER.
This is a stationary-scene desktop measurement, not a mobile benchmark or a
claim of 60 FPS on all phones. Check a physical Android phone before release.

## Checks

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . -- --smoke
Godot_v4.7.1-stable_win64_console.exe --headless --path . -- --campaign-smoke
Godot_v4.7.1-stable_win64_console.exe --path . -- --capture
Godot_v4.7.1-stable_win64_console.exe --path . -- --campaign-capture
```

Smoke checks cover touch press/drag/release, movement-gated time, eating, growth,
duplicate scoring, pause/resume, replay reset, traffic (lanes, heading, wrap,
60 simulated seconds without overlap or deadlock), pedestrians, combos, stars,
the duck boss, a deterministic route to the boss that chases moving food, and timeout. The route includes estimated travel time but is not a human
difficulty test. Neither smoke nor capture mode writes the player's save.
Capture writes menu/game/combo/boss/result PNGs and a performance JSON to `test-output/`.
Campaign checks cover save migration/validation, coins and upgrades, all 48 growth
routes with estimated travel time, boss sizes/footprints, landmark vs defence
behaviour, boss catches, next-level reset, weather pause, journey pages and the
shop. Campaign capture writes the journey, shop, wardrobe and all 48 city menus.

## Android debug APK

1. Install the Android SDK and a JDK (the existing Android Studio JBR works here).
2. Run `python tools/fetch_android_template.py`. It reads the matching official
   Godot archive over HTTPS ranges and extracts only the debug Android template.
3. Run `tools/build-android.ps1`, passing `-AndroidSdk` and `-JavaSdk` if needed.

The build script creates a local **debug-only** keystore in the ignored `builds`
directory. The standard `android` password is for this disposable debug key,
not a production signing identity. Editor SDK settings are restored after export.
The APK targets ARM64 with package ID `org.holemunch.pocketcity.prototype`, so it
does not replace the existing Capacitor app. The template version must exactly
match the editor version. No Gradle build or global template installation is used.

Output: `builds/hole-munch-prototype.apk` (about 27 MiB). The verified APK targets
SDK 36, requires Android 7/API 24 or later on ARM64, has a launcher alias and no
requested Android permissions, and passes APK v2/v3 signature verification.
The non-Gradle template determines the manifest target SDK; the preset SDK value
selects the locally available signing build tools. Tooling, signing keys and test
artifacts are excluded from the APK. This APK has not been installed or tested on
the connected physical phone. The headless scripted editor exporter emits RID
cleanup warnings after successful export; the captured game runtime log is clean.
It is for local installation/testing,
not Play Store submission. Store release needs a release-signed AAB, current
store-target requirements, physical-device QA, final assets and privacy metadata.
iOS has a project-only export preset and Mac setup script. See [IOS.md](IOS.md).
Xcode compilation, signing and device testing still require a Mac and Apple Team.

## Deferred migration

World events, onboarding goals, achievements, ads and web save migration are not
ported yet. Validate the game feel
and artwork of this slice before extending the content. Keep the web project
available if the YouTube Playables application receives a response later.
