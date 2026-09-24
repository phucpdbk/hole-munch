// Renders real game frames (intro, boss scared, boss swallowed) to PNG for review.
// Usage: node tools/render-game.mjs [level]
import { createCanvas } from '@napi-rs/canvas';
import { mkdirSync, writeFileSync } from 'node:fs';

const W = 420;
const H = 760;
globalThis.window = { devicePixelRatio: 1, innerWidth: W, innerHeight: H, addEventListener() {} };
globalThis.requestAnimationFrame = () => 0;
globalThis.document = { documentElement: {} };
globalThis.OffscreenCanvas = class {
  constructor(w, h) {
    return createCanvas(w, h);
  }
};

const { Game } = await import('../src/game.js');
const { getLevel } = await import('../src/levels.js');
const { emptyUpgrades } = await import('../src/upgrades.js');
await import('../src/i18n.js').then((m) => m.setLanguage('vi'));

const n = Number(process.argv[2]) || 3;
const canvas = createCanvas(W, H);
canvas.addEventListener = () => {};
canvas.getBoundingClientRect = () => ({ left: 0, top: 0, width: W, height: H });
const game = new Game(canvas, {});
mkdirSync('tools/out', { recursive: true });
const shot = (name) => {
  game.render();
  writeFileSync(`tools/out/game-${n}-${name}.png`, canvas.toBuffer('image/png'));
  console.log('wrote', `tools/out/game-${n}-${name}.png`);
};
const step = (sec) => {
  for (let t = 0; t < sec; t += 1 / 60) game.update(1 / 60);
};

game.start(getLevel(n), emptyUpgrades());
step(0.9);
shot('intro');

step(3);
const boss = game.world.boss;
const h = game.hole;
h.targetR = h.r = boss.r / 0.8;
h.x = boss.x + boss.r + h.r * 1.1;
h.y = boss.y + boss.r * 0.4;
step(1.2);
shot('scared');

h.x = boss.x;
h.y = boss.y;
step(0.1);
step(0.25);
shot('swallow');
step(0.6);
shot('fireworks');
