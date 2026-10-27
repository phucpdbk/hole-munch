# Hole Munch — animated ad scripts

Cartoon story ads (9:16, 25–35 s) in which animated characters set up a joke
and real gameplay pays it off. Each shot is one of:

- **ANIM**: an animated cartoon shot (keyframe from an image model, animated by
  an image-to-video model, 4–8 s each).
- **GAME**: real gameplay, already recorded by `tools/make-ad-videos.ps1`
  (`test-output/ads/*.avi`, clip and time range given).
- **CARD**: the end card (`endcard-09-en.avi`).

On-screen text is English; VO lines are short so they can be generated as TTS
or by the video model's own audio. Plain gameplay ads live in
[ADS-SCRIPTS.md](ADS-SCRIPTS.md).

## Cast (match the existing key art in `assets/facebook/`)

| Character | Look | Personality | Voice |
|---|---|---|---|
| **ZIB** | Lime-green alien, two antennae with round tips, huge white eyes, big toothy grin, flies a silver saucer with cyan lights and a clear bubble canopy | Always hungry, cheerful, a bit dim. Treats Earth like a buffet | High, fast, giggly. Catchphrase: "MUNCH TIME!" |
| **KING QUACKERS** | Giant fluffy yellow duck, golden crown, orange beak, always in a white bubble bath with a bath brush | Vain royal diva, the city's guardian. Panics loudly | Pompous, honking. "How DARE you!" |
| **BELLA** | Brown cow, flower crown, yellow bell (matches the in-game cow card) | Sassy | "Moo." (deadpan) |
| **SGT. PIGEON** | Grey pigeon in a tiny police cap and whistle | Strict driving instructor | Squeaky whistle, "RED MEANS STOP!" |

Style for every keyframe: premium stylized 3D cartoon (Pixar/Illumination-like
toy look), glossy rounded forms, saturated cyan / sunny yellow / violet palette,
the violet-rimmed black hole from the game, toy-like miniature cities. No text
in generated frames: captions are added in the edit.

---

## A1 — "Snack Time" (28 s) · main map, Paris

Hook: a hungry alien looks at Earth like it is a doughnut.

| # | Time | Type | Picture | VO / SFX | Caption |
|---|------|------|---------|----------|---------|
| 1 | 0–3 | ANIM | Inside the saucer: ZIB's stomach growls so hard the saucer shakes. He opens an empty space fridge: one sad sock | *GRRRROWL* · ZIB: "Nothing to eat…" | so… hungry… |
| 2 | 3–6 | ANIM | ZIB looks down through the canopy at Earth; it turns into a frosted doughnut in his eyes; drool drips on the glass | ZIB (gasp): "Ooooh." | |
| 3 | 6–8 | ANIM | He slams a big red button labelled with a hole icon. A tiny black hole drops onto a Paris street | *BLOOP* · ZIB: "MUNCH TIME!" | MUNCH TIME! |
| 4 | 8–18 | GAME | `growth-09` 0–10 s (sped up): cones, cars, buildings vanish | crunch SFX, upbeat music | it's getting BIGGER |
| 5 | 18–22 | ANIM | A Parisian at a café holds a baguette; it is sucked out of his hand, then his beret, then his table | "Mon baguette!" | |
| 6 | 22–25 | GAME | `growth-09` tremble → Eiffel Tower swallowed | big rumble | BYE BYE EIFFEL |
| 7 | 25–27 | ANIM | ZIB pats his round belly and burps; a tiny Eiffel Tower tip pops out of his mouth | *BUUURP* · ZIB: "Next city!" | |
| 8 | 27–30 | CARD | End card | jingle | PLAY FREE |

## A2 — "Royal Bath" (30 s) · boss fight, New York

Hook: a king duck relaxes in his bath; the plug is a black hole.

