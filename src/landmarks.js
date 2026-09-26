// Stylised front-view landmarks drawn in the boss slot. Coordinates are in units of the
// boss radius r, centred on the boss; everything fits roughly inside [-r, r].
import { drawNewLandmark } from './landmarks-expansion.js';

function poly(ctx, r, pts) {
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i ? ctx.lineTo(x * r, y * r) : ctx.moveTo(x * r, y * r)));
  ctx.closePath();
}

function rect(ctx, r, x, y, w, h) {
  ctx.fillRect(x * r, y * r, w * r, h * r);
}

function archWindow(ctx, r, cx, top, w, h) {
  ctx.beginPath();
  ctx.moveTo((cx - w / 2) * r, (top + h) * r);
  ctx.lineTo((cx - w / 2) * r, (top + w / 2) * r);
  ctx.arc(cx * r, (top + w / 2) * r, (w / 2) * r, Math.PI, 0);
  ctx.lineTo((cx + w / 2) * r, (top + h) * r);
  ctx.closePath();
  ctx.fill();
}

function eiffel(ctx, r) {
  ctx.fillStyle = '#8a5a3b';
  ctx.beginPath();
  ctx.moveTo(-0.78 * r, 0.92 * r);
  ctx.lineTo(-0.52 * r, 0.92 * r);
  ctx.quadraticCurveTo(0, 0.2 * r, 0.52 * r, 0.92 * r);
  ctx.lineTo(0.78 * r, 0.92 * r);
  ctx.lineTo(0.36 * r, 0.2 * r);
  ctx.lineTo(0.14 * r, -0.45 * r);
  ctx.lineTo(0.05 * r, -0.9 * r);
  ctx.lineTo(-0.05 * r, -0.9 * r);
  ctx.lineTo(-0.14 * r, -0.45 * r);
  ctx.lineTo(-0.36 * r, 0.2 * r);
  ctx.closePath();
  ctx.fill();

  // Lattice zigzag up the upper section.
  ctx.strokeStyle = '#c08a5c';
  ctx.lineWidth = Math.max(1, r * 0.022);
  ctx.beginPath();
  let side = -1;
  for (let y = 0.16; y > -0.86; y -= 0.1) {
    const half = 0.05 + ((y + 0.9) / 1.1) * 0.28;
    const x = side * half * r;
    if (y === 0.16) ctx.moveTo(x, y * r);
    else ctx.lineTo(x, y * r);
    side = -side;
  }
  ctx.stroke();
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(s * 0.66 * r, 0.9 * r);
    ctx.lineTo(s * 0.34 * r, 0.3 * r);
    ctx.moveTo(s * 0.44 * r, 0.9 * r);
    ctx.lineTo(s * 0.56 * r, 0.55 * r);
    ctx.stroke();
  }

  ctx.fillStyle = '#5e3b25';
  rect(ctx, r, -0.44, 0.16, 0.88, 0.09);
  rect(ctx, r, -0.2, -0.44, 0.4, 0.06);
  rect(ctx, r, -0.08, -0.94, 0.16, 0.06);
  ctx.fillRect(-r * 0.012, -1.06 * r, r * 0.024, 0.14 * r);
}

