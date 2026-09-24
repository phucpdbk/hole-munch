// Renders boss/landmark sheets to PNG so the art can be reviewed without a browser.
// Usage: node tools/render-bosses.mjs [filter] [fear] [time]
//   filter: comma-separated boss ids (default: all), fear: 0..1, time: seconds
import { createCanvas } from '@napi-rs/canvas';
import { mkdirSync, writeFileSync } from 'node:fs';

globalThis.window = { devicePixelRatio: 1 };
globalThis.OffscreenCanvas = class {
  constructor(w, h) {
    return createCanvas(w, h);
  }
};
const { THEMES } = await import('../src/levels.js');
const { drawObject } = await import('../src/world.js');

const [filterArg, fearArg, timeArg] = process.argv.slice(2);
const filter = filterArg && filterArg !== 'all' ? new Set(filterArg.split(',')) : null;
const fear = Number(fearArg) || 0;
const time = timeArg === undefined ? 0.7 : Number(timeArg);

const seen = new Map();
for (const th of THEMES) if (!seen.has(th.boss) && (!filter || filter.has(th.boss))) seen.set(th.boss, th);
const themes = [...seen.values()];

const cell = 260;
const cols = Math.min(5, themes.length);
const rows = Math.ceil(themes.length / cols);
const canvas = createCanvas(cols * cell, rows * cell);
const ctx = canvas.getContext('2d');
themes.forEach((th, i) => {
  const x = (i % cols) * cell;
  const y = Math.floor(i / cols) * cell;
  ctx.fillStyle = th.block;
  ctx.fillRect(x, y, cell, cell);
  ctx.strokeStyle = 'rgba(0,0,0,0.3)';
  ctx.strokeRect(x + 0.5, y + 0.5, cell - 1, cell - 1);
  drawObject(ctx, { kind: 'boss', bossType: th.boss, landmark: th.landmark, r: 95, x: x + cell / 2, y: y + cell / 2 + 8, fear }, time);
  ctx.fillStyle = '#000';
  ctx.font = 'bold 16px sans-serif';
  ctx.fillText(th.boss, x + 8, y + 20);
});

mkdirSync('tools/out', { recursive: true });
const file = `tools/out/bosses${filter ? '-' + [...filter].join('_') : ''}.png`;
writeFileSync(file, canvas.toBuffer('image/png'));
console.log('wrote', file);