| # | Time | Type | Picture | VO / SFX | Caption |
|---|------|------|---------|----------|---------|
| 1 | 0–4 | ANIM | KING QUACKERS in a bubble bath on a New York rooftop, cucumber slices on his eyes, humming | QUACKERS: "Ahh, royal spa day." | |
| 2 | 4–7 | ANIM | He pulls the bath plug; instead of water draining, the plug hole glows violet and grows | *SHLUUURP* | wait… |
| 3 | 7–10 | ANIM | ZIB's saucer hovers over it, waving | ZIB: "Hiii! Is that your city?" | |
| 4 | 10–12 | ANIM | QUACKERS leaps out, furious, crown askew | "How DARE you! GUARDS!" | |
| 5 | 12–19 | GAME | `boss-24` 0–7 s: the guardian hops the roofs and blasts the saucer | ZIB: "Ow! Ow!" | IT CAN JUMP?! |
| 6 | 19–24 | GAME | `cling-24` 2–7 s: guardian hangs on the rim, TAP TAP TAP | tapping SFX | TAP TAP TAP! |
| 7 | 24–27 | ANIM | QUACKERS slides into the hole like a water slide; his crown spins up and lands on ZIB's head | QUACKERS: "Not the craaaown!" · ZIB: "Ooh, shiny." | |
| 8 | 27–30 | CARD | End card | | PLAY FREE |

## A3 — "Where's Max?" (30 s) · daily game, Find the cow

Hook: a farmer begs for help finding his cow. The edit calls her Max, the name
the in-game cow card shows (BELLA's look, Max's name).

| # | Time | Type | Picture | VO / SFX | Caption |
|---|------|------|---------|----------|---------|
| 1 | 0–3 | ANIM | A farmer holds up a "MISSING" poster of BELLA (flower crown, yellow bell) to the camera | FARMER: "Have you seen Max?!" | |
| 2 | 3–5 | ANIM | ZIB salutes from the saucer, sunglasses on | ZIB: "Leave it to me." | |
| 3 | 5–7 | GAME | `daily-findcow` 0–2 s: the cow card | | Remember her! |
| 4 | 7–12 | GAME | `daily-findcow` 3–8 s: the saucer roams the farm | bell ringing | warmer… |
| 5 | 12–14 | ANIM | ZIB beams up a cow; it's a look-alike wearing the wrong hat, who stares at him in disgust | WRONG COW: "Moo." (offended) · ZIB: "Oops." | NOT HER! |
| 6 | 14–20 | GAME | `daily-findcow` 12–18 s: radar heats up, the right cow found | | HOTTER! |
| 7 | 20–24 | ANIM | BELLA beamed into the saucer, sitting next to ZIB, both wearing sunglasses | BELLA: "Moo." (pleased) | FOUND HER! |
| 8 | 24–26 | ANIM | The farmer reads a new poster: 50 cows | FARMER: "…and these ones?" | NEW GAME EVERY DAY |
| 9 | 26–29 | CARD | End card | | PLAY FREE |

## A4 — "Driving Test" (28 s) · daily game, Red light green light

Hook: an alien takes a driving test.

| # | Time | Type | Picture | VO / SFX | Caption |
|---|------|------|---------|----------|---------|
| 1 | 0–3 | ANIM | SGT. PIGEON with a clipboard climbs into ZIB's saucer, nervous | PIGEON: "Saucer driving test. Rule one: RED MEANS STOP." | |
| 2 | 3–5 | ANIM | ZIB gives a big thumbs-up, wearing a learner sign | ZIB: "Easy!" | |
| 3 | 5–12 | GAME | `daily-redlight` 0–7 s: eats on green, stops on red | whistle | GREEN = GO |
| 4 | 12–15 | ANIM | Red light. ZIB freezes, sweating; a single watermelon rolls right next to the hole | ZIB (whisper): "Just… one… bite…" | don't do it… |
| 5 | 15–18 | GAME | `daily-redlight` strike moment: "CAUGHT" | *FWEEEET* | …oops |
| 6 | 18–22 | ANIM | SGT. PIGEON faints backwards; his clipboard reads a giant red F | PIGEON: "*thud*" | |
| 7 | 22–25 | ANIM | ZIB, cheeks full of watermelon, shrugs | ZIB: "Worth it." | Could YOU stand still? |
| 8 | 25–28 | CARD | End card | | PLAY FREE |

## A5 — "Wrong Door" (22 s) · main map, gates, Sydney

Hook: a choice between two glowing gates.

