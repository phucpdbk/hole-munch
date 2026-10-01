// Turns the Meshy landmark concept images (godot/assets/landmarks_src/<id>.png,
// transparent background) into small card pictures for the Godot landmark intro:
// trimmed to the artwork, centred on a square and saved as
// godot/assets/landmark_cards/<id>.png. Usage: node tools/make-landmark-cards.mjs
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { mkdirSync, readdirSync, writeFileSync } from 'node:fs';

const SRC = 'godot/assets/landmarks_src';
const OUT = 'godot/assets/landmark_cards';
const SIZE = 320;
const PAD = 0.04;

// Bounding box of pixels that are not (nearly) transparent.
function artBounds(ctx, width, height) {
  const data = ctx.getImageData(0, 0, width, height).data;
  let minX = width, minY = height, maxX = -1, maxY = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] < 16) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return maxX < 0 ? null : { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 };
}

mkdirSync(OUT, { recursive: true });
const ids = readdirSync(SRC).filter((f) => /^[a-z]+\.png$/.test(f)).map((f) => f.slice(0, -4));
for (const id of ids) {
  const image = await loadImage(`${SRC}/${id}.png`);
  const source = createCanvas(image.width, image.height);
  const sctx = source.getContext('2d');
  sctx.drawImage(image, 0, 0);
  const box = artBounds(sctx, image.width, image.height);
  if (!box) {
    console.warn('skipped (empty):', id);
    continue;
  }
  const card = createCanvas(SIZE, SIZE);
  const ctx = card.getContext('2d');
  const scale = (SIZE * (1 - PAD * 2)) / Math.max(box.w, box.h);
  const w = box.w * scale;
  const h = box.h * scale;
  ctx.drawImage(image, box.x, box.y, box.w, box.h, (SIZE - w) / 2, (SIZE - h) / 2, w, h);
  writeFileSync(`${OUT}/${id}.png`, card.toBuffer('image/png'));
  console.log('wrote', `${OUT}/${id}.png`);
}
