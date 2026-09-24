// Headless content check: strings for every theme, every landmark/prop draws, every level runs.
// Usage: node tools/check-content.mjs
const noop = () => {};
let calls = 0;
const ctx = new Proxy({}, {
  get: (t, k) => (k in t ? t[k] : /Gradient/.test(k) ? () => ({ addColorStop: noop }) : k === 'measureText' ? () => ({ width: 1 }) : () => { calls++; }),
  set: (t, k, v) => ((t[k] = v), true),
});
globalThis.window = { devicePixelRatio: 1, innerWidth: 400, innerHeight: 700, addEventListener: noop };
globalThis.document = { documentElement: {} };
let queue = [];
globalThis.requestAnimationFrame = (f) => queue.push(f);

const { STRINGS } = await import('../src/locales.js');
await import('../src/i18n.js');
const { Game } = await import('../src/game.js');
const { getLevel, THEMES } = await import('../src/levels.js');
const { generateWorld, drawObject } = await import('../src/world.js');
const { PROP_KINDS } = await import('../src/props.js');
const { emptyUpgrades } = await import('../src/upgrades.js');

let failed = false;
const need = new Set(THEMES.flatMap((th) => [`${th.boss}Name`, `${th.boss}Boss`, `${th.boss}Twist`]));
const missing = [];
for (const [lang, s] of Object.entries(STRINGS)) for (const k of need) if (!s[k]) missing.push(`${lang}:${k}`);
console.log(`themes ${THEMES.length}, unique ${new Set(THEMES.map((t) => t.boss)).size}, landmarks ${THEMES.filter((t) => t.landmark).length}`);
console.log('missing strings:', missing.length ? missing.slice(0, 20) : 'none');
failed ||= missing.length > 0;

const weak = [];
for (const th of THEMES.filter((t) => t.landmark)) {
  calls = 0;
  drawObject(ctx, { kind: 'boss', bossType: th.boss, landmark: true, r: 60, x: 0, y: 0 }, 1.7);
  if (calls < 15) weak.push(`${th.boss}:${calls}`);
}
for (const k of PROP_KINDS) {
  calls = 0;
  drawObject(ctx, { kind: k, r: 10, w: 20, h: 12, x: 0, y: 0, angle: 0.3 }, 1.2);
  if (calls < 2) weak.push(`${k}:${calls}`);
}
console.log('empty drawings:', weak.length ? weak : 'none');
failed ||= weak.length > 0;

const kinds = {};
for (let n = 1; n <= THEMES.length; n++) {
  for (const o of generateWorld(getLevel(n)).objects) kinds[o.kind] = (kinds[o.kind] || 0) + 1;
}
console.log(`objects over ${THEMES.length} maps:`, JSON.stringify(kinds));

const game = new Game(
  { width: 400, height: 700, getContext: () => ctx, addEventListener: noop, getBoundingClientRect: () => ({ left: 0, top: 0, width: 400, height: 700 }), style: {} },
  {}
);
for (let n = 1; n <= THEMES.length + 1; n++) {
  game.start(getLevel(n), emptyUpgrades());
  for (let i = 1; i <= 60; i++) {
    const q = queue;
    queue = [];
    q.forEach((f) => f(n * 10000 + i * 16));
  }
}
console.log(`played levels 1-${THEMES.length + 1} without errors`);
console.log(THEMES.map((t, i) => `${i + 1}:${t.boss}${t.landmark ? '*' : ''}/${t.weather}`).join(' '));
process.exit(failed ? 1 : 0);
