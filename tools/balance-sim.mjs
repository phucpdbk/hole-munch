// Headless balance check: a bot plays consecutive levels with the real game code,
// spending every coin on stat upgrades (the "easiest possible" progression).
// Several independent campaigns are aggregated per level:
//   APS    attempts per success (industry target: ~1.0-1.3 easy, ~1.6-1.9 spike)
//   stars  mean stars on the clearing attempt, 3*% share of clears with 3 stars
// Usage: node tools/balance-sim.mjs [levels=15] [skill=0.75] [runs=6]
globalThis.window = { addEventListener() {}, innerWidth: 1024, innerHeight: 576, devicePixelRatio: 1 };
globalThis.requestAnimationFrame = () => {};

const { Game } = await import('../src/game.js');
const { getLevel } = await import('../src/levels.js');
const { STAT_UPGRADES, upgradeCost, emptyUpgrades } = await import('../src/upgrades.js');

const LEVELS = Number(process.argv[2]) || 15;
// Fraction of full joystick deflection the bot uses; a rough stand-in for human imprecision.
const SKILL = Number(process.argv[3]) || 0.75;
const RUNS = Number(process.argv[4]) || 6;
// Reproducible maps make balancing changes comparable.
const SEED = Number(process.argv[5]) || 202609;
let rng = SEED >>> 0;
Math.random = () => { rng = (Math.imul(rng,1664525)+1013904223) >>> 0; return rng / 4294967296; };
const MAX_TRIES = 6;
const DT = 1 / 30;
const RETARGET = 0.25;

const canvas = { getContext: () => ({}), addEventListener() {} };

function playLevel(levelNum, up) {
  let result = null;
  const game = new Game(canvas, { onLevelEnd: (r) => (result = r) });
  game.start(getLevel(levelNum), up);
  game.skipIntro();
  let target = null;
  let retarget = 0;
  let elapsed = 0;
  let bossAt = null;
  while (!result && elapsed < 400) {
    retarget -= DT;
    const h = game.hole;
    if (game.state === 'playing' && (retarget <= 0 || !target || target.eaten || target.falling)) {
      retarget = RETARGET;
      let best = -1;
      target = null;
      for (const o of game.world.objects) {
        if (o.eaten || o.falling || o.hidden || o.r > h.r * 0.85) continue;
        const d = Math.hypot(o.x - h.x, o.y - h.y);
        const value = (o.r * o.r) / (d + 60);
        if (value > best) {
          best = value;
          target = o;
        }
      }
    }
    const strike = game.weather.strike;
    // Humans get a 1.4s warning ring; the bot steps out of it once it has reacted.
    if (strike && !strike.hit && strike.t > 0.5 && Math.hypot(h.x - strike.x, h.y - strike.y) < strike.r + h.r) {
      const dx = h.x - strike.x;
      const dy = h.y - strike.y;
      const l = Math.hypot(dx, dy) || 1;
      game.input.active = true;
      game.input.dx = (dx / l) * 60 * SKILL;
      game.input.dy = (dy / l) * 60 * SKILL;
    } else if (target) {
      const dx = target.x - h.x;
      const dy = target.y - h.y;
      const l = Math.hypot(dx, dy) || 1;
      game.input.active = true;
      game.input.dx = (dx / l) * 60 * SKILL;
      game.input.dy = (dy / l) * 60 * SKILL;
    }
    game.update(DT);
    elapsed += DT;
    if (bossAt === null && game.bossEaten) bossAt = elapsed;
  }
  return { ...result, bossAt, duration: getLevel(levelNum).duration + game.stats.bonusTime };
}

function buyUpgrades(save) {
  for (;;) {
    let pick = null;
    for (const u of STAT_UPGRADES) {
      const lvl = save.up[u.key];
      if (lvl >= u.max) continue;
      const cost = upgradeCost(u, lvl);
      if (cost <= save.coins && (!pick || cost < pick.cost)) pick = { u, cost };
    }
    if (!pick) return;
    save.coins -= pick.cost;
    save.up[pick.u.key]++;
  }
}

const rows = Array.from({ length: LEVELS + 1 }, () => ({ reached: 0, cleared: 0, tries: 0, stars: 0, three: 0, bossAt: 0, pct: 0 }));

for (let run = 0; run < RUNS; run++) {
  const save = { level: 1, coins: 0, up: emptyUpgrades() };
  while (save.level <= LEVELS) {
    const row = rows[save.level];
    row.reached++;
    let tries = 0;
    let r;
    do {
      tries++;
      r = playLevel(save.level, save.up);
      save.coins += r.coins;
      buyUpgrades(save);
    } while (!r.cleared && tries < MAX_TRIES);
    row.tries += tries;
    if (!r.cleared) break;
    row.cleared++;
    row.stars += r.stars;
    row.three += r.stars === 3 ? 1 : 0;
    row.bossAt += r.bossAt / r.duration;
    row.pct += r.pct;
    save.level++;
  }
}

console.log(`skill ${SKILL}, ${RUNS} campaigns, seed ${SEED}`);
console.log('lvl | diff | reach | APS  | stars | 3*%  | eaten | boss@time');
for (let n = 1; n <= LEVELS; n++) {
  const row = rows[n];
  if (!row.reached) break;
  const c = row.cleared || 1;
  const aps = row.cleared ? (row.tries / row.cleared).toFixed(2) : ' inf';
  console.log(
    [
      String(n).padStart(3),
      getLevel(n).difficulty.toFixed(2),
      `${row.cleared}/${row.reached}`.padStart(5),
      aps.padStart(4),
      (row.stars / c).toFixed(1).padStart(5),
      `${Math.round((row.three / c) * 100)}%`.padStart(4),
      `${Math.round((row.pct / c) * 100)}%`.padStart(5),
      `${Math.round((row.bossAt / c) * 100)}%`.padStart(9),
    ].join(' | ')
  );
}
