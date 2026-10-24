# Google Play listing — Hole Munch

Draft copy and graphics for the Play Console **Main store listing**. English is the
default listing; add translations later from the in-game i18n tables if wanted.
Build the signed AAB separately with [ANDROID-RELEASE.md](ANDROID-RELEASE.md).

## Graphics

```powershell
node godot/tools/make-store-assets.mjs
```

Writes to `godot/builds/store/` (ignored by Git):

| File | Play field | Spec |
|---|---|---|
| `icon-512.png` | App icon | 512×512 PNG, cropped like the launcher icon |
| `feature-graphic.png` | Feature graphic | 1024×500, from `assets/facebook/hole-munch-cover-v2-ufo.png` |
| `screenshot-1..8.png` | Phone screenshots | 1920×1080 landscape, English UI |

Screenshots come from 1080p English captures copied into `builds/store/raw/`:

```powershell
$godot = 'Godot_v4.7.1-stable_win64_console.exe'
foreach ($city in 8, 24, 40) {   # Paris, New York, Sydney
    & $godot --path godot --resolution 1920x1080 -- --capture --lang=en "--levels=$city"
    foreach ($shot in 'game', 'combo', 'boss') { Copy-Item "godot/test-output/$shot.png" "godot/builds/store/raw/$city-$shot.png" }
}
& $godot --path godot --resolution 1920x1080 -- --capture --ui-capture --lang=en
foreach ($shot in 'journey-1', 'wardrobe', 'result', 'shop') { Copy-Item "godot/test-output/ui-en-$shot.png" "godot/builds/store/raw/ui-en-$shot.png" }
```

The order is set by `SCREENSHOTS` in the script. Re-shoot after visible UI changes.
For tablets, Play reuses phone screenshots unless 7"/10" sets are uploaded.

## Text

**App name** (30 max): `Hole Munch`

**Short description** (80 max):

> Pilot a hungry hole, swallow whole cities and topple the world's landmarks!

**Full description** (4000 max):

> Earth is on the menu. Steer a hungry black hole from a flying saucer and swallow everything in your path — cars, trees, buses, buildings — growing bigger with every bite until you can gulp down the city's famous landmark.
>
> TRAVEL THE WORLD
> Conquer 48 cities across six continents: topple the Eiffel Tower in Paris, the Statue of Liberty in New York, the Sydney Opera House and many more. Festival cities unlock along the way.
>
> LANDMARKS FIGHT BACK
> Every landmark has a guardian. Dodge stomps, beams and fireballs, then swallow the guardian before you take the prize.
>
> A NEW CHALLENGE EVERY DAY
> Eleven daily mini-games rotate: stampedes, gold rush, snake, whack-a-mole, sky hop, sliding puzzles, siege defense and more.
>
> UPGRADE AND COLLECT
> Spend coins on size, speed, time and magnet upgrades. Collect saucers, hole skins, bite effects and trails.
>
> QUICK TO PLAY
> Drag one finger to move. Rounds last about a minute, perfect for short breaks. Play offline; ads load only when available.
>
> Available in English, Spanish, Portuguese, French, Indonesian and Vietnamese.

**Category:** Game › Casual · **Tags:** Arcade, Casual, Offline
**Contact email:** phucpdbk@gmail.com
**Privacy policy:** https://phucpdbk.github.io/hole-munch/privacy.html

## App content answers (draft — confirm in Play Console)

- **Ads:** Yes, the app contains ads (AdMob interstitial + rewarded).
- **App access:** All functionality is available without special access.
- **Target audience:** 13+ / general audience, not designed for children (see the audience note in ANDROID-RELEASE.md).
- **Content rating (IARC):** cartoon/fantasy destruction, no blood, no user interaction, no gambling or real-money purchases. Expect Everyone / PEGI 3–7.
- **Data safety:** follow the draft in ANDROID-RELEASE.md (AdMob collects device IDs, approximate location, app interactions and diagnostics; encrypted in transit; no account deletion flow because there are no accounts).
- **Government / financial / health features:** None.
