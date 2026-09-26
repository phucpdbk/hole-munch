// Preserve the generated composition; encode a compact lossless-layout web asset.
import { createCanvas, loadImage } from '@napi-rs/canvas';
import { writeFileSync } from 'node:fs';
const img = await loadImage('assets/hole-munch-cover.png');
const c = createCanvas(img.width, img.height);
c.getContext('2d').drawImage(img, 0, 0);
writeFileSync('assets/hole-munch-cover.webp', c.toBuffer('image/webp', 86));
console.log(`Cover encoded: ${img.width} x ${img.height}`);
