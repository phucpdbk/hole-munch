// Generates the Godot Android launcher icons (godot/assets/app_icon) from the duck
// cover art, cropped like the classic app's icons (tools/make-android-icons.mjs).
// Usage: node tools/make-godot-icons.mjs
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { writeFileSync } from 'node:fs';

const OUT = 'godot/assets/app_icon';
const BG = '#10172d';
// The duck's face, as fractions of the cover (center x, center y, side relative to width).
const FACE = { cx: 0.53, cy: 0.43, side: 0.46 };
// Adaptive icons are 108dp; launchers show roughly the central 72dp.
const SAFE_ZOOM = 72 / 108;

const cover = await loadImage('assets/hole-munch-cover.png');

function drawFace(ctx, size, zoom = 1) {
  const side = cover.width * FACE.side / zoom;
  ctx.drawImage(cover, cover.width * FACE.cx - side / 2, cover.height * FACE.cy - side / 2, side, side, 0, 0, size, size);
}

function png(path, size, draw) {
  const canvas = createCanvas(size, size);
  draw(canvas.getContext('2d'), size);
  writeFileSync(path, canvas.toBuffer('image/png'));
}

png(`${OUT}/main_192.png`, 192, (ctx, s) => {
  ctx.beginPath();
  ctx.roundRect(0, 0, s, s, s * 0.2);
  ctx.clip();
  drawFace(ctx, s);
});
png(`${OUT}/adaptive_foreground.png`, 432, (ctx, s) => drawFace(ctx, s, SAFE_ZOOM));
png(`${OUT}/adaptive_background.png`, 432, (ctx, s) => {
  ctx.fillStyle = BG;
  ctx.fillRect(0, 0, s, s);
});
console.log(`Wrote ${OUT}/main_192.png, adaptive_foreground.png and adaptive_background.png`);