function liberty(ctx, r, time) {
  ctx.fillStyle = '#b5a58a';
  poly(ctx, r, [[-0.45, 0.95], [0.45, 0.95], [0.34, 0.45], [-0.34, 0.45]]);
  ctx.fill();
  ctx.fillStyle = '#9c8c70';
  rect(ctx, r, -0.4, 0.38, 0.8, 0.09);
  rect(ctx, r, -0.16, 0.58, 0.32, 0.22);

  const green = '#5fa38b';
  const dark = '#3f7f6a';
  ctx.fillStyle = green;
  poly(ctx, r, [[-0.3, 0.4], [0.3, 0.4], [0.18, -0.3], [-0.18, -0.3]]);
  ctx.fill();
  ctx.strokeStyle = dark;
  ctx.lineWidth = Math.max(1, r * 0.025);
  for (const x of [-0.12, 0, 0.12]) {
    ctx.beginPath();
    ctx.moveTo(x * r, -0.2 * r);
    ctx.lineTo(x * 1.4 * r, 0.38 * r);
    ctx.stroke();
  }

  ctx.fillStyle = dark;
  ctx.save();
  ctx.translate(-0.2 * r, -0.02 * r);
  ctx.rotate(-0.25);
  rect(ctx, r, -0.08, -0.12, 0.16, 0.24);
  ctx.restore();

  ctx.strokeStyle = green;
  ctx.lineCap = 'round';
  ctx.lineWidth = r * 0.11;
  ctx.beginPath();
  ctx.moveTo(0.14 * r, -0.22 * r);
  ctx.lineTo(0.3 * r, -0.72 * r);
  ctx.stroke();
  ctx.lineCap = 'butt';

  ctx.fillStyle = green;
  ctx.beginPath();
  ctx.arc(0, -0.42 * r, 0.13 * r, 0, Math.PI * 2);
  ctx.fill();
  for (let i = -3; i <= 3; i++) {
    const a = -Math.PI / 2 + i * 0.36;
    ctx.beginPath();
    ctx.moveTo(Math.cos(a - 0.12) * 0.11 * r, -0.44 * r + Math.sin(a - 0.12) * 0.11 * r);
    ctx.lineTo(Math.cos(a) * 0.27 * r, -0.44 * r + Math.sin(a) * 0.27 * r);
    ctx.lineTo(Math.cos(a + 0.12) * 0.11 * r, -0.44 * r + Math.sin(a + 0.12) * 0.11 * r);
    ctx.fill();
  }

  ctx.fillStyle = '#c9a227';
  poly(ctx, r, [[0.24, -0.8], [0.36, -0.8], [0.33, -0.72], [0.27, -0.72]]);
  ctx.fill();
  const flicker = 1 + Math.sin(time * 12) * 0.12;
  ctx.fillStyle = '#ff9f1c';
  ctx.beginPath();
  ctx.ellipse(0.3 * r, -0.9 * r, 0.07 * r * flicker, 0.11 * r * flicker, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ffe066';
  ctx.beginPath();
  ctx.ellipse(0.3 * r, -0.88 * r, 0.035 * r, 0.06 * r * flicker, 0, 0, Math.PI * 2);
  ctx.fill();
}

function pyramid(ctx, r) {
  ctx.fillStyle = '#d9a441';
  poly(ctx, r, [[0.15, 0.85], [0.98, 0.85], [0.58, 0.2]]);
  ctx.fill();
  ctx.fillStyle = '#b98532';
  poly(ctx, r, [[0.58, 0.2], [0.98, 0.85], [0.62, 0.85]]);
  ctx.fill();

  ctx.fillStyle = '#f0c05a';
  poly(ctx, r, [[-0.9, 0.92], [0.7, 0.92], [-0.1, -0.78]]);
  ctx.fill();
  ctx.fillStyle = '#c8903a';
  poly(ctx, r, [[-0.1, -0.78], [0.7, 0.92], [0.02, 0.92]]);
  ctx.fill();
  ctx.strokeStyle = 'rgba(90,55,20,0.22)';
  ctx.lineWidth = Math.max(1, r * 0.018);
  for (let y = -0.5; y < 0.9; y += 0.17) {
    const k = (y + 0.78) / 1.7;
    ctx.beginPath();
    ctx.moveTo((-0.1 - 0.8 * k) * r, y * r);
    ctx.lineTo((-0.1 + 0.8 * k) * r, y * r);
    ctx.stroke();
  }

  // A small sphinx guarding the front.
  ctx.fillStyle = '#d6a75c';
  rect(ctx, r, -0.98, 0.72, 0.36, 0.2);
  rect(ctx, r, -0.72, 0.56, 0.13, 0.2);
  ctx.fillStyle = '#3d6fb6';
  rect(ctx, r, -0.74, 0.54, 0.17, 0.07);
}

function bigben(ctx, r, time) {
  const stone = '#d4b483';
  ctx.fillStyle = '#c4a26f';
  rect(ctx, r, -0.27, 0.72, 0.54, 0.24);
  ctx.fillStyle = stone;
  rect(ctx, r, -0.2, -0.36, 0.4, 1.1);
  ctx.fillStyle = '#9c7b4f';
  for (const x of [-0.12, 0, 0.12]) rect(ctx, r, x - 0.018, -0.25, 0.036, 0.9);

  ctx.fillStyle = '#e0c38f';
  rect(ctx, r, -0.26, -0.64, 0.52, 0.3);
  ctx.fillStyle = '#fffdf5';
  ctx.beginPath();
  ctx.arc(0, -0.49 * r, 0.17 * r, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#c9a227';
  ctx.lineWidth = Math.max(1, r * 0.035);
  ctx.stroke();
  ctx.strokeStyle = '#1b1b1b';
  ctx.lineCap = 'round';
  const minute = time * 0.8;
  const hour = time * 0.07;
  ctx.lineWidth = Math.max(1, r * 0.03);
  ctx.beginPath();
  ctx.moveTo(0, -0.49 * r);
  ctx.lineTo(Math.sin(minute) * 0.13 * r, -0.49 * r - Math.cos(minute) * 0.13 * r);
  ctx.moveTo(0, -0.49 * r);
  ctx.lineTo(Math.sin(hour) * 0.08 * r, -0.49 * r - Math.cos(hour) * 0.08 * r);
  ctx.stroke();
  ctx.lineCap = 'butt';

  ctx.fillStyle = stone;
  rect(ctx, r, -0.2, -0.8, 0.4, 0.17);
  ctx.fillStyle = '#5c4630';
  for (const x of [-0.1, 0, 0.1]) archWindow(ctx, r, x, -0.77, 0.06, 0.12);
  ctx.fillStyle = '#2f3e46';
  poly(ctx, r, [[-0.23, -0.8], [0.23, -0.8], [0, -1.04]]);
  ctx.fill();
  ctx.fillStyle = '#c9a227';
  rect(ctx, r, -0.012, -1.1, 0.024, 0.08);
}

function colosseum(ctx, r) {
  const wall = [
    [-0.95, 0.88], [-0.95, -0.4], [-0.5, -0.52], [0.2, -0.52], [0.3, -0.3], [0.5, -0.36],
    [0.6, -0.12], [0.8, -0.16], [0.95, 0.1], [0.95, 0.88],
  ];
  ctx.fillStyle = '#d9b77e';
  poly(ctx, r, wall);
  ctx.fill();
  ctx.save();
  poly(ctx, r, wall);
  ctx.clip();
  ctx.fillStyle = '#e8cc98';
  for (const y of [0.42, 0.06, -0.3]) rect(ctx, r, -1, y, 2, 0.05);
  ctx.fillStyle = '#7a5230';
  for (const top of [0.5, 0.14, -0.22]) {
    for (let x = -0.84; x <= 0.86; x += 0.19) archWindow(ctx, r, x, top, 0.11, 0.26);
  }
  ctx.restore();
  ctx.fillStyle = '#c29a5f';
  rect(ctx, r, -0.95, 0.82, 1.9, 0.08);
}

function pisa(ctx, r) {
  ctx.save();
  ctx.translate(0, 0.95 * r);
  ctx.rotate(0.13);
  const tiers = [[0.38, 0.26], [0.36, 0.2], [0.36, 0.2], [0.36, 0.2], [0.36, 0.2], [0.36, 0.2], [0.36, 0.2], [0.28, 0.2]];
  let y = 0;
  for (const [w, h] of tiers) {
    ctx.fillStyle = '#f1ece2';
    rect(ctx, r, -w, y - h, w * 2, h);
    ctx.fillStyle = '#d8d0c0';
    rect(ctx, r, w * 0.35, y - h, w * 0.65, h);
    ctx.fillStyle = '#b9ae98';
    const n = w > 0.3 ? 5 : 4;
    for (let i = 0; i < n; i++) {
      const cx = -w + ((i + 0.5) * (w * 2)) / n;
      archWindow(ctx, r, cx, y - h + 0.04, 0.07, h - 0.07);
    }
    ctx.fillStyle = '#cfc6b3';
    rect(ctx, r, -w - 0.03, y - h - 0.02, w * 2 + 0.06, 0.035);
    y -= h;
  }
  ctx.fillStyle = '#b9ae98';
  ctx.beginPath();
  ctx.ellipse(0, y * r, 0.26 * r, 0.06 * r, 0, Math.PI, 0);
  ctx.fill();
  ctx.restore();
}

function fuji(ctx, r) {
  ctx.fillStyle = '#e63946';
  ctx.beginPath();
  ctx.arc(0.56 * r, -0.62 * r, 0.2 * r, 0, Math.PI * 2);
  ctx.fill();

  const slope = () => {
    ctx.beginPath();
    ctx.moveTo(-r, 0.9 * r);
    ctx.quadraticCurveTo(-0.45 * r, 0.1 * r, -0.16 * r, -0.62 * r);
    ctx.lineTo(0.16 * r, -0.62 * r);
    ctx.quadraticCurveTo(0.45 * r, 0.1 * r, r, 0.9 * r);
    ctx.closePath();
  };
  ctx.fillStyle = '#4f5d95';
  slope();
  ctx.fill();
  ctx.save();
  slope();
  ctx.clip();
  ctx.fillStyle = 'rgba(20,25,60,0.25)';
  rect(ctx, r, 0.05, -1, 1, 2);
  ctx.fillStyle = '#ffffff';
  poly(ctx, r, [
    [-0.5, -0.62], [0.5, -0.62], [0.5, -0.24], [0.38, -0.24], [0.26, -0.12], [0.16, -0.24], [0.04, -0.08],
    [-0.08, -0.22], [-0.2, -0.1], [-0.3, -0.2], [-0.5, -0.24],
  ]);
  ctx.fill();
  ctx.restore();
}

function turtle(ctx, r, time) {
  ctx.fillStyle = '#4d908e';
  ctx.beginPath();
  ctx.ellipse(0, 0.72 * r, 0.98 * r, 0.26 * r, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.lineWidth = Math.max(1, r * 0.02);
  const ripple = (time * 0.4) % 1;
  ctx.beginPath();
  ctx.ellipse(0, 0.66 * r, (0.5 + ripple * 0.4) * r, (0.12 + ripple * 0.08) * r, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = '#6a994e';
  ctx.beginPath();
  ctx.ellipse(0, 0.62 * r, 0.42 * r, 0.12 * r, 0, 0, Math.PI * 2);
  ctx.fill();

  const wall = '#e9dcc0';
  const shade = '#d4c3a0';
  const win = '#6b5b45';
  const tiers = [[0.32, 0.58, 0.55, 3], [0.24, 0.03, 0.38, 2], [0.16, -0.35, 0.27, 1]];
  for (const [w, bottom, h, windows] of tiers) {
    ctx.fillStyle = wall;
    rect(ctx, r, -w, bottom - h, w * 2, h);
    ctx.fillStyle = shade;
    rect(ctx, r, w * 0.4, bottom - h, w * 0.6, h);
    ctx.fillStyle = win;
    for (let i = 0; i < windows; i++) {
      const cx = -w + ((i + 0.5) * w * 2) / windows;
      archWindow(ctx, r, cx, bottom - h + 0.08, 0.09, h - 0.16);
    }
    ctx.fillStyle = '#b08968';
    rect(ctx, r, -w - 0.04, bottom - h - 0.03, w * 2 + 0.08, 0.04);
  }
  ctx.fillStyle = '#8d5b4c';
  ctx.beginPath();
  ctx.moveTo(-0.24 * r, -0.6 * r);
  ctx.quadraticCurveTo(-0.08 * r, -0.66 * r, 0, -0.86 * r);
  ctx.quadraticCurveTo(0.08 * r, -0.66 * r, 0.24 * r, -0.6 * r);
  ctx.quadraticCurveTo(0, -0.64 * r, -0.24 * r, -0.6 * r);
  ctx.fill();
  rect(ctx, r, -0.012, -0.96, 0.024, 0.12);

  // The legendary turtle paddling by.
  const tx = (0.62 + Math.sin(time * 0.8) * 0.06) * r;
  ctx.fillStyle = '#3a5a40';
  ctx.beginPath();
  ctx.arc(tx + 0.12 * r, 0.76 * r, 0.05 * r, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#588157';
  ctx.beginPath();
  ctx.ellipse(tx, 0.78 * r, 0.12 * r, 0.07 * r, 0, 0, Math.PI * 2);
  ctx.fill();
}

function arc(ctx, r, time) {
  ctx.fillStyle = '#eadcb8';
  rect(ctx, r, -0.8, -0.55, 1.6, 1.47);
  ctx.fillStyle = '#dccba0';
  rect(ctx, r, -0.86, -0.78, 1.72, 0.25);
  ctx.fillStyle = '#c9b68a';
  rect(ctx, r, -0.9, -0.56, 1.8, 0.05);
  rect(ctx, r, -0.9, -0.8, 1.8, 0.04);
  ctx.fillStyle = '#d8c69c';
  for (const x of [-0.7, 0.4]) rect(ctx, r, x, -0.4, 0.3, 0.34);
  ctx.fillStyle = '#c9b68a';
  for (const x of [-0.62, -0.38, 0.38, 0.62]) rect(ctx, r, x - 0.02, 0.05, 0.04, 0.85);
  ctx.fillStyle = '#4a3f35';
  archWindow(ctx, r, 0, -0.18, 0.56, 1.1);

  // Tricolour hanging in the arch, waving.
  const colors = ['#1f4fa8', '#ffffff', '#e0323c'];
  const w = 0.12;
  for (let i = 0; i < 3; i++) {
    const x0 = (-0.18 + i * w) * r;
    const sway = Math.sin(time * 3 + i * 0.9) * 0.03 * r;
    ctx.fillStyle = colors[i];
    ctx.beginPath();
    ctx.moveTo(x0, 0.08 * r);
    ctx.lineTo(x0 + w * r, 0.08 * r);
    ctx.lineTo(x0 + w * r + sway, 0.5 * r);
    ctx.lineTo(x0 + sway, 0.5 * r);
    ctx.closePath();
    ctx.fill();
  }
}

function stonehenge(ctx, r) {
  ctx.fillStyle = '#6b9b5e';
  ctx.beginPath();
  ctx.ellipse(0, 0.78 * r, 0.98 * r, 0.2 * r, 0, 0, Math.PI * 2);
  ctx.fill();

  const stone = '#8d8f87';
  const dark = '#6b6d66';
  const light = '#a9aba2';
  ctx.fillStyle = dark;
  for (const x of [-0.78, -0.44, -0.08, 0.3, 0.66]) rect(ctx, r, x, 0.02, 0.14, 0.6);
  rect(ctx, r, -0.82, -0.04, 0.5, 0.09);
  rect(ctx, r, 0.26, -0.04, 0.56, 0.09);

  const trilithon = (x0, x1, top) => {
    ctx.fillStyle = stone;
    rect(ctx, r, x0, top, 0.2, 0.95 - top);
    rect(ctx, r, x1, top, 0.2, 0.95 - top);
    ctx.fillStyle = light;
    rect(ctx, r, x0, top, 0.06, 0.95 - top);
    rect(ctx, r, x1, top, 0.06, 0.95 - top);
    ctx.fillStyle = stone;
    rect(ctx, r, x0 - 0.05, top - 0.13, x1 - x0 + 0.3, 0.15);
    ctx.fillStyle = light;
    rect(ctx, r, x0 - 0.05, top - 0.13, x1 - x0 + 0.3, 0.04);
  };
  trilithon(-0.68, -0.3, -0.35);
  trilithon(0.12, 0.5, -0.45);

  ctx.save();
  ctx.translate(-0.05 * r, 0.8 * r);
  ctx.rotate(-0.35);
  ctx.fillStyle = dark;
  rect(ctx, r, -0.3, -0.07, 0.6, 0.14);
  ctx.restore();
}

function parthenon(ctx, r) {
  ctx.fillStyle = '#cfc4a8';
  rect(ctx, r, -0.98, 0.78, 1.96, 0.16);
  ctx.fillStyle = '#ddd3b8';
  rect(ctx, r, -0.9, 0.66, 1.8, 0.13);
  rect(ctx, r, -0.84, 0.56, 1.68, 0.11);
  ctx.fillStyle = '#efe7d2';
  for (let i = 0; i < 8; i++) {
    const x = -0.78 + i * 0.215;
    rect(ctx, r, x, -0.2, 0.13, 0.77);
  }
  ctx.fillStyle = '#d8ceb3';
  for (let i = 0; i < 8; i++) rect(ctx, r, -0.78 + i * 0.215 + 0.09, -0.2, 0.04, 0.77);
  ctx.fillStyle = '#e6dcc3';
  rect(ctx, r, -0.86, -0.34, 1.72, 0.15);
  ctx.fillStyle = '#d2c7aa';
  rect(ctx, r, -0.86, -0.24, 1.72, 0.05);
  ctx.fillStyle = '#efe7d2';
  poly(ctx, r, [[-0.9, -0.34], [0.9, -0.34], [0, -0.7]]);
  ctx.fill();
  ctx.fillStyle = '#d8ceb3';
  poly(ctx, r, [[-0.66, -0.38], [0.66, -0.38], [0, -0.62]]);
  ctx.fill();
}

function greatwall(ctx, r, time) {
  ctx.fillStyle = '#6a994e';
  poly(ctx, r, [[-1, 0.95], [-1, 0.2], [-0.55, -0.1], [-0.1, 0.25], [0.35, -0.35], [1, 0.05], [1, 0.95]]);
  ctx.fill();
  ctx.fillStyle = '#577f40';
  poly(ctx, r, [[-1, 0.95], [-1, 0.55], [-0.3, 0.4], [0.4, 0.62], [1, 0.45], [1, 0.95]]);
  ctx.fill();

  const path = [[-1, 0.62], [-0.55, 0.12], [-0.1, 0.42], [0.35, -0.16], [1, 0.22]];
  ctx.strokeStyle = '#a68a64';
  ctx.lineJoin = 'round';
  ctx.lineWidth = 0.14 * r;
  ctx.beginPath();
  path.forEach(([x, y], i) => (i ? ctx.lineTo(x * r, y * r) : ctx.moveTo(x * r, y * r)));
  ctx.stroke();
  ctx.strokeStyle = '#c2a878';
  ctx.lineWidth = 0.05 * r;
  ctx.setLineDash([0.05 * r, 0.04 * r]);
  ctx.beginPath();
  path.forEach(([x, y], i) => (i ? ctx.lineTo(x * r, (y - 0.08) * r) : ctx.moveTo(x * r, (y - 0.08) * r)));
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.lineJoin = 'miter';

  for (const [x, y] of [[-0.55, 0.12], [0.35, -0.16]]) {
    ctx.fillStyle = '#b5986c';
    rect(ctx, r, x - 0.13, y - 0.36, 0.26, 0.34);
    ctx.fillStyle = '#8c7350';
    for (const dx of [-0.13, -0.04, 0.05]) rect(ctx, r, x + dx, y - 0.42, 0.07, 0.07);
    ctx.fillStyle = '#4a3b2a';
    archWindow(ctx, r, x, y - 0.26, 0.08, 0.14);
  }
  const wave = Math.sin(time * 4) * 0.03;
  ctx.fillStyle = '#5c4630';
  rect(ctx, r, 0.34, -0.8, 0.02, 0.3);
  ctx.fillStyle = '#e63946';
  poly(ctx, r, [[0.36, -0.8], [0.58, -0.76 + wave], [0.36, -0.66]]);
  ctx.fill();
}

function tajmahal(ctx, r) {
  ctx.fillStyle = '#7fc8f8';
  rect(ctx, r, -0.2, 0.8, 0.4, 0.16);
  ctx.fillStyle = '#e9e4da';
  rect(ctx, r, -0.95, 0.66, 1.9, 0.14);
  const white = '#fbf8f2';
  const shadowCol = '#e2dccf';
  ctx.fillStyle = white;
  rect(ctx, r, -0.55, 0.05, 1.1, 0.62);
  ctx.fillStyle = shadowCol;
  rect(ctx, r, 0.3, 0.05, 0.25, 0.62);
  ctx.fillStyle = '#c9b99a';
  archWindow(ctx, r, 0, 0.12, 0.3, 0.55);
  for (const x of [-0.4, 0.4]) {
    archWindow(ctx, r, x, 0.2, 0.14, 0.2);
    archWindow(ctx, r, x, 0.44, 0.14, 0.2);
  }

  ctx.fillStyle = white;
  rect(ctx, r, -0.26, -0.12, 0.52, 0.18);
  ctx.beginPath();
  ctx.moveTo(-0.3 * r, -0.12 * r);
  ctx.bezierCurveTo(-0.42 * r, -0.5 * r, -0.12 * r, -0.62 * r, 0, -0.78 * r);
  ctx.bezierCurveTo(0.12 * r, -0.62 * r, 0.42 * r, -0.5 * r, 0.3 * r, -0.12 * r);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = shadowCol;
  ctx.beginPath();
  ctx.moveTo(0.1 * r, -0.12 * r);
  ctx.bezierCurveTo(0.24 * r, -0.4 * r, 0.1 * r, -0.6 * r, 0, -0.78 * r);
  ctx.bezierCurveTo(0.12 * r, -0.62 * r, 0.42 * r, -0.5 * r, 0.3 * r, -0.12 * r);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#c9a227';
  rect(ctx, r, -0.012, -0.9, 0.024, 0.13);

  for (const x of [-0.46, 0.46]) {
    ctx.fillStyle = white;
    rect(ctx, r, x - 0.08, -0.12, 0.16, 0.18);
    ctx.beginPath();
    ctx.arc(x * r, -0.12 * r, 0.08 * r, Math.PI, 0);
    ctx.fill();
  }
  for (const x of [-0.86, 0.86]) {
    ctx.fillStyle = white;
    rect(ctx, r, x - 0.035, -0.46, 0.07, 1.12);
    ctx.fillStyle = shadowCol;
    for (const y of [-0.2, 0.1, 0.4]) rect(ctx, r, x - 0.055, y, 0.11, 0.03);
    ctx.fillStyle = white;
    ctx.beginPath();
    ctx.arc(x * r, -0.46 * r, 0.06 * r, Math.PI, 0);
    ctx.fill();
  }
}

function towerbridge(ctx, r, time) {
  ctx.fillStyle = '#4d7ea8';
  rect(ctx, r, -1, 0.6, 2, 0.36);
  ctx.fillStyle = 'rgba(255,255,255,0.35)';
  for (let i = 0; i < 5; i++) rect(ctx, r, -0.9 + i * 0.42 + Math.sin(time + i) * 0.04, 0.72 + (i % 2) * 0.1, 0.18, 0.02);

  const open = (Math.sin(time * 0.6) * 0.5 + 0.5) * 0.7;
  ctx.fillStyle = '#6c757d';
  for (const [pivot, dir] of [[-0.34, 1], [0.34, -1]]) {
    ctx.save();
    ctx.translate(pivot * r, 0.42 * r);
    ctx.rotate(-open * dir);
    rect(ctx, r, dir > 0 ? 0 : -0.34, -0.04, 0.34, 0.08);
    ctx.restore();
  }
  ctx.fillStyle = '#495057';
  rect(ctx, r, -1, 0.38, 0.5, 0.08);
  rect(ctx, r, 0.5, 0.38, 0.5, 0.08);

  ctx.fillStyle = '#5b8fb9';
  rect(ctx, r, -0.34, -0.5, 0.68, 0.07);
  rect(ctx, r, -0.34, -0.38, 0.68, 0.04);

  for (const x of [-0.46, 0.46]) {
    ctx.fillStyle = '#d9c9a3';
    rect(ctx, r, x - 0.14, -0.6, 0.28, 1.2);
    ctx.fillStyle = '#c4b28a';
    rect(ctx, r, x + 0.06, -0.6, 0.08, 1.2);
    ctx.fillStyle = '#5b8fb9';
    archWindow(ctx, r, x, 0.05, 0.14, 0.35);
    archWindow(ctx, r, x, -0.45, 0.08, 0.16);
    ctx.fillStyle = '#34495e';
    poly(ctx, r, [[x - 0.16, -0.6], [x + 0.16, -0.6], [x, -0.92]]);
    ctx.fill();
    for (const dx of [-0.14, 0.14]) {
      poly(ctx, r, [[x + dx - 0.04, -0.6], [x + dx + 0.04, -0.6], [x + dx, -0.74]]);
      ctx.fill();
    }
    ctx.fillStyle = '#c9a227';
    rect(ctx, r, x - 0.01, -0.99, 0.02, 0.08);
  }
}

function neuschwanstein(ctx, r) {
  ctx.fillStyle = '#8d99ae';
  poly(ctx, r, [[-1, 0.95], [-1, -0.1], [-0.6, -0.55], [-0.25, -0.2], [0.2, -0.7], [0.7, -0.15], [1, -0.35], [1, 0.95]]);
  ctx.fill();
  ctx.fillStyle = '#f8f9fa';
  poly(ctx, r, [[-0.6, -0.55], [-0.45, -0.38], [-0.62, -0.4], [-0.75, -0.38]]);
  ctx.fill();
  poly(ctx, r, [[0.2, -0.7], [0.4, -0.48], [0.18, -0.52], [0.02, -0.5]]);
  ctx.fill();
  ctx.fillStyle = '#2d6a4f';
  poly(ctx, r, [[-1, 0.95], [-1, 0.55], [-0.4, 0.62], [0.3, 0.5], [1, 0.62], [1, 0.95]]);
  ctx.fill();

  const wall = '#f5f3ee';
  const shadowCol = '#dcd8cf';
  const roof = '#3a6ea5';
  const turret = (x, top, w, h) => {
    ctx.fillStyle = wall;
    rect(ctx, r, x - w / 2, top, w, h);
    ctx.fillStyle = shadowCol;
    rect(ctx, r, x + w * 0.2, top, w * 0.3, h);
    ctx.fillStyle = roof;
    poly(ctx, r, [[x - w * 0.62, top], [x + w * 0.62, top], [x, top - w * 1.7]]);
    ctx.fill();
    ctx.fillStyle = '#4a3f35';
    archWindow(ctx, r, x, top + 0.06, w * 0.35, w * 0.6);
  };
  ctx.fillStyle = wall;
  rect(ctx, r, -0.7, 0.05, 1.3, 0.62);
  ctx.fillStyle = shadowCol;
  rect(ctx, r, 0.3, 0.05, 0.3, 0.62);
  ctx.fillStyle = '#b56576';
  poly(ctx, r, [[-0.74, 0.05], [0.64, 0.05], [0.5, -0.12], [-0.6, -0.12]]);
  ctx.fill();
  ctx.fillStyle = '#4a3f35';
  for (let i = 0; i < 5; i++) archWindow(ctx, r, -0.55 + i * 0.25, 0.18, 0.08, 0.16);
  archWindow(ctx, r, -0.05, 0.42, 0.16, 0.25);
  turret(-0.8, -0.05, 0.16, 0.72);
  turret(0.66, 0.0, 0.14, 0.67);
  turret(-0.2, -0.5, 0.2, 0.55);
  turret(0.22, -0.3, 0.13, 0.35);
}

function chichen(ctx, r) {
  const tiers = 7;
  for (let i = 0; i < tiers; i++) {
    const k = i / tiers;
    const half = 0.95 - k * 0.62;
    const y = 0.92 - (i + 1) * 0.16;
    ctx.fillStyle = i % 2 ? '#c9b48a' : '#d8c49b';
    rect(ctx, r, -half, y, half * 2, 0.16);
    ctx.fillStyle = '#a8946c';
    rect(ctx, r, -half, y + 0.13, half * 2, 0.03);
  }
  ctx.fillStyle = '#b8a47c';
  poly(ctx, r, [[-0.14, 0.92], [0.14, 0.92], [0.1, -0.2], [-0.1, -0.2]]);
  ctx.fill();
  ctx.strokeStyle = '#8f7c58';
  ctx.lineWidth = Math.max(1, r * 0.012);
  for (let y = -0.15; y < 0.92; y += 0.06) {
    const w = 0.1 + ((y + 0.2) / 1.12) * 0.04;
    ctx.beginPath();
    ctx.moveTo(-w * r, y * r);
    ctx.lineTo(w * r, y * r);
    ctx.stroke();
  }
  ctx.fillStyle = '#d8c49b';
  rect(ctx, r, -0.24, -0.5, 0.48, 0.3);
  ctx.fillStyle = '#b8a47c';
  rect(ctx, r, -0.27, -0.56, 0.54, 0.07);
  ctx.fillStyle = '#4a3f35';
  for (const x of [-0.12, 0, 0.12]) rect(ctx, r, x - 0.035, -0.42, 0.07, 0.22);
  ctx.fillStyle = '#6a994e';
  poly(ctx, r, [[-0.3, 0.92], [-0.18, 0.92], [-0.1, -0.2], [-0.14, -0.2]]);
  ctx.globalAlpha = 0.25;
  ctx.fill();
  ctx.globalAlpha = 1;
}

function machupicchu(ctx, r, time) {
  ctx.fillStyle = '#40916c';
  poly(ctx, r, [[-0.1, 0.5], [0.35, -0.92], [0.5, -0.85], [0.95, 0.5]]);
  ctx.fill();
  ctx.fillStyle = '#2d6a4f';
  poly(ctx, r, [[0.42, -0.9], [0.5, -0.85], [0.95, 0.5], [0.55, 0.5]]);
  ctx.fill();
  ctx.fillStyle = '#52b788';
  poly(ctx, r, [[-1, 0.95], [-1, 0.2], [-0.5, -0.05], [0.2, 0.15], [1, 0.3], [1, 0.95]]);
  ctx.fill();
  ctx.fillStyle = '#74c69d';
  for (let i = 0; i < 4; i++) {
    const y = 0.28 + i * 0.16;
    rect(ctx, r, -0.95 + i * 0.05, y, 1.9 - i * 0.1, 0.06);
  }
  const house = (x, y, w) => {
    ctx.fillStyle = '#a89f91';
    rect(ctx, r, x, y, w, 0.12);
    ctx.fillStyle = '#8a8174';
    poly(ctx, r, [[x - 0.02, y], [x + w + 0.02, y], [x + w / 2, y - 0.1]]);
    ctx.fill();
    ctx.fillStyle = '#4a3f35';
    rect(ctx, r, x + w / 2 - 0.02, y + 0.04, 0.04, 0.08);
  };
  house(-0.7, 0.02, 0.18);
  house(-0.45, 0.08, 0.16);
  house(-0.2, 0.1, 0.2);
  house(0.1, 0.16, 0.16);
  house(-0.55, 0.32, 0.2);
  house(0.25, 0.36, 0.18);

  const drift = Math.sin(time * 0.3) * 0.2;
  ctx.fillStyle = 'rgba(255,255,255,0.75)';
  for (const [x, y, s] of [[-0.3, -0.45, 0.16], [-0.1, -0.5, 0.2], [0.1, -0.44, 0.14]]) {
    ctx.beginPath();
    ctx.arc((x + drift) * r, y * r, s * r, 0, Math.PI * 2);
    ctx.fill();
  }
}

function moai(ctx, r, time) {
  ctx.fillStyle = '#6c757d';
  rect(ctx, r, -0.98, 0.72, 1.96, 0.22);
  ctx.fillStyle = '#5a6168';
  rect(ctx, r, -0.98, 0.88, 1.96, 0.06);
  const head = (x, scale, hat) => {
    const s = scale;
    ctx.fillStyle = '#7d7468';
    ctx.beginPath();
    ctx.moveTo((x - 0.2 * s) * r, 0.72 * r);
    ctx.lineTo((x - 0.22 * s) * r, (0.72 - 0.9 * s) * r);
    ctx.quadraticCurveTo(x * r, (0.72 - 1.05 * s) * r, (x + 0.22 * s) * r, (0.72 - 0.9 * s) * r);
    ctx.lineTo((x + 0.2 * s) * r, 0.72 * r);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#5e564c';
    rect(ctx, r, x - 0.2 * s, 0.72 - 0.66 * s, 0.4 * s, 0.1 * s);
    rect(ctx, r, x - 0.05 * s, 0.72 - 0.6 * s, 0.1 * s, 0.3 * s);
    rect(ctx, r, x - 0.12 * s, 0.72 - 0.22 * s, 0.24 * s, 0.05 * s);
    rect(ctx, r, x - 0.3 * s, 0.72 - 0.75 * s, 0.08 * s, 0.32 * s);
    rect(ctx, r, x + 0.22 * s, 0.72 - 0.75 * s, 0.08 * s, 0.32 * s);
    if (hat) {
      ctx.fillStyle = '#a44a3f';
      rect(ctx, r, x - 0.16 * s, 0.72 - 1.12 * s, 0.32 * s, 0.14 * s);
    }
  };
  head(-0.6, 0.72, false);
  head(0.58, 0.78, false);
  head(0, 1.05, true);
  // Surf rolling against the platform.
  ctx.fillStyle = '#4cc9f0';
  ctx.beginPath();
  ctx.moveTo(-0.98 * r, 0.96 * r);
  for (let x = -0.98; x <= 0.99; x += 0.14) ctx.lineTo(x * r, (0.9 + Math.sin(time * 2.5 + x * 9) * 0.025) * r);
  ctx.lineTo(0.98 * r, 0.96 * r);
  ctx.fill();
}

const DRAW = {
  eiffel, liberty, pyramid, bigben, colosseum, pisa, fuji, turtle, arc, stonehenge,
  parthenon, greatwall, tajmahal, towerbridge, neuschwanstein, chichen, machupicchu, moai,
};

export function drawLandmark(ctx, type, r, time) {
  // A layered miniature foundation anchors every destination in the world.
  ctx.save();
  const base = ctx.createLinearGradient(0, r*0.75, 0, r*1.1);
  base.addColorStop(0, '#f2deac');base.addColorStop(1, '#8b706b');
  ctx.fillStyle = base;
  ctx.beginPath();ctx.ellipse(0,r*0.91,r*1.07,r*0.2,0,0,Math.PI*2);ctx.fill();
  ctx.fillStyle = '#c8ddae';
  ctx.beginPath();ctx.ellipse(0,r*0.86,r*1.07,r*0.17,0,0,Math.PI*2);ctx.fill();
  ctx.strokeStyle = 'rgba(255,249,220,0.8)';ctx.lineWidth = r*0.023;ctx.stroke();
  if (!drawNewLandmark(ctx, type, r, time)) DRAW[type]?.(ctx, r, time);
  // Fine architectural details remain visible in close-up and simplify at thumbnail size.
  if (type === 'eiffel') {
    ctx.strokeStyle='#f7cc82';ctx.lineWidth=r*0.016;
    for(const s of [-1,1]) {
      ctx.beginPath();ctx.moveTo(s*0.74*r,0.89*r);ctx.lineTo(s*0.32*r,0.2*r);ctx.lineTo(s*0.11*r,-0.43*r);ctx.lineTo(s*0.025*r,-0.88*r);ctx.stroke();
      for(let i=0;i<5;i++) {const y=0.35+i*0.11,x=0.34+(y-0.2)*0.45;ctx.beginPath();ctx.moveTo(s*(x-0.12)*r,y*r);ctx.lineTo(s*x*r,(y-0.09)*r);ctx.stroke();}
    }
    for(const [y,w] of [[0.18,0.85],[-0.44,0.38]]) {ctx.fillStyle='#ffe1a0';ctx.fillRect(-w*r/2,y*r,w*r,r*0.024);}
  }
  if (['eiffel','bigben','pisa','colosseum','arc','parthenon','tajmahal','turtle','towerbridge','neuschwanstein','pagoda','petra','saintbasil'].includes(type)) {
    // Tiny flowering gardens frame the architecture without hiding the silhouette.
    for(const s of [-1,1]) {
      ctx.fillStyle='#417e68';ctx.beginPath();ctx.ellipse(s*0.82*r,0.87*r,r*0.15,r*0.065,0,0,Math.PI*2);ctx.fill();
      for(let i=0;i<3;i++) {ctx.fillStyle=i%2?'#fff5c0':'#f593b0';ctx.beginPath();ctx.arc((s*0.82+(i-1)*0.065)*r,(0.845-(i%2)*0.026)*r,r*0.022,0,Math.PI*2);ctx.fill();}
    }
  }
  ctx.restore();
}
