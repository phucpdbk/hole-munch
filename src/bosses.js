// Boss and landmark rendering: sticker-style sprites (lit + outlined via an offscreen
// canvas), living faces, aura and fear reactions. Coordinates are in units of r.
import { drawLandmark } from './landmarks.js';

const TAU = Math.PI * 2;
const OUTLINE = '#1d1a2e';

// ---------- helpers ----------

function lighten(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const c = (v) => Math.max(0, Math.min(255, v + amt));
  return `rgb(${c(n >> 16)},${c((n >> 8) & 255)},${c(n & 255)})`;
}

// Soft 3D ball: light from the top-left, darker rim.
function ball(ctx, r, x, y, rx, ry, color, rot = 0) {
  const g = ctx.createRadialGradient((x - rx * 0.35) * r, (y - ry * 0.4) * r, 0, x * r, y * r, Math.max(rx, ry) * r * 1.05);
  g.addColorStop(0, lighten(color, 45));
  g.addColorStop(0.55, color);
  g.addColorStop(1, lighten(color, -55));
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.ellipse(x * r, y * r, rx * r, ry * r, rot, 0, TAU);
  ctx.fill();
}

function shine(ctx, r, x, y, rx, ry, alpha = 0.55, rot = -0.5) {
  ctx.fillStyle = `rgba(255,255,255,${alpha})`;
  ctx.beginPath();
  ctx.ellipse(x * r, y * r, rx * r, ry * r, rot, 0, TAU);
  ctx.fill();
}

function disc(ctx, r, x, y, rr, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x * r, y * r, rr * r, 0, TAU);
  ctx.fill();
}

function star4(ctx, x, y, s) {
  ctx.beginPath();
  ctx.moveTo(x, y - s);
  ctx.quadraticCurveTo(x, y, x + s, y);
  ctx.quadraticCurveTo(x, y, x, y + s);
  ctx.quadraticCurveTo(x, y, x - s, y);
  ctx.quadraticCurveTo(x, y, x, y - s);
  ctx.fill();
}

// ---------- faces ----------

// st: { time, blink, fear, lx, ly }
function drawEyes(ctx, r, eyes, er, st, opts = {}) {
  const grow = 1 + st.fear * 0.25;
  const e = er * grow;
  const pupil = e * (opts.pupil ?? 0.55) * (1 - st.fear * 0.35);
  for (const [x, y] of eyes) {
    if (st.blink && st.fear < 0.5) {
      ctx.strokeStyle = OUTLINE;
      ctx.lineWidth = Math.max(1.5, e * r * 0.28);
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(x * r, y * r, e * r * 0.7, 0.15 * Math.PI, 0.85 * Math.PI);
      ctx.stroke();
      ctx.lineCap = 'butt';
      continue;
    }
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.ellipse(x * r, y * r, e * r, e * r * 1.08, 0, 0, TAU);
    ctx.fill();
    ctx.strokeStyle = OUTLINE;
    ctx.lineWidth = Math.max(1, e * r * 0.14);
    ctx.stroke();
    const px = (x + st.lx * e * 0.38) * r;
    const py = (y + st.ly * e * 0.38) * r;
    ctx.fillStyle = opts.iris || '#2b2d42';
    ctx.beginPath();
    ctx.arc(px, py, pupil * r, 0, TAU);
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(px - pupil * r * 0.35, py - pupil * r * 0.4, pupil * r * 0.38, 0, TAU);
    ctx.fill();
  }
  if (st.fear > 0.35) {
    // Worried brows.
    ctx.strokeStyle = OUTLINE;
    ctx.lineWidth = Math.max(1.5, er * r * 0.25);
    ctx.lineCap = 'round';
    for (const [x, y] of eyes) {
      const s = x < eyes[0][0] + 0.001 && eyes.length > 1 ? -1 : 1;
      ctx.beginPath();
      ctx.moveTo((x - e * 0.8) * r, (y - e * 1.45 + (s < 0 ? 0.1 * e : -0.25 * e)) * r);
      ctx.lineTo((x + e * 0.8) * r, (y - e * 1.45 + (s < 0 ? -0.25 * e : 0.1 * e)) * r);
      ctx.stroke();
    }
    ctx.lineCap = 'butt';
  }
}

function drawMouth(ctx, r, x, y, w, st, color = OUTLINE) {
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = Math.max(1.5, w * r * 0.14);
  ctx.lineCap = 'round';
  if (st.fear > 0.45) {
    const shake = Math.sin(st.time * 40) * 0.08 * w;
    ctx.beginPath();
    ctx.ellipse((x + shake) * r, (y + w * 0.1) * r, w * 0.35 * r, w * (0.3 + st.fear * 0.2) * r, 0, 0, TAU);
    ctx.fill();
    ctx.fillStyle = '#ff6b8b';
    ctx.beginPath();
    ctx.ellipse((x + shake) * r, (y + w * 0.25) * r, w * 0.2 * r, w * 0.1 * r, 0, 0, TAU);
    ctx.fill();
  } else {
    ctx.beginPath();
    ctx.arc(x * r, (y - w * 0.25) * r, w * 0.5 * r, 0.2 * Math.PI, 0.8 * Math.PI);
    ctx.stroke();
  }
  ctx.lineCap = 'butt';
}

