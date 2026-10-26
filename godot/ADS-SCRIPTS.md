# Hole Munch — ad video scripts

Short vertical ads (9:16, 1080×1920, 15–30 s) for TikTok, Reels, Shorts and UA
networks. Every on-screen line is English (international stores first); the
footage is real gameplay recorded by `scripts/ad_capture.gd` /
`scripts/ad_daily.gd` and cut by `tools/make-ad-videos.ps1`.

Rules every script follows:

- **Hook in the first second**: a question or a dare on screen before anything
  happens. No logo intro.
- **Curiosity gap**: the caption promises something ("wait for it…", "is it
  eating PARIS?!") and the payoff lands 5–15 s later.
- **One fail or twist per ad**: the wrong gate, the wrong cow, moving on red,
  the monster stealing a puppy. Fails are what people comment on.
- **Big, short captions** (max ~5 words a line), centred in the top third so
  the platform UI never covers them.
- **End card** (2.5 s): icon, HOLE MUNCH, "Eat the whole world", PLAY FREE.
- No fake numbers ("99% fail") and no claims the game does not back up.

Captions are timed to game events, not the clock, so they stay in sync if the
gameplay changes.

## Main maps

| # | Ad | City | Hook | Beats | Payoff |
|---|----|------|------|-------|--------|
| M1 | `eat-paris` | Paris | "This hole is very hungry…" | eats cones → "a bench?" → cars → "it's getting BIGGER" → guardian → "wait… is it eating PARIS?!" | Eiffel Tower trembles, gets sucked in: "BYE BYE EIFFEL" |
| M2 | `boss-fight` | New York | "The city sent a BOSS" | guardian hops the roofs and blasts the saucer: "OUCH!" → "Eat it back!" | cling: "TAP TAP TAP!" → it drops in: "GULP." |
| M3 | `liberty` | New York | "Can a hole eat Lady Liberty?" | big hole rolls across the plaza: "Only one way to find out" | tremble, vacuum, burp, banner: "…yes it can" |
| M4 | `wrong-gate` | Sydney | "Pick a gate. Quick!" | green ×1.5: "EASY" → next pair: "this one looks fine…" | red −30%: "NOOOO" / "Would you pick better?" |
| M5 | `rush-hour` | Paris | "Traffic jam in Paris?" | the jam rolls in: "Leave it to me" | the hole eats its way through: "Traffic: solved" |
| M6 | `sydney-growth` | Sydney | "Start tiny…" | autopilot at 1.6×: "…eat everything…" | "…eat the OPERA HOUSE" |

## Daily games (one new game every day)

| # | Ad | Hook | Beats | Twist / payoff |
|---|----|------|-------|----------------|
| D1 | `daily-findcow` | "Find this cow." (the cow card) | roams the farm, radar warms: "Warmer…" | bites a look-alike: "THAT'S NOT HER!" → "HOTTER!" → "FOUND HER!" |
| D2 | `daily-redlight` | "Red light… green light!" | eats on green: "GO GO GO" | "RED! Don't move!" → it moves anyway: "…oops" |
| D3 | `daily-skyhop` | "How far can a UFO fly?" | tap-hops through gaps: "10!" "20!" | crashes: "…not that far" / "Beat my score" |
| D4 | `daily-slide` | "Can you solve it?" | board shown, pause: "Think…" | the solver slides it clean in par: "Big brain" |
| D5 | `daily-snake` | "Collect ALL the pets" | the line grows: "so cute" | the gobbler wakes up: "uh oh…" → bite: "HEY! My puppy!" |
| D6 | `daily-mole` | "Whack-a-mole… but you EAT them" | moles pop, the hole snaps them up | golden mole: "GOLDEN ONE!" |
| D7 | `daily-siege` | "The army fights back" | auto-fire downs helicopters: "pew pew" | holds still under one: "Steal their helicopter!" |
| D8 | `daily-beam` | "Put the landmarks back. Easy?" | beams up a landmark | drops it on the wrong city: "WRONG CITY" → "Geography 101" |
| D9 | `daily-stampede` | "Eat the ducks in line" | tail first: "1… 2… 3… 4… 5!" | the mother last: "WHOLE FAMILY" |
| D10 | `daily-coinrain` | "It's raining coins!" | coins drop round the hole | bombs too: "Not the bomb!" |
| D11 | `daily-goldrush` | "Grab the gold…" | it gets heavy: "so… slow…" | the red hole races in: "BANK IT!" |
| D12 | `daily-montage` | "A NEW game every day" | 2.5 s of each daily, its name on screen | "Which one is your favourite?" |

## Recording

```powershell
powershell -File godot/tools/make-ad-videos.ps1            # every ad
powershell -File godot/tools/make-ad-videos.ps1 -Ads daily-findcow,eat-paris
```

Raw clips (AVI + key-frame PNGs) go to `godot/test-output/ads/`, finished MP4s
to `godot/test-output/ads/final/`.
