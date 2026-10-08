// Serves the level catalog (test-output/catalog) on http://localhost:8766.
// Build it first: Godot --path godot -- --capture --catalog
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'test-output', 'catalog');
const PORT = Number(process.env.PORT) || 8766;
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.jpg': 'image/jpeg', '.png': 'image/png' };

http.createServer((req, res) => {
  const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname).replace(/^\/+/, '') || 'index.html';
  const file = path.resolve(ROOT, name);
  if (!file.startsWith(ROOT + path.sep)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, body) => {
    if (err) { res.writeHead(404).end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' }).end(body);
  });
}).listen(PORT, '127.0.0.1', () => console.log(`catalog: http://localhost:${PORT}/ (${ROOT})`));