function blush(ctx, r, pts, rr) {
  ctx.fillStyle = 'rgba(255,105,140,0.4)';
  for (const [x, y] of pts) {
    ctx.beginPath();
    ctx.ellipse(x * r, y * r, rr * r, rr * r * 0.6, 0, 0, TAU);
    ctx.fill();
  }
}

function sweat(ctx, r, x, y, st) {
  if (st.fear < 0.3) return;
  for (let i = 0; i < 2; i++) {
    const p = (st.time * 1.6 + i * 0.5) % 1;
    const sx = (x + i * 0.12) * r;
    const sy = (y + p * 0.35) * r;
    const s = 0.07 * r;
    ctx.globalAlpha = (1 - p) * Math.min(1, st.fear * 1.5);
    ctx.fillStyle = '#8fd3ff';
    ctx.beginPath();
    ctx.moveTo(sx, sy - s * 1.6);
    ctx.quadraticCurveTo(sx + s, sy, sx, sy + s * 0.8);
    ctx.quadraticCurveTo(sx - s, sy, sx, sy - s * 1.6);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

// ---------- bosses (bodies + faces), drawn centred, r = radius ----------

const BOSSES = {
  duck(ctx, r, st) {
    ctx.fillStyle = 'rgba(120,200,255,0.5)';
    ctx.beginPath();
    ctx.ellipse(0, 0.62 * r, 1.05 * r, 0.22 * r, 0, 0, TAU);
    ctx.fill();
    ball(ctx, r, -0.1, 0.2, 0.95, 0.62, '#ffd23f');
    // Tail flick.
    ctx.fillStyle = '#ffc300';
    ctx.beginPath();
    ctx.moveTo(-0.9 * r, 0.05 * r);
    ctx.quadraticCurveTo(-1.15 * r, -0.25 * r, -1.02 * r, -0.35 * r);
    ctx.quadraticCurveTo(-0.85 * r, -0.1 * r, -0.7 * r, -0.05 * r);
    ctx.fill();
    const flap = Math.sin(st.time * 5) * 0.08 * (1 + st.fear * 2);
    ctx.save();
    ctx.translate(-0.25 * r, 0.18 * r);
    ctx.rotate(-0.35 + flap);
    ball(ctx, r, 0, 0, 0.42, 0.24, '#ffc300');
    ctx.restore();
    ball(ctx, r, 0.3, -0.42, 0.5, 0.48, '#ffd23f');
    shine(ctx, r, 0.12, -0.68, 0.16, 0.08);
    // Beak.
    ball(ctx, r, 0.34, -0.2, 0.3, 0.13, '#ff8c1a');
    ctx.fillStyle = '#d9670b';
    ctx.fillRect(0.08 * r, -0.21 * r, 0.52 * r, 0.03 * r);
    blush(ctx, r, [[0.02, -0.3], [0.64, -0.3]], 0.08);
    drawEyes(ctx, r, [[0.16, -0.52], [0.46, -0.52]], 0.1, st);
    sweat(ctx, r, 0.75, -0.7, st);
  },

  pizza(ctx, r, st) {
    ball(ctx, r, 0, 0, 1, 1, '#d99a55');
    ctx.fillStyle = '#ffcf5c';
    ctx.beginPath();
    for (let i = 0; i <= 24; i++) {
      const a = (i / 24) * TAU;
      const rr = 0.84 + (i % 2 ? 0.03 : -0.02) + Math.sin(i * 1.7) * 0.02;
      ctx.lineTo(Math.cos(a) * rr * r, Math.sin(a) * rr * r);
    }
    ctx.fill();
    // Cheese drips over the crust.
    for (const a of [0.6, 2.1, 3.9, 5.2]) {
      ctx.beginPath();
      ctx.ellipse(Math.cos(a) * 0.86 * r, Math.sin(a) * 0.86 * r, 0.08 * r, 0.13 * r, a + Math.PI / 2, 0, TAU);
      ctx.fill();
    }
    for (const [x, y, s] of [[-0.5, 0.35, 1], [0.55, 0.3, 0.9], [-0.15, 0.62, 0.85], [0.1, -0.62, 0.8], [-0.62, -0.2, 0.8], [0.62, -0.25, 0.75]]) {
      ball(ctx, r, x, y, 0.14 * s, 0.14 * s, '#d62828');
      disc(ctx, r, x - 0.04 * s, y - 0.03 * s, 0.025, 'rgba(255,255,255,0.5)');
    }
    ctx.fillStyle = '#2d9d52';
    for (const [x, y, a] of [[0.35, 0.6, 0.6], [-0.4, -0.55, -0.4], [0.7, 0.05, 1.2]]) {
      ctx.beginPath();
      ctx.ellipse(x * r, y * r, 0.09 * r, 0.045 * r, a, 0, TAU);
      ctx.fill();
    }
    shine(ctx, r, -0.4, -0.45, 0.25, 0.1, 0.3);
    blush(ctx, r, [[-0.42, 0.12], [0.42, 0.12]], 0.1);
    drawEyes(ctx, r, [[-0.25, -0.12], [0.25, -0.12]], 0.14, st);
    drawMouth(ctx, r, 0, 0.22, 0.3, st);
    sweat(ctx, r, 0.55, -0.45, st);
    // Steam.
    ctx.strokeStyle = 'rgba(255,255,255,0.55)';
    ctx.lineWidth = 0.04 * r;
    ctx.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      const p = (st.time * 0.5 + i / 3) % 1;
      const x = (-0.3 + i * 0.3) * r;
      ctx.globalAlpha = Math.sin(p * Math.PI) * 0.8;
      ctx.beginPath();
      ctx.moveTo(x, (-0.8 - p * 0.4) * r);
      ctx.quadraticCurveTo(x + 0.12 * r, (-0.95 - p * 0.4) * r, x, (-1.1 - p * 0.4) * r);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    ctx.lineCap = 'butt';
  },

  frog(ctx, r, st) {
    ball(ctx, r, 0, 0.18, 1, 0.72, '#4caf50');
    ball(ctx, r, 0, 0.45, 0.62, 0.36, '#b5e48c');
    for (const s of [-1, 1]) {
      ball(ctx, r, s * 0.72, 0.72, 0.28, 0.14, '#43a047');
      ball(ctx, r, s * 0.45, -0.45, 0.32, 0.3, '#4caf50');
    }
    for (const [x, y, s] of [[-0.6, 0.05, 0.08], [0.55, -0.02, 0.06], [0.2, 0.05, 0.05], [-0.25, -0.12, 0.05]]) {
      disc(ctx, r, x, y, s, '#388e3c');
    }
    shine(ctx, r, -0.55, -0.62, 0.12, 0.06);
    shine(ctx, r, 0.35, -0.62, 0.12, 0.06);
    drawEyes(ctx, r, [[-0.45, -0.48], [0.45, -0.48]], 0.2, st, { pupil: 0.5 });
    blush(ctx, r, [[-0.62, 0.12], [0.62, 0.12]], 0.1);
    if (st.fear > 0.45) drawMouth(ctx, r, 0, 0.12, 0.4, st);
    else {
      ctx.strokeStyle = '#1b5e20';
      ctx.lineWidth = 0.05 * r;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(0, -0.2 * r, 0.5 * r, 0.25 * Math.PI, 0.75 * Math.PI);
      ctx.stroke();
      ctx.lineCap = 'butt';
      // Tongue flick every few seconds.
      const p = (st.time % 4.3) / 0.35;
      if (p < 1) {
        const len = Math.sin(p * Math.PI) * 0.6;
        ctx.strokeStyle = '#ff6b8b';
        ctx.lineWidth = 0.07 * r;
        ctx.beginPath();
        ctx.moveTo(0, 0.15 * r);
        ctx.lineTo(len * 0.8 * r, (0.15 + len * 0.3) * r);
        ctx.stroke();
        disc(ctx, r, len * 0.8, 0.15 + len * 0.3, 0.06, '#ff6b8b');
      }
    }
    sweat(ctx, r, 0.8, -0.6, st);
  },

  cow(ctx, r, st) {
    const ear = Math.sin(st.time * 3) * 0.12;
    for (const s of [-1, 1]) {
      ctx.fillStyle = '#e8e2d6';
      ctx.beginPath();
      ctx.moveTo(s * 0.45 * r, -0.62 * r);
      ctx.quadraticCurveTo(s * 0.72 * r, -1.05 * r, s * 0.62 * r, -1.12 * r);
      ctx.quadraticCurveTo(s * 0.55 * r, -0.85 * r, s * 0.28 * r, -0.7 * r);
      ctx.fill();
      ctx.save();
      ctx.translate(s * 0.82 * r, -0.4 * r);
      ctx.rotate(s * (0.4 + ear));
      ball(ctx, r, 0, 0, 0.3, 0.14, '#f5f5f5');
      ball(ctx, r, 0.05 * s, 0, 0.18, 0.07, '#f8bbd0');
      ctx.restore();
    }
    ball(ctx, r, 0, 0, 0.82, 0.8, '#fafafa');
    ctx.fillStyle = '#2b2b2b';
    for (const [x, y, rx, ry, a] of [[-0.45, -0.3, 0.22, 0.17, 0.5], [0.5, -0.05, 0.18, 0.24, -0.3], [-0.2, -0.62, 0.12, 0.08, 0]]) {
      ctx.beginPath();
      ctx.ellipse(x * r, y * r, rx * r, ry * r, a, 0, TAU);
      ctx.fill();
    }
    ball(ctx, r, 0, 0.42, 0.55, 0.33, '#f8bbd0');
    disc(ctx, r, -0.18, 0.42, 0.07, '#b56576');
    disc(ctx, r, 0.18, 0.42, 0.07, '#b56576');
    shine(ctx, r, -0.35, -0.55, 0.2, 0.08, 0.5);
    // Bell.
    ball(ctx, r, 0, 0.86, 0.14, 0.12, '#ffd23f');
    disc(ctx, r, 0, 0.92, 0.035, '#7a5c00');
    drawEyes(ctx, r, [[-0.3, -0.1], [0.3, -0.1]], 0.13, st);
    if (st.fear > 0.45) drawMouth(ctx, r, 0, 0.62, 0.25, st);
    sweat(ctx, r, 0.7, -0.4, st);
  },

  dumbbell(ctx, r, st) {
    const bar = ctx.createLinearGradient(0, -0.12 * r, 0, 0.12 * r);
    bar.addColorStop(0, '#e0e0e0');
    bar.addColorStop(0.5, '#9e9e9e');
    bar.addColorStop(1, '#616161');
    ctx.fillStyle = bar;
    ctx.fillRect(-0.75 * r, -0.12 * r, 1.5 * r, 0.24 * r);
    for (const s of [-1, 1]) {
      for (const [dx, h, w] of [[0.62, 1.1, 0.18], [0.84, 0.86, 0.16]]) {
        const x = s * dx;
        const g = ctx.createLinearGradient((x - w / 2) * r, 0, (x + w / 2) * r, 0);
        g.addColorStop(0, '#fff176');
        g.addColorStop(0.4, '#ffd23f');
        g.addColorStop(1, '#c79100');
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.roundRect((x - w / 2) * r, (-h / 2) * r, w * r, h * r, 0.06 * r);
        ctx.fill();
      }
    }
    // Centre hub carries the face.
    ball(ctx, r, 0, 0, 0.4, 0.4, '#ffd23f');
    shine(ctx, r, -0.14, -0.18, 0.12, 0.06, 0.6);
    const glint = (st.time * 0.7) % 1;
    ctx.fillStyle = `rgba(255,255,255,${Math.sin(glint * Math.PI) * 0.9})`;
    star4(ctx, (-0.62 + glint * 1.24) * r, -0.45 * r, 0.1 * r);
    drawEyes(ctx, r, [[-0.13, -0.06], [0.13, -0.06]], 0.09, st);
    drawMouth(ctx, r, 0, 0.16, 0.16, st);
    sweat(ctx, r, 0.3, -0.35, st);
  },

  snowman(ctx, r, st) {
    const wave = Math.sin(st.time * 3) * 0.25 + st.fear * Math.sin(st.time * 25) * 0.2;
    ctx.strokeStyle = '#6d4c41';
    ctx.lineWidth = 0.05 * r;
    ctx.lineCap = 'round';
    for (const s of [-1, 1]) {
      const a = s * (0.5 + (s > 0 ? wave : 0));
      ctx.beginPath();
      ctx.moveTo(s * 0.45 * r, 0.1 * r);
      const ex = s * 0.95 * r;
      const ey = (-0.2 - (s > 0 ? wave * 0.6 : 0)) * r;
      ctx.lineTo(ex, ey);
      ctx.moveTo(s * 0.8 * r, (-0.1 - (s > 0 ? wave * 0.5 : 0)) * r);
      ctx.lineTo(s * 0.92 * r, (-0.02 - (s > 0 ? wave * 0.5 : 0)) * r - a * 0.01);
      ctx.stroke();
    }
    ctx.lineCap = 'butt';
    ball(ctx, r, 0, 0.42, 0.62, 0.55, '#f4faff');
    ball(ctx, r, 0, -0.4, 0.42, 0.4, '#f4faff');
    shine(ctx, r, -0.2, -0.58, 0.12, 0.06, 0.8);
    for (let i = 0; i < 3; i++) disc(ctx, r, 0, 0.2 + i * 0.18, 0.045, '#263238');
    // Scarf.
    ctx.fillStyle = '#e63946';
    ctx.beginPath();
    ctx.roundRect(-0.42 * r, -0.12 * r, 0.84 * r, 0.14 * r, 0.06 * r);
    ctx.fill();
    ctx.save();
    ctx.translate(0.22 * r, -0.02 * r);
    ctx.rotate(0.2 + Math.sin(st.time * 4) * 0.12);
    ctx.fillRect(0, 0, 0.14 * r, 0.36 * r);
    ctx.restore();
    ctx.fillStyle = '#fff';
    for (let i = 0; i < 4; i++) ctx.fillRect((-0.36 + i * 0.2) * r, -0.12 * r, 0.06 * r, 0.14 * r);
    // Hat.
    ctx.fillStyle = '#212121';
    ctx.beginPath();
    ctx.roundRect(-0.36 * r, -0.8 * r, 0.72 * r, 0.1 * r, 0.04 * r);
    ctx.fill();
    ctx.fillRect(-0.24 * r, -1.2 * r, 0.48 * r, 0.42 * r);
    ctx.fillStyle = '#c1121f';
    ctx.fillRect(-0.24 * r, -0.9 * r, 0.48 * r, 0.08 * r);
    // Carrot.
    ctx.fillStyle = '#ff7b00';
    ctx.beginPath();
    ctx.moveTo(0.02 * r, -0.4 * r);
    ctx.lineTo(0.38 * r, -0.33 * r);
    ctx.lineTo(0.02 * r, -0.28 * r);
    ctx.fill();
    blush(ctx, r, [[-0.25, -0.3], [0.28, -0.28]], 0.07);
    drawEyes(ctx, r, [[-0.14, -0.5], [0.14, -0.5]], 0.075, st, { pupil: 0.8 });
    if (st.fear > 0.45) drawMouth(ctx, r, 0, -0.2, 0.14, st);
    else for (let i = 0; i < 5; i++) disc(ctx, r, -0.14 + i * 0.07, -0.22 + Math.abs(i - 2) * -0.018, 0.022, '#263238');
    sweat(ctx, r, 0.35, -0.7, st);
  },

  cat(ctx, r, st) {
    const swish = Math.sin(st.time * 2.5) * 0.4;
    ctx.strokeStyle = '#e76f51';
    ctx.lineWidth = 0.16 * r;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(0.6 * r, 0.5 * r);
    ctx.quadraticCurveTo((1.1 + swish * 0.2) * r, 0.3 * r, (0.95 + swish * 0.4) * r, (-0.2 + Math.abs(swish) * 0.2) * r);
    ctx.stroke();
    ctx.lineCap = 'butt';
    for (const s of [-1, 1]) {
      ctx.fillStyle = '#f4a261';
      ctx.beginPath();
      ctx.moveTo(s * 0.78 * r, -0.3 * r);
      ctx.lineTo(s * 0.62 * r, -1.02 * r);
      ctx.lineTo(s * 0.18 * r, -0.66 * r);
      ctx.fill();
      ctx.fillStyle = '#ffafcc';
      ctx.beginPath();
      ctx.moveTo(s * 0.66 * r, -0.42 * r);
      ctx.lineTo(s * 0.6 * r, -0.86 * r);
      ctx.lineTo(s * 0.34 * r, -0.64 * r);
      ctx.fill();
    }
    ball(ctx, r, 0, 0.08, 0.95, 0.82, '#f4a261');
    ball(ctx, r, 0, 0.4, 0.5, 0.36, '#fff1e6');
    ctx.fillStyle = '#e76f51';
    for (const dx of [-0.16, 0, 0.16]) {
      ctx.beginPath();
      ctx.ellipse(dx * r, -0.62 * r, 0.04 * r, 0.12 * r, 0, 0, TAU);
      ctx.fill();
    }
    for (const s of [-1, 1]) {
      ctx.beginPath();
      ctx.ellipse(s * 0.82 * r, 0.05 * r, 0.1 * r, 0.04 * r, 0, 0, TAU);
      ctx.fill();
      ball(ctx, r, s * 0.35, 0.78, 0.2, 0.12, '#fff1e6');
    }
    shine(ctx, r, -0.45, -0.45, 0.18, 0.07, 0.4);
    blush(ctx, r, [[-0.5, 0.15], [0.5, 0.15]], 0.11);
    drawEyes(ctx, r, [[-0.3, -0.12], [0.3, -0.12]], 0.16, st, { iris: '#2a9d8f', pupil: 0.6 });
    ball(ctx, r, 0, 0.12, 0.07, 0.05, '#ff6b8b');
    if (st.fear > 0.45) drawMouth(ctx, r, 0, 0.28, 0.2, st);
    else {
      ctx.strokeStyle = OUTLINE;
      ctx.lineWidth = 0.03 * r;
      ctx.beginPath();
      ctx.arc(-0.07 * r, 0.18 * r, 0.07 * r, 0.1, Math.PI - 0.1);
      ctx.arc(0.07 * r, 0.18 * r, 0.07 * r, 0.1, Math.PI - 0.1);
      ctx.stroke();
    }
    ctx.strokeStyle = 'rgba(40,30,30,0.6)';
    ctx.lineWidth = 0.02 * r;
    for (const s of [-1, 1]) {
      for (const dy of [-0.04, 0.06]) {
        ctx.beginPath();
        ctx.moveTo(s * 0.2 * r, (0.15 + dy) * r);
        ctx.lineTo(s * 0.62 * r, (0.12 + dy * 2) * r);
        ctx.stroke();
      }
    }
    sweat(ctx, r, 0.72, -0.55, st);
  },

  pumpkin(ctx, r, st) {
    ctx.fillStyle = '#2d6a4f';
    ctx.beginPath();
    ctx.ellipse(0.28 * r, -0.86 * r, 0.24 * r, 0.1 * r, -0.4, 0, TAU);
    ctx.fill();
    ctx.strokeStyle = '#40916c';
    ctx.lineWidth = 0.03 * r;
    ctx.beginPath();
    ctx.arc(-0.3 * r, -0.85 * r, 0.12 * r, 0, Math.PI * 1.6);
    ctx.stroke();
    for (const [x, rx, c] of [[-0.55, 0.45, '#e85d04'], [0.55, 0.45, '#e85d04'], [-0.28, 0.45, '#f48c06'], [0.28, 0.45, '#f48c06'], [0, 0.42, '#faa307']]) {
      ball(ctx, r, x, 0.1, rx, 0.78, c);
    }
    const stem = ctx.createLinearGradient(-0.08 * r, 0, 0.08 * r, 0);
    stem.addColorStop(0, '#6f4518');
    stem.addColorStop(1, '#3e2410');
    ctx.fillStyle = stem;
    ctx.beginPath();
    ctx.roundRect(-0.08 * r, -0.98 * r, 0.16 * r, 0.32 * r, 0.04 * r);
    ctx.fill();
    shine(ctx, r, -0.35, -0.4, 0.1, 0.22, 0.35, 0.2);
    // Carved face, candle-lit.
    const flick = 0.75 + Math.sin(st.time * (7 + st.fear * 20)) * 0.15 + Math.sin(st.time * 13) * 0.1;
    const glow = ctx.createRadialGradient(0, 0.1 * r, 0, 0, 0.1 * r, 0.6 * r);
    glow.addColorStop(0, `rgba(255,255,220,${flick})`);
    glow.addColorStop(1, `rgba(255,214,10,${flick})`);
    const eyeH = st.blink && st.fear < 0.5 ? 0.05 : 0.28 + st.fear * 0.08;
    const carve = () => {
      ctx.beginPath();
      for (const s of [-1, 1]) {
        ctx.moveTo((s * 0.45 + st.lx * 0.04) * r, -0.05 * r);
        ctx.lineTo((s * 0.13 + st.lx * 0.04) * r, -0.05 * r);
        ctx.lineTo((s * 0.29 + st.lx * 0.04) * r, (-0.05 - eyeH) * r);
        ctx.closePath();
      }
      if (st.fear > 0.45) {
        ctx.moveTo(0.16 * r, 0.38 * r);
        ctx.ellipse(0, 0.38 * r, 0.16 * r, 0.2 * r, 0, 0, TAU);
      } else {
        ctx.moveTo(-0.5 * r, 0.25 * r);
        for (let i = 0; i <= 8; i++) ctx.lineTo((-0.5 + i * 0.125) * r, (i % 2 ? 0.55 : 0.36) * r);
        ctx.lineTo(0.5 * r, 0.25 * r);
        ctx.quadraticCurveTo(0, 0.45 * r, -0.5 * r, 0.25 * r);
      }
    };
    carve();
    ctx.lineJoin = 'round';
    ctx.strokeStyle = '#6a2c00';
    ctx.lineWidth = 0.07 * r;
    ctx.stroke();
    ctx.fillStyle = glow;
    ctx.fill();
    ctx.lineJoin = 'miter';
    sweat(ctx, r, 0.7, -0.5, st);
  },

  kraken(ctx, r, st) {
    const speed = 2 + st.fear * 6;
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * TAU + 0.2;
      ctx.save();
      ctx.rotate(a);
      const w1 = Math.sin(st.time * speed + i) * 0.25;
      const w2 = Math.sin(st.time * speed + i + 1.2) * 0.3;
      ctx.strokeStyle = '#7b2cbf';
      ctx.lineCap = 'round';
      ctx.lineWidth = 0.22 * r;
      ctx.beginPath();
      ctx.moveTo(0.4 * r, 0);
      ctx.quadraticCurveTo(0.75 * r, w1 * r, 1.05 * r, w2 * r);
      ctx.stroke();
      ctx.strokeStyle = '#9d4edd';
      ctx.lineWidth = 0.12 * r;
      ctx.stroke();
      ctx.fillStyle = '#e0aaff';
      for (const k of [0.55, 0.75, 0.92]) {
        const y = (k < 0.75 ? w1 * (k - 0.4) / 0.35 : w1 + (w2 - w1) * (k - 0.75) / 0.3) * r;
        ctx.beginPath();
        ctx.arc(k * r, y, 0.035 * r, 0, TAU);
        ctx.fill();
      }
      ctx.restore();
    }
    ctx.lineCap = 'butt';
    ball(ctx, r, 0, -0.08, 0.62, 0.66, '#9d4edd');
    for (const [x, y, s] of [[-0.35, -0.45, 0.07], [0.3, -0.55, 0.05], [0.42, -0.2, 0.06], [-0.1, -0.62, 0.04]]) {
      disc(ctx, r, x, y, s, '#c77dff');
    }
    shine(ctx, r, -0.25, -0.45, 0.16, 0.08, 0.5);
    blush(ctx, r, [[-0.38, 0.18], [0.38, 0.18]], 0.09);
    drawEyes(ctx, r, [[-0.22, -0.08], [0.22, -0.08]], 0.17, st, { iris: '#240046' });
    drawMouth(ctx, r, 0, 0.26, 0.2, st);
    sweat(ctx, r, 0.5, -0.5, st);
  },

  ufo(ctx, r, st) {
    // Tractor beam.
    const beam = 0.25 + Math.sin(st.time * 3) * 0.1;
    const g = ctx.createLinearGradient(0, 0.2 * r, 0, 1.1 * r);
    g.addColorStop(0, `rgba(158,240,26,${beam + 0.2})`);
    g.addColorStop(1, 'rgba(158,240,26,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(-0.3 * r, 0.2 * r);
    ctx.lineTo(0.3 * r, 0.2 * r);
    ctx.lineTo(0.7 * r, 1.1 * r);
    ctx.lineTo(-0.7 * r, 1.1 * r);
    ctx.fill();
    // Glass dome with the pilot inside.
    const dome = ctx.createRadialGradient(-0.15 * r, -0.55 * r, 0, 0, -0.3 * r, 0.55 * r);
    dome.addColorStop(0, 'rgba(220,250,255,0.95)');
    dome.addColorStop(1, 'rgba(120,200,230,0.85)');
    ctx.fillStyle = dome;
    ctx.beginPath();
    ctx.ellipse(0, -0.2 * r, 0.5 * r, 0.52 * r, 0, Math.PI, 0);
    ctx.fill();
    const bob = Math.sin(st.time * 2.5) * 0.03;
    ctx.strokeStyle = '#70e000';
    ctx.lineWidth = 0.035 * r;
    for (const s of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(s * 0.1 * r, (-0.5 + bob) * r);
      ctx.lineTo(s * 0.18 * r, (-0.68 + bob) * r);
      ctx.stroke();
      disc(ctx, r, s * 0.18, -0.7 + bob, 0.045, '#ffbe0b');
    }
    ball(ctx, r, 0, -0.32 + bob, 0.26, 0.22, '#70e000');
    drawEyes(ctx, r, [[-0.1, -0.35 + bob], [0.1, -0.35 + bob]], 0.075, st, { pupil: 0.7 });
    if (st.fear > 0.45) drawMouth(ctx, r, 0, -0.2 + bob, 0.1, st);
    shine(ctx, r, -0.25, -0.5, 0.1, 0.16, 0.6, 0.4);
    // Saucer.
    const metal = ctx.createLinearGradient(0, -0.35 * r, 0, 0.35 * r);
    metal.addColorStop(0, '#f1f3f5');
    metal.addColorStop(0.45, '#adb5bd');
    metal.addColorStop(1, '#495057');
    ctx.fillStyle = metal;
    ctx.beginPath();
    ctx.ellipse(0, 0, r, 0.36 * r, 0, 0, TAU);
    ctx.fill();
    ctx.fillStyle = '#6c757d';
    ctx.beginPath();
    ctx.ellipse(0, 0.14 * r, 0.62 * r, 0.16 * r, 0, 0, Math.PI);
    ctx.fill();
    const colors = ['#ff006e', '#ffbe0b', '#3a86ff', '#9ef01a'];
    for (let i = 0; i < 7; i++) {
      const on = (Math.floor(st.time * (6 + st.fear * 10)) + i) % 4;
      const x = -0.78 + i * 0.26;
      disc(ctx, r, x, 0.04 - Math.abs(x) * 0.08, 0.07, colors[on]);
      disc(ctx, r, x - 0.02, 0.02 - Math.abs(x) * 0.08, 0.025, 'rgba(255,255,255,0.8)');
    }
    shine(ctx, r, -0.45, -0.15, 0.3, 0.05, 0.6, -0.1);
    sweat(ctx, r, 0.4, -0.6, st);
  },
};

// ---------- sprite pipeline ----------

function makeCanvas(size) {
  if (typeof document !== 'undefined' && document.createElement) {
    const c = document.createElement('canvas');
    if (c && c.getContext) {
      c.width = c.height = size;
      return c;
    }
  }
  if (typeof OffscreenCanvas !== 'undefined') return new OffscreenCanvas(size, size);
  return null;
}

const sprites = new WeakMap();

function spriteFor(o, size) {
  let s = sprites.get(o);
  if (!s || s.size < size || s.size > size * 1.6) {
    const sprite = makeCanvas(size);
    const sil = makeCanvas(size);
    if (!sprite || !sil) return null;
    s = { size, sprite, sil };
    sprites.set(o, s);
  }
  return s;
}

function drawBody(ctx, o, r, st) {
  if (o.landmark) drawLandmark(ctx, o.bossType, r, st.time);
  else BOSSES[o.bossType]?.(ctx, r, st);
}

function faceState(o, time) {
  const seed = (o.x * 7.13 + o.y * 3.7) % 5;
  const blink = (time + seed) % 3.4 < 0.13;
  return { time, blink, fear: o.fear || 0, lx: o.lookX || 0, ly: o.lookY || 0 };
}

// Rays + glow behind the boss; brighter and greener once the hole can eat it.
function drawAura(ctx, o, time) {
  const r = o.r;
  const ready = o.ready ? 1 : 0;
  const pulse = 0.8 + Math.sin(time * 3) * 0.2;
  const color = ready ? '120,255,160' : o.landmark ? '255,214,90' : '255,245,200';
  const g = ctx.createRadialGradient(0, 0, r * 0.3, 0, 0, r * 1.7);
  g.addColorStop(0, `rgba(${color},${(0.4 + ready * 0.2) * pulse})`);
  g.addColorStop(1, `rgba(${color},0)`);
  ctx.fillStyle = g;
  ctx.save();
  ctx.rotate(time * 0.25);
  ctx.beginPath();
  const rays = 12;
  for (let i = 0; i < rays; i++) {
    const a = (i / rays) * TAU;
    ctx.moveTo(0, 0);
    ctx.arc(0, 0, r * 1.7, a, a + TAU / rays / 2);
    ctx.closePath();
  }
  ctx.fill();
  ctx.restore();
  ctx.beginPath();
  ctx.arc(0, 0, r * 1.15, 0, TAU);
  ctx.fill();
}

function drawSparkles(ctx, o, time) {
  const r = o.r;
  ctx.fillStyle = o.landmark ? '#fff3b0' : '#ffffff';
  for (let i = 0; i < 6; i++) {
    const tw = Math.sin(time * 2.2 + i * 1.9);
    if (tw < 0.2) continue;
    const a = i * 1.05 + Math.floor((time * 2.2 + i * 1.9) / TAU) * 2.1;
    const d = r * (1.0 + (i % 3) * 0.12);
    star4(ctx, Math.cos(a) * d, Math.sin(a) * d * 0.9, r * 0.09 * tw);
  }
}

function drawAlarm(ctx, o, time) {
  if ((o.fear || 0) < 0.5) return;
  const r = o.r;
  const pop = Math.min(1, (o.fear - 0.5) * 4);
  const y = -r * 1.35 + Math.sin(time * 10) * r * 0.03;
  ctx.save();
  ctx.translate(r * 0.55, y);
  ctx.scale(pop, pop);
  ctx.fillStyle = '#fff';
  ctx.strokeStyle = OUTLINE;
  ctx.lineWidth = r * 0.03;
  ctx.beginPath();
  ctx.ellipse(0, 0, r * 0.2, r * 0.17, 0, 0, TAU);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#e63946';
  ctx.font = `bold ${r * 0.28}px Trebuchet MS, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('!', 0, r * 0.01);
  ctx.restore();
}

export function drawBoss(ctx, o, time) {
  const r = o.r;
  const st = faceState(o, time);
  const fear = st.fear;

  drawAura(ctx, o, time);
  const sg = ctx.createRadialGradient(0, r * 0.85, 0, 0, r * 0.85, r);
  sg.addColorStop(0, 'rgba(0,0,0,0.35)');
  sg.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = sg;
  ctx.beginPath();
  ctx.ellipse(0, r * 0.85, r, r * 0.3, 0, 0, TAU);
  ctx.fill();

  ctx.save();
  // Idle life: breathing, a gentle bob for creatures, trembling when scared.
  const breathe = Math.sin(time * 2.2) * 0.025;
  const bob = o.landmark ? 0 : Math.sin(time * 2) * r * 0.04 - r * 0.06;
  const shake = fear * r * 0.035;
  ctx.translate(Math.sin(time * 47) * shake, bob + Math.cos(time * 53) * shake * 0.6);
  if (o.landmark) ctx.rotate(Math.sin(time * 31) * fear * 0.025);
  ctx.translate(0, r * 0.9);
  ctx.scale(1 - breathe * 0.6, 1 + breathe);
  ctx.translate(0, -r * 0.9);

  const m = ctx.getTransform?.();
  const px = m ? Math.hypot(m.a, m.b) : 1;
  const R = Math.max(24, Math.min(300, r * px));
  const half = 1.45;
  const size = Math.ceil(R * half * 2 + 8);
  const s = spriteFor(o, size);
  if (!s) {
    drawBody(ctx, o, r, st);
  } else {
    const { sprite, sil } = s;
    const sc = sprite.getContext('2d');
    sc.setTransform(1, 0, 0, 1, 0, 0);
    sc.clearRect(0, 0, s.size, s.size);
    sc.translate(s.size / 2, s.size / 2);
    drawBody(sc, o, R, st);
    // Global light: warm top-left, cool shade bottom-right.
    sc.globalCompositeOperation = 'source-atop';
    const lg = sc.createLinearGradient(-R, -R, R, R);
    lg.addColorStop(0, 'rgba(255,250,230,0.22)');
    lg.addColorStop(0.5, 'rgba(255,255,255,0)');
    lg.addColorStop(1, 'rgba(30,20,60,0.25)');
    sc.fillStyle = lg;
    sc.fillRect(-s.size / 2, -s.size / 2, s.size, s.size);
    sc.globalCompositeOperation = 'source-over';

    const lc = sil.getContext('2d');
    lc.setTransform(1, 0, 0, 1, 0, 0);
    lc.clearRect(0, 0, s.size, s.size);
    lc.drawImage(sprite, 0, 0);
    lc.globalCompositeOperation = 'source-in';
    lc.fillStyle = OUTLINE;
    lc.fillRect(0, 0, s.size, s.size);
    lc.globalCompositeOperation = 'source-over';

    const k = r / R;
    ctx.scale(k, k);
    const w = Math.max(2, R * 0.045);
    const o0 = -s.size / 2;
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * TAU;
      ctx.drawImage(sil, o0 + Math.cos(a) * w, o0 + Math.sin(a) * w);
    }
    ctx.drawImage(sprite, o0, o0);
  }
  ctx.restore();

  drawSparkles(ctx, o, time);
  drawAlarm(ctx, o, time);
}
