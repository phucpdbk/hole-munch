# Hole Munch — Earth Invasion (Godot playtest)

Android store builds: see [ANDROID-RELEASE.md](ANDROID-RELEASE.md) for the API 36
release AAB pipeline, AdMob IDs, upload signing, consent/privacy and verification.

An alien saucer drops a black hole on Earth. Swallow each city, grow, then swallow
its landmark to conquer it, while dodging independent military defenders.

- **6 continents × 8 cities = 48 levels, plus 8 festival cities** (Asia, Europe, Africa, North America,
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
  The boss size comes from the map's own food: the hole must eat 30% of it
  at the start, rising to 49% (`campaign.gd` `share_at`), landmarks 3.0–6.6,
  finales up to 7.2 (still under the hole's 8.5 cap).
  Blocks around the plaza are 24/31/38 units street to street
  (`map_layout.gd`) and sparsely built: about a quarter of shop lots stay
  empty, commercial blocks only front the north and south streets.
- **Shaped cities** (`map_shapes.gd`, `map_layout.gd`): from city 4 on, some
  grid cells are water — a bay, a lake, a river, a canal — chosen per grid size
  and mirrored per city, so a map is no longer a rectangle. The hole's centre
  stays a little off the shore (`clamp_point` slides it along), streets with
  water on both sides disappear unless bridged, and traffic, signals, squads,
  roadblocks (never at a bridge end), drop points, gates and pickups only use
  streets that exist. The rival, the par route and the ad autopilot steer round
  the water (`steer`: corners of the water plus a short Dijkstra); the guardian
  routes over existing street stretches only. `--campaign-smoke --shapes`
  checks every city (reachable blocks, nothing in the water, shore push-out,
  the rival's way to the landmark) without the slow routes;
  `-- --capture --shape-capture [--levels=4,48]` shoots each city whole and at
  its opening street (`test-output/shape-XX.png`). Boats (`boats.gd`: sampans,
  sailboats, ferries, gondolas by continent) drift and rock on the water; only
  a hole big enough to reach out from the shore can eat one (optional food).
- **Festival cities** (`campaign.gd` `HOLIDAYS`, `festive.gd`,
  `festive_models.gd`): eight extra stops, after the 48 cities in save order:
  Lunar New Year in Saigon and Mid-Autumn in Hội An (Asia), Valentine's in
  Verona and Christmas in Nuremberg (Europe), Halloween in Salem (North
  America), Easter in Sydney (Oceania), then the Durbar in Kano (Africa, after
  Lagos) and Carnaval in Salvador (South America, after Rio). New festivals go
  on the end of `HOLIDAYS` so saved festival indices never shift. Each hangs off the city before it on
  the journey map (a pink side trip), opens when that city is beaten, never
  blocks the route, and plays at that city's difficulty rank with its own
  landmark, guardian, weather, colours (Mid-Autumn, Halloween and Carnaval at
  dusk), water and shape (Verona's Adige, Hội An's Thu Bồn, Kano's dye pits,
  Salvador's Bay of All Saints) and the same food share. Trees,
  benches and opening cones become the holiday's trees, stands and snacks at
  the same size, so food totals match. NEXT after the opening city goes to the
  festival while it is unbeaten. Festival guardians: a banh chung (Tết), a lion
  dance lion (Mid-Autumn), a cupid (Valentine's), a snowman (Christmas), a
  pumpkin-head scarecrow (Halloween), an Easter bunny, a Durbar rider (Kano)
  and a Carnaval dancer (Salvador), all Meshy rigs with the six clips; every
  festival landmark is a Meshy bake too (Kano: the Emir's palace gate with
  royal parasols and a decked Durbar horse; Salvador: a Carnaval float with a
  giant feathered mask and drums).
- **Weather** (`weather.gd`): rain and storm add a dense screen layer of
  streaks (`shaders/precipitation.gdshader`) over 3D drops and ground
  splashes; snow uses parallax flake layers plus soft 3D flakes. Fog covers
  the screen with a drifting veil (`shaders/fog_veil.gdshader`) that only
  clears a small window around the saucer (it widens as the hole grows) and
  hides the minimap. `-- --capture --weather-capture` shoots rain, fog, snow
  and storm mid-round.
- **Timer** = par × 3 early, falling to ×2.4 late, never below 48 s early /
  40 s late. Par is how long a real-time greedy route (`smoke.gd`, the same
  food-per-distance choice the rival makes, no clock bonus) needs at player
  speed, 14–206 s. Par times live in `campaign.gd` (`PAR_SECONDS`); regenerate them
  from `--campaign-smoke` output (`PAR` lines) after changing map contents.
- **The clock never refills in campaign or daily rounds**: no combo time, no
  +5 s pickup (both stay in endless only). The only extras are the small time
  upgrade (+2 s per level, 5 levels) and the one rewarded-ad revive below.
  Best combo raises the coin reward by 1% per bite (up to +60%).
- **Swallowing the landmark wins at once**; every second left pays 2 coins. The
  clean 75%/90% goals therefore mean clearing the city before the landmark.
- **Opening street** (`game.gd` `make_opening`): start radius 0.95, a bench at
  each end of the starter snacks, and one of four shapes per city (row, east or
  west L, split street); defender squads also change corner per city.
- **Random drop point** (`spawn_points.gd`): each campaign/endless round (retries
  too) the saucer drops onto a random inner street segment, clear of the
  landmark, its guardian, and the rival's corner; the opening cones
  move with it as a row on that street. Daily games, smoke and captures keep the
  designed opening street. `-- --campaign-smoke --spawn-bench` times the par
  route from each city's farthest drop point (all still finish 40 s+ early).
- **Guardian boss fight** (`mascot.gd`, `mascot_attacks.gd`, `mascot_rig.gd`):
  the guardian walks only along streets and its plaza (`mascot_roads.gd`, never
  through blocks; a leap flies over one but lands on a street): it patrols the
  crossings, hunts the hole within 22 units by the shortest street route
  (Dijkstra over the crossings), circles it at its style's range (stomp up close,
  beams at about 5.5) and leads a moving saucer by 0.6 s. When the streets go
  more than 1.6× the straight distance round a block, it hops the roofs (every
  3 s at most), lands beside the hole and strikes 0.35 s later. Attacks come
  every 2.3 s × the continent's defence scale. It runs home when the
  hole nears the landmark (minimap diamond). It takes three bites: the first two
  knock it away (hearts on the HUD). Attacks: fire, water and lightning beams up
  at the saucer (`shaders/attack_beam.gdshader`: flowing water, flickering fire,
  a cored bolt; splash, embers or sparks where they hit, a charge glow before),
  a leap that rams it, a stomp ring and a charge. A hit rocks the
  saucer, shakes the camera and shoves the hole. `-- --capture --guardian-capture`
  shoots every style. The first city has no guardian (`mechanics.gd`
  `GUARDIAN_FROM`): it is only eat, grow and swallow the landmark; the guardian
  and its intro card join from city 2. Every city and festival has a Meshy guardian (`assets/mascots/<id>.scn`, auto-rigged,
  clips idle/walk/run/attack = Charged Spell Cast/hit = Hit Reaction/leap = Jump Attack, fixed in
  `KINDS.mascots.actions` of `tools/meshy/meshy.mjs` (idle=0,attack=125,hit=178,leap=86),
  baked by `tools/bake_mascots.gd`, scaled to the toy rig's two-unit height);
  the toy rig is only a fallback. `--mascot-capture --levels=0,4` shoots chosen cities
  (idle, windup, attack and mid-beam frames). Meshy prompts must not ask for
  effects ("spray water"): Meshy bakes them into the mesh.
- **Showtime** (`showtime.gd`), the clip-friendly moments: the guardian's last
  bite leaves it hanging on the far rim (mascot `cling`) with a TAP TAP TAP prompt;
  six taps (or 3.2 s) drop it, the hole holds still and the clock waits meanwhile.
  A campaign landmark goes down in a held cinematic: it trembles, loose food
  near the hole is vacuumed in (score only, no completion), the camera swings
  round and in while the saucer climbs out of the shot, the landmark tips in,
  the hole burps and a "<CITY> CONQUERED!" banner plays before the result. People
  and cars at the rim shout lines from `shout_people`/`shout_cars`. Smoke runs switch it
  off (`showtime.enabled`); `check_showtime` in `smoke.gd` covers it.
- **Street events** (`street_events.gd`, campaign and endless only): RUSH HOUR
  rolls a jam of 16 local vehicles (`models.gd` `jam_vehicle`: yellow cab, London
  cab, double-decker, tuk-tuk, school bus; two kinds per continent) onto a street
  near the hole once it can eat a cab, from 10 s in. They are bonus food: score
  and growth, never completion. Two gate pairs per round stand across inner
  streets, a green ×1.5 and a red −30%; the half the hole's centre drives
  through fires and the pair folds away. ×1.5 stops at 90% of the size the
  landmark needs. Off in smoke runs; `check_street_events` covers them.
- **Progress chip** (`hud.gd`): growth toward the landmark (catches in a daily
  game) is a small chip under the score instead of a bar along the bottom: the
  percentage (gold from 80%, green at 100%), the guardian's hearts and the
  rival's share beside it.
- **Bonus run** (`runner.gd`, `runner_props.gd`): the first win on every fifth
  city (5, 10, …) turns PLAY into BONUS RUN. The hole rolls up a 3×31 map's
  middle avenue on its own (about 42 s, speeding up from 10 to 15 units/s); the
  player only steers sideways (14 units/s). Each half of the road has its own
  sparse food, growing from cones to towers. The cross streets repeat a beat of
  four: a gate pair (×1.2/−20%, ×1.1/×1.05, …; from 40% of the course on a pair
  swaps sides every 0.8 s until the hole is 16 units away) with a roadblock on
  one half past it and a coin line leading into that; a free coin line; a
  roadblock sliding from side to side (from 20% on; coins before that); a boost
  pad on one half (×1.35 speed and double coins for 2.5 s) with coins over it.
  Driving into any roadblock costs 20% of the hole's size. Roadblocks and coins
  grow along the course so they read next to a big hole. The city's landmark
  waits at the far end, sized from a simulated run that eats 65% of what fits
  and takes the better gates, never above 90% of what the size cap can eat;
  too small at the end loses. It pays coins only (no stars or goals): food,
  1 per picked coin and 60 for the landmark, up to 120 when the hole arrives
  twice the size it needed. PLAY afterwards goes on to the next city.
  `check_runner` in `campaign_smoke.gd` drives a better-gate bot (wins, reads
  the sliding roadblocks and dodges every one), the same bot hitting one late
  roadblock (still wins) or four (loses) and a worse-gate bot (falls short);
  `-- --capture --run-capture` writes `test-output/run-*.png`.
- **Ad clips** (`ad_capture.gd`, `tools/make-ads.ps1`): portrait 720×1280 AVIs
  plus key-frame PNGs in `test-output/ads/`, English by default (`-Lang es` etc.),
  HUD hidden (score popups drawn by showtime instead). Presets `conquer` (drive
  into the landmark), `cling` (tap the guardian loose), `growth` (the whole city
  on autopilot at 1.6× speed), `rushhour` (the jam rolls in and gets eaten) and
  `gates` (through ×1.5, then into −30%);
  default cities Paris, New York and Sydney (`-Levels 8,24,40`). The script
  swaps in a temporary portrait `override.cfg`; with ffmpeg on PATH it also
  writes MP4s.
- **Level catalog** (`catalog_capture.gd`): `-- --capture --catalog` (optional
  `--levels=0,4`) shoots every city (landmark with its guardian, guardian close
  up, menu) into `test-output/catalog/` with each city's landmark, guardian,
  weather, map and goal data. Review it with `node godot/tools/catalog/serve.js`
  (http://localhost:8766): filters, a keep/change/redo verdict and notes per
  city (kept in the browser), and Export copies the notes as Markdown.
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
- **Star gates**: each continent after the first needs 16 more stars in total (two per city on average, so some goals get replayed).
- **Defence scales per continent** (`defense.gd`): warnings shrink from 1.25 s
  to 0.8 s, up to 5 simultaneous shots, opening grace drops from 8 s to 0,
  later gunners lead a moving hole, and each hit also shrinks the hole by 6%.
- **National forces** (`army_forces.gd`, `army.gd`, `army_visual.gd`,
  `army_models.gd`): every city fields its country's own force at the inner
  crossings (not next to a roadblock), in place of the old tank-and-rifle
  squads. About 30 countries each have their own colours (police uniform and cap band,
  patrol car livery: stripe, two-tone or checker, light bar; soldier camo,
  helmet, vehicle paint, one flag accent; no real insignia). The force grows
  by city: police only (cities 1-2), then soldiers and a missile truck, rocket
  troops (6+), flak guns (9+), tanks (17+), up to 18 soldiers, 7 rocket
  troops, 3 missile trucks, 2 flak guns and 2 tanks. Every weapon shoots the
  saucer, never the ground, with its own dodge: rifle bursts at where it is
  (keep moving), slow rockets and tank rounds aimed a little ahead (sidestep),
  flak aimed fully ahead that bursts in the air (turn), and the missile lock:
  a saucer that stays below 1.2 u/s near a truck for 2.0 s (1.0 s late) gets a
  red reticle and "LOCKED ON"; still after another 1.2 s (0.6 s late) a homing
  missile flies in and always lands (a reel plus a second shrink). Damage
  points drain over time; 10 reel the saucer like a defence blast. Guns share
  the opening grace and hold fire while a guardian clings. Units are edible
  (foot units from the start). `-- --capture --army-capture [--levels=0,8]`
  shoots a volley, the lock and the missile per city;
  `--script tools/check_army.gd` checks rosters, liveries and every weapon.
  Vietnam's police and soldiers are Meshy characters (`army_soldiers.gd`,
  `assets/soldiers/vn_police.scn`, `vn_soldier.scn`; `tools/meshy/meshy.mjs
  soldiers all`, then `tools/bake_mascots.gd -- soldiers`): rigged, 3k triangles,
  512 px textures, a rifle on the right-hand bone; they stand `alert`, hold the
  first frame of `aim` while the saucer is in reach and play `panic` when the
  hole is within 1.6 units. Other countries keep the primitive toy units.
  `--script tools/preview_soldiers.gd` (windowed) writes a clip contact sheet.
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
  Mini-games by date (eleven, `Campaign.DAILY_TYPES`).
  **Classic games with the saucer** (fixed starting hole, checked in
  `classic_daily_smoke.gd`). Each plays on its own themed map instead of a city
  (`theme_maps.gd`, like the cow hunt's farmland): the street grid stays as
  paths and the blocks are decorated by theme, every decoration too big to
  swallow, with no buildings, traffic or army. `-- --capture --classic-capture`
  shoots all three, the pets close up and each harder garden (`test-output/classic-*.png`).
  **Saucer snake** (`snake_trail.gd`, 90 s, a garden) — the saucer never stops
  (an idle stick keeps its last direction). Pets (puppy, kitten,
  piglet, bunny, chick: chibi Meshy rigs standing on two legs, the `critters`
  kind of `tools/meshy/meshy.mjs`, baked by `bake_critters.gd` into flipbook
  frames of their idle, walk and run clips, about 1,570 triangles each, and drawn
  by `pet_flock.gd` as one MultiMesh per kind, clip and frame with no shadows, so
  no skeleton runs in the game; `critters.gd` picks the clip by speed and falls
  back to primitive animals with swinging legs when the frames are missing) roam
  the garden, resting, wandering and bolting from a saucer within
  5. Glide over one to catch it and it joins the line, hopping along the hole's
  path 1.1 apart; a new pet appears elsewhere. Monsters, the Meshy "gobbler"
  (`assets/mascots/gobbler.scn`, a rigged villain from the `monsters` kind of
  `tools/meshy/meshy.mjs`, baked with `bake_mascots.gd -- monsters`, played
  through `mascot_rig.gd`), nap 3 s, then each hunts the pet nearest to it: a
  bite takes that pet and every pet behind it scatters back into the garden;
  with no pets left a monster bites 3 s off the clock. More monsters join
  during the round. Hedges, flower beds, ponds, trees and the fountain block the
  saucer, the pets and the monsters (`theme_maps.gd` `push_out`). Running into
  the line past its first 4 pets ends the run. The score is the line at the
  end; target 12 pets, 5 coins each. Reaching it unlocks the next garden for
  good (`Campaign.checkpoints` "snake"), each tier with more monsters, sooner:
  flower garden (1 monster, +1 every 30 s up to 3), hedge garden (hedged rooms,
  1, every 25 s, up to 4), pond garden (rooms round a pond, 2, every 22 s, up
  to 4) and hedge maze (a perfect maze in every block, 2, every 18 s, up to 5).
  The camera sits at 0.75 of the city zoom. **Mole munch** (`mole_patch.gd`, 60 s, a
  vegetable patch: furrowed soil, carrot and cabbage rows, scarecrows) —
  whack-a-mole: moles pop out of 16 mole hills on the dirt paths 3.5–14 from
  the hole for 3 s (down to 1.3 s as catches add up), two at a time and three
  from 10 catches; golden moles pay 3 and stay up for less, gas bombs pop up
  too; target 25. **Red light, green light** (`red_light.gd`, 75 s, clear
  weather, a blue running track with striped turf, stands and flags) — 44
  fruits (watermelons pay 3), a light ring round the hole and a traffic light
  with a coloured beacon on every crossing: green 2.4–5 s, yellow 0.8 s, red
  1.5–3 s (greens shorten and reds lengthen as fruit goes down); moving on red
  after a 0.3 s grace costs 3 points and a 1.2 s freeze, three strikes end the
  run; target 30.
  **Beam & drop** (`beam_drop.gd`, 90 s, clear weather, fixed hole, a world
  map from `beam_yard.gd` on a 5×3 field: ocean, with the continents of the
  `world` region of `world_map_data.gd` (`tools/geo/make_world_map.cjs`) as
  low slabs, and the 48 regular campaign cities at their real longitude and
  Mercator latitude; the minimap draws the land; the camera stands 1.3× back;
  checked in `beam_smoke.gd`) — a geography lift-and-drop. Each map pins a
  few cities at least 5 apart (a plinth, a map pin and the city's name), not
  pinned before this round while others are left. Their landmarks (Meshy
  bake or primitive model, on a little stand) float at sea 4–14 from the
  saucer. A quick tap (touch let go within 0.3 s and 14 px, a mouse click or
  Space) beams up the landmark under the saucer (the saucer slows to 0.9
  while carrying; the HUD names it); a second tap sets it down. On a pin it
  stays only if it is that city's landmark: a wrong pin costs 2 s and blinks
  the right one for 2 s (pins only light up under the saucer, never green or
  red). Anywhere else it stays where it lands. A full map adds 6 s and brings
  the next: 3 pins, then 4 with a decoy, 5 with 2, then 6 with 2 (repeating);
  a decoy's city is at least 5 from every pin. Target 12 landmarks, 5 coins
  each. `-- --capture --beam-capture` shoots `test-output/beam-*.png`. The daily rotation shuffles every mini-game into
  each cycle of `DAILY_TYPES.size()` days (`Campaign.daily_type`), so each
  comes up once per cycle.
  **Checkpoints**: the ladder games keep their furthest point for good
  (`Campaign.checkpoints`, `reach_checkpoint`): the slide puzzle's board, the
  siege's stage, the sky hop every 10 gaps and the cow hunt's level. A run
  starts there; finishing a whole ladder starts a new lap (new boards, a new
  course) from the beginning. Those ladders are the same for everyone (seeded
  by lap, not by day).
  **Duck families** (stampede): four mother ducks wander with lines of five
  ducklings. Ducklings eaten from the tail of an unbroken line chain 1–5
  points; a mother eaten after all her ducklings pays 5 ("whole family"), one
  eaten first pays 2 and scatters her line into fleeing ducklings worth 1.
  Target 30 points, 3 coins a point.
  **Gold rush**: swallowed gold is carried (each point slows the hole 4%, down
  to half speed) and only counts once banked in the glowing ring on the plaza;
  the rival hole touching the player takes everything carried. Target 30.
  **Find the cow** (`cow_hunt.gd`): a herd on countryside farmland instead of a
  city (`countryside.gd`: forest north, cornfield east, farmyard south, wheat
  west, meadow in the middle, each zone signposted; cows graze outside the
  forest), each cow with a coat, a hat and a bell (27 looks). A card shows the
  named cow's look before the first move (and again for a moment after a wrong
  bite); then a warm/cold bar under the clock and a bell that rings faster
  near it guide the search. A wrong cow costs 3 s and a short chew, five end
  the round. Each find adds 10 s and raises the level: 8 cows on show plus 4 a
  level, and a named cow that shares more of its look with the others. The
  round runs until time or wrong bites run out; stars at 1, 2 and 4 finds.
  The hole keeps its starting size and the minimap gives no help.
  `-- --capture --cow-capture` shoots the card and the radar.
  **Sky hop** (`sky_hop.gd`): a one-tap side view high above the city with the
  default saucer. It flies right on its own, gravity pulls it down and each
  tap (or Space) hops it up; gaps open between towers and storm clouds, 5.4
  high narrowing to 4.0 by gap 25, some drifting up and down from gap 12. The
  course runs through five maps of 20 gaps, each with its colours and, on
  every other gap from its third, a hazard: rooftops (none), desert canyon
  (sand gusts push up or down between the gates), snow peaks (an icicle drops
  1.2 into the gap ahead), neon night (searchlights swing from the tower
  roofs) and harbour (gulls bob between the gates). One touch of a tower, a
  cloud, a hazard or the street ends the run; stars at 10/20/30 gaps in the
  run, 5 coins a gap. The course has its own camera, made current for the
  round and its result. `-- --capture --hop-capture` shoots the test-mode
  daily list, the start and mid-flight; `--hopmaps-capture` each map.
  `--duckgold-capture` shoots the duck lines and the gold bank.
  **Slide munch** (`slide_puzzle.gd`): a turn-based puzzle on a city block high
  above the city with its own tilted camera. A swipe (arrows/WASD) slides the
  hole until a building, the edge or something bigger than the hole stops it,
  swallowing every snack that fits on the way. Snacks are size 1 and 2, the
  hole grows a size at each of the board's two growth points, and the landmark
  needs size 3. The puzzle is a ladder of 30 boards, five from each of six
  tiers (`TIERS`): 5×5 with par 3–5 up to 7×7 with more walls and snacks and
  par 12–17. Each board has its own seed and is made when it comes up (all 30
  take about a quarter of a second); a breadth-first solver keeps a layout
  whose shortest solution (par) falls in the tier's range, or the closest one.
  Every board has its own clock, 15 s plus 3 s a par slide, started by the
  first slide; running out costs one of three lives and starts that board
  over, and the last life ends the run. A run starts at the kept board; stars
  at 1, 3 and 5 boards solved in the run; 15 coins, 6 a board and 4 more for
  each board solved in par. Undo (U) and reset
  (R) are free buttons beside the board. The HUD lays the board out between
  its chips (`hud.gd puzzle_layout`) and the camera fits the biggest board to
  that frame. `-- --capture --slide-capture` shoots it.
  **Sky siege** (`sky_siege.gd`): the air force attacks the saucer over today's
  city, 90 s on the clock. The player only steers; the saucer fires at the
  nearest enemy within 8 units. Three stages (`STAGES`): helicopters (10
  points), then jets join (14 points), then flak guns and the command blimp,
  whose fall wins the run. Clearing a stage gives a life back and a 2.5 s
  breather and is kept as the checkpoint; each stage cleared so far is a star. Helicopters circle with their nose on the
  saucer and shoot (escorts turn to what they shoot), jets strafe
  along a lane that glows red for 1 s first, flak guns drop warned blasts where
  the saucer is, and the blimp fires rings. Holding still beside a helicopter
  for 0.6 s reels it into the beam: it counts as downed and flies as an escort
  that fires for 8 s. Downed enemies score 1 (helicopter), 2 (jet, flak) or 6
  (blimp) and sometimes drop a spread or rapid-fire power (5 s). Three hits end
  the run; 3 coins a point plus 15 a stage. The aircraft are Meshy models
  (`assets/aircraft`, baked by `tools/bake_aircraft.gd`, nose turned to +z),
  with block models as the fallback. The bake cuts the helicopter's main rotor
  (its top band) into `heli_rotor.res` around the hub so the game spins it. `-- --capture --siege-capture` shoots
  mid-round, the late stage, the beam and a strafing jet.
- **Extra daily tries**: with no tries left, the daily button (and PLAY on a
  daily result) offers a rewarded ad for one more try, up to
  `Campaign.DAILY_AD_TRIES` (2) a day; the record keeps them as `bonus`.
- **Daily swap**: once a day, while tries are left, a rewarded ad swaps today's
  mini-game for the day's other one (`Campaign.swap_type`, fixed per date) and
  starts it; the tries used and the ad tries are kept, the day's best starts over.
  Offered by a SWAP button between daily and endless in the menu and an offer row
  on a daily result; the record keeps the pick as `swap`. A swapped game's score
  stays off the daily leaderboard, which ranks the day's own game.
  `-- --capture --swap-capture` shoots both offers in landscape and portrait.
- **Daily streak**: a finished daily round keeps it; days 1–7 pay 20–120 coins
  and every seventh day adds a 300-coin bonus. Shown beside today's mini-game.
- **Daily leaderboard** (`play_games.gd`): Android only, with the GodotPlayGameServices
  addon v3.4.0 (godot-sdk-integrations/godot-play-game-services, release
  `addons.zip` into `addons/`, enable it, set the game id in the Android export
  preset field `godot_play_game_services/game_id`). Put the daily leaderboard id
  in Project Settings `application_custom/play_games/daily_leaderboard`. Without
  the addon or the id every leaderboard button stays hidden.
- **Reminders** (`notify.gd`): Android only, with the NotificationScheduler addon
  v6.0 (godot-mobile-plugins/godot-notification-scheduler, Android zip into
  `addons/`). One notification at 19:00 on each of the next three days, re-set
  whenever the app goes to the background, naming that day's mini-game and
  city ("Today: FIND THE COW in Paris!"; the first warns about a live streak); permission is asked after the first win and the
  megaphone button in the menu switches it off.
- **Endless** (VÔ TẬN): 60 s clock, every bite adds a little time (plus combo
  time and +5 s pickups), each landmark adds 30 s and leads to a random harder
  city; best score and cities are saved.
- **Upgrades** (NÂNG CẤP): coins buy start size (+0.04 × 6), speed (+3% × 8),
  time (+2 s × 5), magnet (× 5) and coin bonus (+8% × 8); base prices
  160/140/200/300/240, ×1.75 per level. A maxed size upgrade still cannot eat
  a shop at the start (checked in `--campaign-smoke`). Map food pays 1 coin per
  80 points on a win (200 on a loss); stars and the win pay the rest.
  Replaying a city that already has a star pays in full only when the round
  earns a star the city did not have yet (and then only the new stars);
  otherwise it pays 15% of the food coins and no star, win or time coins
  (`Campaign.REPLAY_SHARE`), so grinding an easy city stops paying.
- **Saucer skills** (`skills.gd`): in campaign and endless cities, eating fills
  an energy bar (five full bars over a whole map's food, ×1.5 from an 8-bite
  combo; a hit drains a quarter). A full bar lights the round button bottom
  right (E or Shift on a keyboard), which fires the equipped saucer's skill:
  dash (double speed 1.6 s), vacuum (+8 magnet levels 4 s), blink (jump ahead
  6 + 1.5×radius), big gulp (eat one size up 3 s, never the landmark), freeze
  (defence and rival hold 4 s) or shield (blocks hits 5 s). `SKILL_OF` maps
  the 13 saucers to these six; the wardrobe shows each saucer's skill. Daily
  mini-games, the bonus run and the cow hunt have no skill.
- **Journey map** (BẢN ĐỒ, `journey_map.gd`): one 3D continent per page in its
  own SubViewport. Land is extruded from Natural Earth 110m outlines
  (`world_map_data.gd`, generated by `node tools/geo/make_world_map.cjs`); each
  city stands at its real position (nudged apart when cities are close) on a
  plinth with its 3D landmark, greyed while locked, joined by a dotted route that
  turns gold once conquered. The player's craft hovers over the selected city;
  the side card shows weather, timer, map size, rival and goals and starts it.
  Swipe or use the arrows to change continent.
- **Conquest album** (SƯU TẬP / ALBUM, `album.gd`, a `wardrobe.gd` tab): the
  menu button (right side in landscape, under PRIVACY in portrait) opens one page
  per continent with every stop on its route, festival cities included. A
  conquered city (its landmark swallowed, `campaign.is_conquered`) shows its
  landmark render, city, landmark name and the star of each goal; a gold edge
  marks all three. Cities not yet taken are dark silhouettes with a lock. The
  header counts cities and stars over the whole journey, each continent tab its
  own stops. Tapping a conquered card opens its fun-fact landmark card. Portrait
  lays out at 540 wide and scales up so cards stay readable. Test mode reveals
  every card (the counts and stars still come from the test save).
  `-- --capture --album-capture [--lang=en]` writes `test-output/album-*.png`
  (landscape and portrait).
- **Languages** (`i18n.gd`, table in `i18n_strings.gd`): Tiếng Việt, English,
  Español, Português, Français, Bahasa Indonesia. First launch follows the phone
  language; the speech-bubble button on the menu switches it (saved).
- **Intro and tips** (`intro.gd`): a four-card story and how-to-play on first
  launch (again from the ? button), and a "new!" card before the first city with
  each new thing: rain, fog, wind, snow, storm, power orbs, hunger,
  the landmark counter-attack, the rival hole, continent finales and each new
  continent (at most one card per start, the landmark card only when nothing new
  needs explaining; seen cards are saved).
- **Result screen**: each goal with its numbers (50%/75%), where the coins came
  from, and RETRY FOR ★ on a won city that still misses a star.
- **Shop** (`cosmetics.gd`, `wardrobe.gd`): saucers, hole skins, bite effects
  and trails are all bought with coins; the first of each is free. Journey
  rewards are gone: saves before version 9 keep the saucer in use and every
  reward already earned, and the 7-day streak pays a coin bonus. Fire and
  rainbow trails are painted on the ground behind the hole (`ground_trail.gd`,
  `shaders/ground_trail.gdshader`); `-- --capture --trail-capture` shoots each.
- **UI look**: Baloo 2 (titles/buttons) and Nunito (body), both OFL with full
  Vietnamese, in `assets/fonts`; chunky 3D buttons (`ui_button.gd`); icons baked
  from the local POLYGON Icons pack (`assets/icons/README.md`).
- Save version 9 stores progress, per-goal stars, coins, upgrades and the daily
  and endless records, the streak and reminder switch, plus the chosen language
  and seen intro cards. Version 4 star counts become their first goals. Older
  native saves keep best score and cosmetics; their stars become 25 coins each.

**Test mode** (debug builds only): tap the HOLE MUNCH title on the menu seven
times to switch it on or off (a red TEST MODE label shows). It opens all 48
cities, refills coins to 999999 after every purchase, never runs out of daily
tries, and plays on its own save
(`user://test_save.json`), so the real progress is never touched. The daily
button opens a TEST · DAILY list (`daily_picker.gd`) of every mini-game with its
goal, plus AUTO (today's); a row starts that game and PLAY AGAIN on its result
replays it. All levels can
also be opened for every build with
`application_custom/testing/unlock_all_levels=true` in `project.godot`.
`application_custom/testing/daily_type` pins the daily mini-game in debug builds
(`stampede`, `coinrain`, `goldrush`, `findcow`, `skyhop`, `slide` or `siege`; empty rotates by date). 
`testing/daily_type_android` sets `findcow` for the debug APK; release builds
ignore both.

The launcher icon is the classic app's duck: `node tools/make-godot-icons.mjs`
(from the repo root) crops `assets/hole-munch-cover.png` into `assets/app_icon`.
All 13 saucers are Meshy models (`assets/crafts`); the plainer ones are cheap and the
creature and crystal ships (donut to crystal, 3500–12000 coins) are the prizes.

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
Godot_v4.7.1-stable_win64_console.exe --path . -- --capture --album-capture --lang=en
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

## Web build (GitHub Pages)

The "Web" preset exports a single-threaded build (GitHub Pages cannot send the
COOP/COEP headers threads need) without the AdMob addon; ads and the update check
are Android-only. Install the 4.7.1 web export templates, then run
`bash godot/tools/deploy-web.sh` from the repo root (set `GODOT_BIN` if Godot is
not on PATH). It publishes to the `gh-pages` branch:
https://phucpdbk.github.io/hole-munch/ serves the Godot build, `/classic/` the
previous HTML5 game and `/privacy.html` the privacy policy. Pass `--no-push` to
build the branch locally without publishing.

## Meshy assets

`tools/meshy/meshy.mjs` turns the prompts in `tools/meshy/<kind>.json` into GLBs
(text-to-image, then image-to-3d). Review the PNGs before paying for models.
Every step is resumable through the output folder's `manifest.json`. A model
still building when a run stops is picked up again from its saved task id, so it
is never paid for twice. Keys never go
in the game or the repo: list several accounts in the git-ignored
`tools/meshy/keys.local.json` (`{"acc1": "msy_...", "acc2": "msy_..."}`, see
`keys.example.json`; put the original key first, it owns items made before
accounts were tracked), or set one in `MESHY_API_KEY`. Each run reads every
account's balance (`meshy.mjs <kind> balance`). A new item starts on the first
account with credits for its whole chain (about 42 for a landmark or saucer, 59
for a rigged guardian) and stays on it, since later steps reuse that account's
task ids; `status` shows each item's account. An account that runs out before an
item starts hands it to the next one; one that runs out mid-chain stops that
item until it is topped up or the item is redone with `--redo`. To move a stuck item to
another account without paying again: for a missing model, set its manifest entry to
`imageSource: "google"` and drop `imageTask` and `account` (the PNG on disk is
uploaded); for a missing rig, set `account` to the new one and `rigUpload: true` (the
model GLB on disk is uploaded to `/rigging`). Background removal also cuts away
pure white, so prompts give white parts an off-white colour (a `#ffffff` belly left a
hole through Tokyo Tower's guardian).

`images --google` draws the image with Google's Nano Banana Pro
(`gemini-3-pro-image`, key in the git-ignored `tools/meshy/gemini.local.json` as
`{"key": "..."}`, or `GEMINI_API_KEY`) instead of Meshy. It sends the kind's approved
images (`refs` in `KINDS`, or `--refs id,id`) as style references, which keeps new
items in the same look, then cuts the white background away. It spends no Meshy
credits; `models` uploads the PNG and picks the Meshy account at that point. Ask for
the base explicitly in landmark prompts: "on a green hill" alone grows the hill past
the frame.

```powershell
$env:MESHY_API_KEY = "msy_..."
node tools/meshy/meshy.mjs landmarks images --only namsan,watarun
node tools/meshy/meshy.mjs landmarks models --only namsan,watarun
node tools/meshy/meshy.mjs mascots images --google --only fuji  # Google image, review, then "all"
node tools/meshy/meshy.mjs mascots all --only onepillar      # images, models, rig
node tools/meshy/meshy.mjs mascots library                   # animation ids, if a clip is wrong
node tools/meshy/meshy.mjs crafts all
```

Then bake (headless Godot, `--script res://tools/<tool>.gd [-- ids]`):

| Kind | Raw GLBs (`.gdignore`d) | Bake tool | Game files | Fallback |
|---|---|---|---|---|
| Landmarks | `assets/landmarks_src/<id>.glb` | `bake_landmarks.gd` | `assets/landmarks/<id>.res` + `_albedo.res` | primitive landmark (`landmarks.gd`) |
| Guardians | `assets/mascots_src/<id>.glb` + `<id>@<clip>.glb` | `bake_mascots.gd` | `assets/mascots/<id>.scn` | primitive rig (`mascot_specs.gd`) |
| Saucers | `assets/crafts_src/<index>.glb` (0–12, `fleet.gd` NAMES) | `bake_crafts.gd` | `assets/crafts/<index>.res` + `_albedo.res` | primitive craft (`fleet.gd`) |
| Power-ups | `assets/pickups_src/<kind>.glb` (time, magnet, speed, freeze) | `bake_pickups.gd` | `assets/pickups/<kind>.res` + `_albedo.res` | the plain coloured orb (`mechanics.gd`) |
| Siege aircraft | `assets/aircraft_src/<kind>.glb` (heli, jet, flak, blimp) | `bake_aircraft.gd` | `assets/aircraft/<kind>.res` + `_albedo.res` | block models (`sky_siege.gd`) |
| Snake pets | `assets/critters_src/<kind>.glb` + `<kind>@<clip>.glb` (idle, walk, run) | `bake_critters.gd` (not headless) | `assets/critters/<kind>_<clip>_<n>.res` + `_albedo.res` | primitive animals (`critters.gd`) |

- **Facing**: models face +z (toward the camera). Fix a bad bake with that tool's
  `YAW` table; for a hand-made guardian GLB, use `CLIP_OVERRIDES` in `mascot_rig.gd`.
- **Sizes**: landmarks are normalised to a 2.6 radius on the ground, saucers to 1.6
  centred on their middle, guardians to a one-unit footprint on the ground (the game
  scales them to the guardian's swallow radius).
- **Budget**: about 8k triangles per landmark, 10k per guardian, 5k per saucer,
  textures 1024 px lossy WebP. Each rigged guardian is one skinned mesh.
- **Guardian clips**: `idle`, `walk`, `run`, `attack`, `hit`, `leap`. Meshy's
  auto-rig gives walk and run; the others come from its animation library (first
  name match, override with `--actions idle=N,attack=N`). Auto-rigging only accepts
  two-legged characters with clear limbs, which is why the mascot prompts ask for a
  standing T-pose. A model that fails rigging still works: the game bobs, leans,
  squashes and jumps the whole body.
- **Collection thumbnails**: after new saucers, render `assets/thumbs` with
  `Godot --path . --script res://tools/bake_craft_thumbs.gd` (not headless).
  After new or changed landmarks, render the album pictures
  (`assets/thumbs/landmark_<id>.png`, also used by landmark cards without
  concept art) with `Godot --path . --script res://tools/bake_landmark_thumbs.gd
  [-- id,id]`; `--campaign-smoke` fails while one is missing.
- **Check**: `-- --capture --guardian-capture` shoots every attack style with the
  baked guardians and saucer, and `-- --capture --landmark-gallery` shows every landmark.

Every landmark and every guardian of the 48 cities and 8 festivals is a Meshy bake;
the primitive landmarks (`landmarks.gd`) and toy rigs (`mascot_specs.gd`) remain as
fallbacks for a checkout without the baked files. `-- --capture --landmark-gallery`
and `-- --capture --guardian-gallery` shoot each city's landmark and guardian.

## Deferred migration

World events, onboarding goals, achievements, ads and web save migration are not
ported yet. Validate the game feel
and artwork of this slice before extending the content. Keep the web project
available if the YouTube Playables application receives a response later.
