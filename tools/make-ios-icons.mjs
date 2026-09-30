// Uses the same cover-art crop as make-android-icons.mjs.
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { writeFileSync } from 'node:fs';

const cover = await loadImage('assets/hole-munch-cover.png');
const canvas = createCanvas(1024, 1024);
const ctx = canvas.getContext('2d');
ctx.fillStyle = '#10172d';
ctx.fillRect(0, 0, 1024, 1024);
const side = cover.width * 0.46;
ctx.drawImage(cover, cover.width * 0.53 - side / 2,
  cover.height * 0.43 - side / 2, side, side, 0, 0, 1024, 1024);
writeFileSync('ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png', canvas.toBuffer('image/png'));
console.log('Wrote iOS app icon (1024 × 1024).');

// Keep the logo inside the central area when the square splash is cropped on phones.
const splash = createCanvas(2732, 2732);
const splashCtx = splash.getContext('2d');
splashCtx.fillStyle = '#10172d';
splashCtx.fillRect(0, 0, 2732, 2732);
splashCtx.drawImage(canvas, 1066, 1066, 600, 600);
const splashPng = splash.toBuffer('image/png');
for (const suffix of ['', '-1', '-2']) {
  writeFileSync(`ios/App/App/Assets.xcassets/Splash.imageset/splash-2732x2732${suffix}.png`, splashPng);
}
console.log('Wrote iOS launch images.');