| # | Time | Type | Picture | VO / SFX | Caption |
|---|------|------|---------|----------|---------|
| 1 | 0–3 | ANIM | ZIB faces a green and a red gate, eeny-meeny-miny-moe with his antennae | ZIB: "Eeny, meeny…" | Pick a gate |
| 2 | 3–6 | GAME | `gates-41` 0–3 s: through ×1.5 | power-up SFX | BIGGER! |
| 3 | 6–8 | ANIM | ZIB, cocky, flexes in the canopy | ZIB: "I'm a genius." | |
| 4 | 8–11 | GAME | `gates-41` 4–7 s: into −30% | deflate SFX | |
| 5 | 11–15 | ANIM | ZIB and the saucer shrink to a pea; his voice goes chipmunk | ZIB (tiny): "Hellooo?" | NOOOO |
| 6 | 15–18 | ANIM | A seagull looks at the tiny saucer like a snack | *SQUAWK* | |
| 7 | 18–21 | CARD | End card | | Would YOU pick better? |

## A6 — "Mom Said No Snacks" (30 s) · daily montage

Hook: Zib's mom forbids snacks; he finds 11 loopholes.

| # | Time | Type | Picture | VO / SFX | Caption |
|---|------|------|---------|----------|---------|
| 1 | 0–3 | ANIM | ZIB's mom (bigger alien, curlers in her antennae) points a spatula | MOM: "No snacks before dinner!" | |
| 2 | 3–5 | ANIM | ZIB, innocent face, holding the saucer controls behind his back | ZIB: "Snacks? Never." | |
| 3 | 5–24 | GAME | Montage, 1.7 s per daily (`daily-*-clean`), each named | quick cuts on the beat | A NEW GAME EVERY DAY |
| 4 | 24–27 | ANIM | MOM opens the fridge: a cow, a duck family, a pile of gold and a mole stare back | MOM: "ZIB!!!" | |
| 5 | 27–30 | CARD | End card | | Which is YOUR favourite? |

---

## Production pipeline

1. **Character sheets** (image model, our Gemini key works): front/side/expression
   sheet for each character, using the Facebook key art as references, then
   approved by you before any animation.
2. **Keyframes** (image model): one 9:16 frame per ANIM shot from the sheets,
   about 25 frames for A1–A6.
3. **Animation** (image-to-video model): each keyframe animated 4–8 s with the
   shot's action in the prompt. Needs a video API (see below).
4. **Voice** (Gemini TTS works on our key, or the video model's own audio).
5. **Edit** (ffmpeg, scripted like `make-ad-videos.ps1`): ANIM + GAME + CARD,
   captions, music, 1080×1920 MP4.

## Setup

- **Images**: `node godot/tools/ads/cartoon.mjs sheets [zib quackers bella pigeon]`
  uses the Gemini key of `tools/meshy/gemini.local.json`; sheets land in
  `godot/test-output/animated/characters/` (a new `-vN` each run).
- **Animation and sound**: Kling AI API (Kling 3.0 image-to-video, text-to-audio).
  Put the API key in `godot/tools/ads/kling.local.json` (git-ignored):
  `{"key": "api-key-kling-..."}`.

Each ad is one file, `godot/tools/ads/shots/<ad>.json`: its shots (keyframe and
motion prompts), voices and lines, sounds, and the edit list. Then:

```powershell
node godot/tools/ads/cartoon.mjs keyframes a1-snack-time   # Gemini, review these first
node godot/tools/ads/kling.mjs animate a1-snack-time       # ~0.8 units per second at 1080p
node godot/tools/ads/voice.mjs a1-snack-time               # Gemini TTS lines
node godot/tools/ads/kling.mjs sounds a1-snack-time        # SFX + music loop, 0.25 units each
node godot/tools/ads/assemble.mjs a1-snack-time            # -> test-output/animated/<ad>/<ad>-vN.mp4
```

An entry's `captionTop` (share of the height, default 0.13) moves its caption,
e.g. 0.6 under a daily game's HUD; long captions shrink to fit the width. GAME entries point at caption-free gameplay (`--ad-clean` recordings in
`test-output/ads/`); a redone shot only needs its own `animate <ad> <shot>`.
