// Local static server that mimics the Content-Security-Policy YouTube applies to Playables.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';

const ROOT = resolve(process.cwd());
const PORT = Number(process.env.PORT) || 5173;

const CSP =
  "default-src 'none'; script-src 'report-sample' 'self' 'unsafe-eval' 'unsafe-inline' blob: " +
  'https://www.youtube.com/game_api/v0 https://www.youtube.com/game_api/v0/ ' +
  'https://www.youtube.com/game_api/v1 https://www.youtube.com/game_api/v1/; ' +
  "object-src 'none'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
  "img-src 'self' blob: data:; media-src 'self' blob:; font-src 'self' data: https://fonts.googleapis.com https://fonts.gstatic.com; " +
  "connect-src 'self' blob: data:; base-uri 'self'; manifest-src 'self'; worker-src 'self' blob:";

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
};

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    let path = normalize(join(ROOT, decodeURIComponent(url.pathname)));
    if (!path.startsWith(ROOT)) {
      res.writeHead(403).end();
      return;
    }
    if ((await stat(path)).isDirectory()) path = join(path, 'index.html');
    const body = await readFile(path);
    const headers = { 'Content-Type': TYPES[extname(path)] || 'application/octet-stream', 'Cache-Control': 'no-store' };
    if (extname(path) === '.html') headers['Content-Security-Policy'] = CSP;
    res.writeHead(200, headers).end(body);
  } catch {
    res.writeHead(404).end('Not found');
  }
}).listen(PORT, () => console.log(`Hole Munch running at http://localhost:${PORT}`));
