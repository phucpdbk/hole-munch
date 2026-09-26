// Generates the Android launcher icons, splash images and Play Store icon from the cover art.
// Usage: node tools/make-android-icons.mjs  (run again whenever assets/hole-munch-cover.png changes)
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { mkdirSync, readdirSync, writeFileSync } from 'node:fs';

const RES = 'android/app/src/main/res';
const BG = '#10172d';
// The duck's face, as fractions of the cover (center x, center y, side relative to width).
const FACE = { cx: 0.53, cy: 0.43, side: 0.46 };
const DENSITIES = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

const cover = await loadImage('assets/hole-munch-cover.png');

function drawFace(ctx, x, y, size, zoom = 1) {
  const side = cover.width * FACE.side / zoom;
  ctx.drawImage(cover, cover.width * FACE.cx - side / 2, cover.height * FACE.cy - side / 2, side, side, x, y, size, size);
}

function png(path, w, h, draw) {
  const c = createCanvas(w, h);
  draw(c.getContext('2d'), w, h);
  writeFileSync(path, c.toBuffer('image/png'));
}

function roundedClip(ctx, size, radius) {
  ctx.beginPath();
  ctx.roundRect(0, 0, size, size, radius);
  ctx.clip();
}

for (const [density, scale] of Object.entries(DENSITIES)) {
  const dir = `${RES}/mipmap-${density}`;
  const legacy = Math.round(48 * scale);
  // Adaptive foreground is 108dp; launchers mask it down to roughly the central 72dp.
  const adaptive = Math.round(108 * scale);
  png(`${dir}/ic_launcher.png`, legacy, legacy, (ctx, s) => {
    roundedClip(ctx, s, s * 0.2);
    drawFace(ctx, 0, 0, s);
  });
  png(`${dir}/ic_launcher_round.png`, legacy, legacy, (ctx, s) => {
    ctx.beginPath();
    ctx.arc(s / 2, s / 2, s / 2, 0, Math.PI * 2);
    ctx.clip();
    drawFace(ctx, 0, 0, s);
  });
  png(`${dir}/ic_launcher_foreground.png`, adaptive, adaptive, (ctx, s) => drawFace(ctx, 0, 0, s, 72 / 108));
}

// Replace every template splash with the same size: dark backdrop and the duck in the middle.
for (const folder of readdirSync(RES).filter((f) => f.startsWith('drawable'))) {
  for (const file of readdirSync(`${RES}/${folder}`).filter((f) => f === 'splash.png')) {
    const path = `${RES}/${folder}/${file}`;
    const { width, height } = await loadImage(path);
    png(path, width, height, (ctx, w, h) => {
      ctx.fillStyle = BG;
      ctx.fillRect(0, 0, w, h);
      const s = Math.min(w, h) * 0.45;
      ctx.save();
      ctx.translate((w - s) / 2, (h - s) / 2);
      roundedClip(ctx, s, s * 0.22);
      drawFace(ctx, 0, 0, s);
      ctx.restore();
    });
  }
}

mkdirSync('dist/store', { recursive: true });
png('dist/store/icon-512.png', 512, 512, (ctx, s) => drawFace(ctx, 0, 0, s));
console.log('Wrote launcher icons, splash images and dist/store/icon-512.png');
