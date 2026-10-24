// Builds the Google Play listing graphics in builds/store/ from the launcher icon
// layers and English 1080p captures in builds/store/raw/ (see STORE-LISTING.md),
// plus the App Store icon and iPhone 6.9" shots in builds/store/ios/ from
// 2868×1320 captures in builds/store/raw-ios/ when present (see APP-STORE.md).
//   node godot/tools/make-store-assets.mjs
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const raw = join(root, 'builds/store/raw');
const out = join(root, 'builds/store');
const rawIos = join(root, 'builds/store/raw-ios');
const outIos = join(out, 'ios');
// Order is the listing order: the first shots are the ones most people see.
const SCREENSHOTS = ['8-combo', '24-boss', '40-boss', 'ui-en-journey-1', '8-game', 'ui-en-wardrobe', 'ui-en-result', 'ui-en-shop'];
// iOS ships without ads, so skip shots that show an ad offer (App Review 2.3.3).
const IOS_SCREENSHOTS = SCREENSHOTS.filter((name) => name !== 'ui-en-result');

mkdirSync(out, { recursive: true });

const save = (canvas, name) => writeFileSync(join(out, name), canvas.toBuffer('image/png'));

// Scales to cover the frame and crops the overflow evenly.
function cover(ctx, image, width, height) {
  const scale = Math.max(width / image.width, height / image.height);
  const w = image.width * scale, h = image.height * scale;
  ctx.drawImage(image, (width - w) / 2, (height - h) / 2, w, h);
}

// Both stores reject screenshots, feature graphics and the App Store icon if the
// PNG has an alpha channel, even a fully opaque one, so these are written as
// 24-bit RGB. The canvas encoder always emits RGBA, hence this small encoder.
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(bytes) {
  let c = 0xffffffff;
  for (const b of bytes) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const length = Buffer.alloc(4), crc = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([length, body, crc]);
}
function saveOpaque(canvas, path) {
  const { width, height } = canvas;
  const rgba = canvas.getContext('2d').getImageData(0, 0, width, height).data;
  const rows = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) {
    const row = y * (width * 3 + 1);
    for (let x = 0; x < width; x++) {
      const src = (y * width + x) * 4, dst = row + 1 + x * 3;
      rows[dst] = rgba[src]; rows[dst + 1] = rgba[src + 1]; rows[dst + 2] = rgba[src + 2];
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header.set([8, 2, 0, 0, 0], 8);  // 8-bit RGB, no interlace
  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  writeFileSync(path, Buffer.concat([signature, chunk('IHDR', header), chunk('IDAT', deflateSync(rows, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}

async function iconCanvas(size) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');
  for (const layer of ['adaptive_background', 'adaptive_foreground']) {
    // The launcher shows the middle 288 px (2/3) of the 432 px adaptive layers; the stores mask the corners themselves.
    ctx.drawImage(await loadImage(join(root, `assets/app_icon/${layer}.png`)), 72, 72, 288, 288, 0, 0, size, size);
  }
  return canvas;
}

async function icon() {
  save(await iconCanvas(512), 'icon-512.png');
  // The iOS preset points at this checked-in copy (icons/icon_1024x1024).
  saveOpaque(await iconCanvas(1024), join(root, 'assets/app_icon/ios_1024.png'));
}

async function screenshots(from, to, names, width, height) {
  for (const [index, name] of names.entries()) {
    const canvas = createCanvas(width, height);
    cover(canvas.getContext('2d'), await loadImage(join(from, `${name}.png`)), width, height);
    saveOpaque(canvas, join(to, `screenshot-${index + 1}.png`));
  }
}

// The logo key art from the Facebook cover, centre-cropped to Play's 1024×500.
async function featureGraphic() {
  const canvas = createCanvas(1024, 500);
  cover(canvas.getContext('2d'), await loadImage(join(root, '../assets/facebook/hole-munch-cover-v2-ufo.png')), 1024, 500);
  saveOpaque(canvas, join(out, 'feature-graphic.png'));
}

await icon();
if (existsSync(raw)) await screenshots(raw, out, SCREENSHOTS, 1920, 1080);
await featureGraphic();
// iPhone 6.9" landscape; App Store Connect scales these down for smaller iPhones.
if (existsSync(rawIos)) {
  mkdirSync(outIos, { recursive: true });
  await screenshots(rawIos, outIos, IOS_SCREENSHOTS, 2868, 1320);
}
console.log(`Store graphics written to ${out}`);
