# Hole Munch — Earth Invasion (Godot playtest)

An alien saucer drops a black hole on Earth. Swallow each city, grow, then swallow
its landmark to conquer it, while dodging independent military defenders.

- **6 continents × 8 cities = 48 levels** (Asia, Europe, Africa, North America,
  South America, Oceania). Each continent has its own palette, houses, trees and
  weather. All 48 objectives are city landmarks. Tanks and rifle infantry approach along roads and attack independently of the landmark.
- **Street fronts follow the landmark city** (`city_profiles.gd`): each city
  picks one of 19 shophouse styles (Hà Nội tube houses, Paris Haussmann, New
  York brownstones, Amsterdam canal houses, Lagos tin-roof shops, Sydney lace
  verandahs…), its wall/sign colours and a skyline density. Blocks become
  downtown (shops + towers), commercial (shops + courtyard) or residential
  (one shop row + houses) in `city_blocks.gd`; villages such as Pisa, Djenné,
  Uluru and Rapa Nui have no towers. Buildings standing between the camera and
  the hole are drawn as a see-through screen door. Preview with
  `-- --capture --street-capture` (writes `test-output/street-XX.png`).
- **Map size follows difficulty**: 3×3 blocks at the start, 5×3, then 5×5;
  continent finales use the next size up (5×7 from the fourth continent).
  The boss size comes from the map's own food (3.0–5.6, finales up to 6.2).
- **Timer** = par × 2.3 early, falling to ×1.55 late, never below 45 s early /
  30 s late. Par is how long a real-time greedy route (`smoke.gd`, the same
  food-per-distance choice the rival makes, no clock bonus) needs at player
  speed, 14–206 s. Par times live in `campaign.gd` (`PAR_SECONDS`); regenerate them
  from `--campaign-smoke` output (`PAR` lines) after changing map contents.
- **The clock never refills in campaign or daily rounds**: no combo time, no
  +5 s pickup (both stay in endless only). The only extras are the small time
  upgrade (+1 s per level, 5 levels) and the one rewarded-ad revive below.
  Best combo raises the coin reward by 1% per bite (up to +60%).
- **Ads** (`ads.gd`): a rewarded ad can add 15 s once per campaign round, only
  when time runs out with the hole at least 60% of the way to the landmark
  (6 s offer, then it gives up by itself); a result with coins can be doubled
  by a rewarded ad. Interstitials: none before city 6, at most one per three
  round ends and three minutes, and never within two minutes of a rewarded ad.
  On Android `admob_backend.gd` drives the Poing Studios AdMob plugin 5.1.0
  (`addons/admob`, Google test unit IDs for now); desktop debug runs simulate
  rewarded ads. Android export needs the Gradle build (`android/` template
  from the 4.7.1 export templates, ETC2/ASTC import on). The plugin's AARs in
  `addons/admob/android/bin` are git-ignored by the plugin itself: after a
  fresh clone reinstall them via Project → Tools → AdMob Manager → Android.
- **Three goals per city** (`challenges.gd`), one star each: conquer, plus two
  rotating goals (clean 75%/90%, combo N, finish with time left, no hits, eat N
  defenders, eat the rival). Stars are kept per goal across replays.
- **Star gates**: each continent after the first needs 14 more stars in total.
- **Defence scales per continent** (`defense.gd`): warnings shrink from 1.25 s
  to 0.8 s, up to 5 simultaneous shots, opening grace drops from 8 s to 0,
  later gunners lead a moving hole, and each hit also shrinks the hole by 6%.
- **Landmark counter-attack** (from city 5): once the hole reaches 80% of the
  size it needs, the landmark fires volleys around it and a hidden squad of
  three rolls in from the map edge.
- **Rival hole** (`rival.gd`): from the second continent (every third city,
  then every city from city 33) a red hole races for the same landmark. It
  eats the best food per distance, pauses to chew, hunts a smaller player and
  flees a bigger one. If it swallows the landmark or the player, the round is
  lost; swallowing it pays +300 and a goal. Tune its pace with
  `-- --campaign-smoke --rival-bench` (an unopposed rival takes the city at
  about 70–90% of the timer).
- **Daily challenge** (THỬ THÁCH NGÀY): one city per date for everyone, with a
  rival and one continent tougher defence; the first win of the day pays ×1.5.
- **Endless** (VÔ TẬN): 60 s clock, every bite adds a little time (plus combo
  time and +5 s pickups), each landmark adds 30 s and leads to a random harder
  city; best score and cities are saved.
- **Upgrades** (NÂNG CẤP): coins buy start size (+0.05 × 6), speed (+4% × 8),
  time (+1 s × 5), magnet (× 5) and coin bonus (+8% × 8); base prices
  160/140/200/300/240, ×1.75 per level. A maxed size upgrade still cannot eat
  a shop at the start (checked in `--campaign-smoke`). Map food pays 1 coin per
  80 points on a win (200 on a loss); stars and the win pay the rest.
- **Journey map** (BẢN ĐỒ, `journey_map.gd`): one 3D continent per page in its
  own SubViewport. Land is extruded from Natural Earth 110m outlines
  (`world_map_data.gd`, generated by `node tools/geo/make_world_map.cjs`); each
  city stands at its real position (nudged apart when cities are close) on a
  plinth with its 3D landmark, greyed while locked, joined by a dotted route that
  turns gold once conquered. The player's craft hovers over the selected city;
  the side card shows weather, timer, map size, rival and goals and starts it.
  Swipe or use the arrows to change continent.
- **Languages** (`i18n.gd`, table in `i18n_strings.gd`): Tiếng Việt, English,
  Español, Português, Français, Bahasa Indonesia. First launch follows the phone
  language; the speech-bubble button on the menu switches it (saved).
- **Intro and tips** (`intro.gd`): a four-card story and how-to-play on first
  launch (again from the ? button), and a "new!" card before the first city with
  each new thing: rain, fog, wind, snow, storm, power orbs, gas bombs, hunger,
  the landmark counter-attack, the rival hole, continent finales and each new
  continent (at most two cards per start; seen cards are saved).
- **UI look**: Baloo 2 (titles/buttons) and Nunito (body), both OFL with full
  Vietnamese, in `assets/fonts`; chunky 3D buttons (`ui_button.gd`); icons baked
  from the local POLYGON Icons pack (`assets/icons/README.md`).
- Save version 5 stores progress, per-goal stars, coins, upgrades and the daily
  and endless records, plus the chosen language and seen intro cards. Version 4 star counts become their first goals. Older
  native saves keep best score and cosmetics; their stars become 25 coins each.

All 48 levels are temporarily selectable via
`application_custom/testing/unlock_all_levels=true` in `project.godot`.
Set it to `false` to restore normal locks.

Earth defense squads mark red attack zones and fire visible projectiles. Dodge them
or swallow the attacker to cancel its shot. Hits cost 2 seconds, shrink the hole
and briefly slow movement; hit immunity keeps overlapping blasts fair. See
`LOCAL-MODELS.md` for combat rules and the local asset-library audit.

This is a separate, mobile-first native prototype. Open `project.godot` with
Godot **4.7.1** and press F5. The original JavaScript game remains in the parent
project and its saves are not touched.

The local build uses imported POLYGON houses, trees and vehicles from the user’s asset library. See `assets/synty/README.md` for the import pipeline and public-source fallback.

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
Godot_v4.7.1-stable_win64_console.exe --path . -- --capture --challenge-capture
Godot_v4.7.1-stable_win64_console.exe --path . -- --capture --ui-capture --lang=en
Godot_v4.7.1-stable_win64_console.exe --headless --path . -- --campaign-smoke --rival-bench
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
