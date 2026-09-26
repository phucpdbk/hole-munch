// Windows includes bsdtar, so packaging needs no PowerShell modules or script policy changes.
import { mkdirSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
mkdirSync('dist', { recursive: true });
const result = spawnSync('tar', ['-a', '-cf', 'dist/hole-munch.zip', 'index.html', 'style.css', 'src', 'assets'], { stdio: 'inherit' });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status || 1);
if (readFileSync('dist/hole-munch.zip').subarray(0, 2).toString() !== 'PK') {
  throw new Error('Packaging requires bsdtar with ZIP support.');
}
console.log('Packaged game and artwork: dist/hole-munch.zip');
