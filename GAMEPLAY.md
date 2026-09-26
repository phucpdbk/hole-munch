# Gameplay update

## Eating and combos

Objects tip, spin and shrink into the hole. Larger objects take longer to sink and
make a deeper sound. The rim pulses on a bite, with expanding rings on larger bites
and growth milestones. Score popups are batched to keep the play area readable.

Eat again within 2.2 seconds to continue a combo. At 5, 10 and 20 bites, score
multipliers become 1.5x, 2x and 3x. Completion percentage and stars still use original
object points. The result screen shows the best combo from that run.

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
Completing a goal adds 5 seconds once per round; it is not required to win.
All new text has English and Vietnamese strings, with English fallback elsewhere.

## Verification

- `npm test`: state, score, reward, pause/retry, starter-route and boss-behavior
  checks, followed by the existing content smoke test across 91 levels.
- `node tools/balance-sim.mjs 90 0.75 2`: two simulated campaigns, using earned
  coins on upgrades. This checks reachability, not human difficulty or retention.
- `node tools/render-gameplay.mjs`: phone-size images in `tools/out` for review.
- `npm run package`: rebuild `dist/hole-munch.zip`, including all artwork.
