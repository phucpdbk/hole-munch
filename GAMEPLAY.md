# Gameplay update

## Eating and combos

Objects tip, spin and shrink into the hole. Larger objects take longer to sink and
make a deeper sound. The rim pulses on a bite, with expanding rings on larger bites
and growth milestones. Score popups are batched to keep the play area readable.

Eat again within 1 second to continue a combo. At 8, 16 and 30 bites, score
multipliers become 1.5x, 2x and 3x. Completion percentage and stars still use original
object points. The result screen shows the best combo from that run. Combo banners,
countdown bars, milestone rings and combo sound changes are disabled; regular
eating feedback remains.

## Boss behaviors

- Duck: flees in 0.85-second bursts, rests for 3 seconds and drops up to 8 small
  ducklings. Movement stays within 140 world units of its starting position.
- Crab: warns for 1.1 seconds before a 0.9-second sideways sweep of small food,
  then rests for 3 seconds. It does not push the player or buildings.
- UFO: warns for 1.2 seconds, carries up to 6 small objects for 2.4 seconds, then
  releases them. Floating objects remain edible. Swallowing the UFO or ending the
  round releases its cargo immediately. No food points are removed from the map.

## Onboarding and challenges

The original level sequence remains unchanged. The first five maps have a fixed
starter snack route. Each teaches one goal: 12 objects, an 8-bite combo, double
starting size, 6 cars, and catching the boss. Level 1 waits for directional input
before starting the timer. Later levels rotate optional combo/car/object goals.
Completing a goal adds 5 seconds only in the first five teaching levels; later
goals earn challenge medals instead. Goals are not required to win.
All new text has English and Vietnamese strings, with English fallback elsewhere.

## World events

From level 3, one encounter arrives after 10–16 seconds of active play, cycling
through a candy truck, a parade of 12 cars, and a secret fruit garden. Swallowing
the garden gate opens it; it also opens after 9 seconds if ignored. The event
appears near the player, has a short HUD announcement, and pauses with the game.
Its food is part of the original map budget, so revealing it does not move the
completion target or resize the boss. Events cannot be farmed repeatedly.

## Journey and replay rewards

The world journey groups levels into chapters of nine. Each level shows its
objective, boss speed target, stars and three permanent medals. A successful
round can award a task medal, a speed medal for catching the boss within 60% of
the base timer, and a cleanup medal for reaching 90% completion. Replays merge
medals without duplicate awards. Clearing a landmark adds its stamp to a
24-destination collection, with replay buttons.

Rewards are claimed once in the journey screen, then equipped in the shop:

- 6 medals: confetti effect; 18 medals: Comet skin; 36 medals: rainbow trail.
- 6 landmarks: Explorer skin; all 24 landmarks: World Crown skin.

Save version 3 preserves coins, upgrades, cosmetics and stars from versions 1/2.
Older completed levels restore landmark stamps, but do not invent challenge
medals. Rewards grant cosmetic ownership only and do not change equipped items.

## Increased difficulty

The base timer falls from 105 seconds toward roughly 72 seconds, with small
allowances for harsh weather. Growth is slower and later bosses require a larger
share of the map's food area. Hole-size movement acceleration now has a cap,
preventing huge holes from sweeping the whole map almost instantly. Upgrade
income uses original food points, not the combo multiplier; combos still improve
leaderboard score. Existing saved currency and upgrades are preserved.

The seeded bot is a reachability and regression aid, not a claim about human
difficulty. It sees all edible objects and buys every affordable stat upgrade;
playtesting with people is still needed to tune the final difficulty curve.

## Verification

- `npm test`: gameplay, events, save migration, medal/reward persistence and
  one-time claims, followed by the content smoke test across 91 levels.
- `node tools/balance-sim.mjs 90 0.75 2`: two simulated campaigns, using earned
  coins on upgrades. This checks reachability, not human difficulty or retention.
- `node tools/render-gameplay.mjs`: phone-size images in `tools/out` for review.
- `tools/journey-preview.html`: isolated in-memory UI fixture for unlocked
  collections and rewards; does not read or write the player's save.
- `npm run package`: rebuild `dist/hole-munch.zip`, including all artwork.
