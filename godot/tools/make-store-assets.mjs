// Builds the Google Play listing graphics in builds/store/ from the launcher icon
// layers and English 1080p captures in builds/store/raw/ (see STORE-LISTING.md).
//   node godot/tools/make-store-assets.mjs
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const raw = join(root, 'builds/store/raw');
const out = join(root, 'builds/store');
// Order is the listing order: the first shots are the ones most people see.
const SCREENSHOTS = ['8-combo', '24-boss', '40-boss', 'ui-en-journey-1', '8-game', 'ui-en-wardrobe', 'ui-en-result', 'ui-en-shop'];

mkdirSync(out, { recursive: true });

const save = (canvas, name) => writeFileSync(join(out, name), canvas.toBuffer('image/png'));

// Scales to cover the frame and crops the overflow evenly.
function cover(ctx, image, width, height) {
  const scale = Math.max(width / image.width, height / image.height);
  const w = image.width * scale, h = image.height * scale;
  ctx.drawImage(image, (width - w) / 2, (height - h) / 2, w, h);
}

async function icon() {
  const canvas = createCanvas(512, 512);
  const ctx = canvas.getContext('2d');
  for (const layer of ['adaptive_background', 'adaptive_foreground']) {
    // The launcher shows the middle 288 px (2/3) of the 432 px adaptive layers; Play masks the corners itself.
    ctx.drawImage(await loadImage(join(root, `assets/app_icon/${layer}.png`)), 72, 72, 288, 288, 0, 0, 512, 512);
  }
  save(canvas, 'icon-512.png');
}

async function screenshots() {
  for (const [index, name] of SCREENSHOTS.entries()) {
    const canvas = createCanvas(1920, 1080);
    cover(canvas.getContext('2d'), await loadImage(join(raw, `${name}.png`)), 1920, 1080);
    save(canvas, `screenshot-${index + 1}.png`);
  }
}

// The logo key art from the Facebook cover, centre-cropped to Play's 1024×500.
async function featureGraphic() {
  const canvas = createCanvas(1024, 500);
  cover(canvas.getContext('2d'), await loadImage(join(root, '../assets/facebook/hole-munch-cover-v2-ufo.png')), 1024, 500);
  save(canvas, 'feature-graphic.png');
}

await icon();
await screenshots();
await featureGraphic();
console.log(`Store graphics written to ${out}`);
