// Builds www/ for the Capacitor Android app: the same game as the web build, minus the YouTube
// SDK (the app must run offline), plus the Capacitor plugin scripts that src/native.js reads.
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';

const OUT = 'www';
const VENDOR = {
  'capacitor.js': { from: 'node_modules/@capacitor/core/dist/capacitor.js' },
  'capacitor-app.js': { from: 'node_modules/@capacitor/app/dist/plugin.js', global: 'capacitorApp' },
  // The AdMob bundle declares itself as `capacitorStripe`, so every plugin global is renamed explicitly.
  'capacitor-admob.js': { from: 'node_modules/@capacitor-community/admob/dist/plugin.js', global: 'capacitorAdMob' },
};

rmSync(OUT, { recursive: true, force: true });
mkdirSync(`${OUT}/vendor`, { recursive: true });
mkdirSync(`${OUT}/assets`, { recursive: true });

cpSync('src', `${OUT}/src`, { recursive: true });
cpSync('style.css', `${OUT}/style.css`);
cpSync('assets/hole-munch-cover.webp', `${OUT}/assets/hole-munch-cover.webp`);
for (const [name, { from, global }] of Object.entries(VENDOR)) {
  let js = readFileSync(from, 'utf8');
  if (global) {
    const declaration = /^var \w+ = \(function/m;
    if (!declaration.test(js)) throw new Error(`${from}: unexpected bundle format, cannot expose ${global}`);
    js = js.replace(declaration, `var ${global} = (function`);
  }
  writeFileSync(`${OUT}/vendor/${name}`, js);
}

const html = readFileSync('index.html', 'utf8');
const sdkTag = '<script src="https://www.youtube.com/game_api/v1"></script>';
const moduleTag = '<script type="module" src="src/main.js"></script>';
if (!html.includes(sdkTag) || !html.includes(moduleTag)) {
  throw new Error('index.html changed: update the tags that tools/build-app.mjs rewrites.');
}
const vendorTags = Object.keys(VENDOR).map((name) => `<script src="vendor/${name}"></script>`).join('\n  ');
const appHtml = html
  .replace(sdkTag, '')
  .replace(/^[ \t]*<meta property="og:.*\r?\n/gm, '')
  .replace(moduleTag, `${vendorTags}\n  ${moduleTag}`);
writeFileSync(`${OUT}/index.html`, appHtml);

console.log(`Built ${OUT}/ for the Android app`);
