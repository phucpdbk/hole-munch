const TAU = Math.PI * 2;
const MAX_PARTICLES = 450;

export const SKINS = [
  { id: 'classic', price: 0 },
  { id: 'candy', price: 300 },
  { id: 'slime', price: 500 },
  { id: 'fire', price: 800 },
  { id: 'galaxy', price: 1200 },
  { id: 'neon', price: 1500 },
  { id: 'xmas', price: 2000 },
  { id: 'gold', price: 5000 },
  { id: 'comet', price: null, rewardOnly: true },
  { id: 'atlas', price: null, rewardOnly: true },
  { id: 'crown', price: null, rewardOnly: true },
];

export const EAT_FX = [
  { id: 'dust', icon: '💨', price: 0 },
  { id: 'confetti', icon: '🎉', price: 200 },
  { id: 'hearts', icon: '💖', price: 300 },
  { id: 'stars', icon: '⭐', price: 400 },
  { id: 'coins', icon: '🪙', price: 600 },
  { id: 'pixels', icon: '🟪', price: 800 },
  { id: 'snow', icon: '❄️', price: 1000 },
];

export const TRAILS = [
  { id: 'none', icon: '∅', price: 0 },
  { id: 'bubbles', icon: '🫧', price: 250 },
  { id: 'sparkle', icon: '✨', price: 400 },
  { id: 'snow', icon: '🌨️', price: 600 },
  { id: 'fire', icon: '🔥', price: 800 },
  { id: 'rainbow', icon: '🌈', price: 1200 },
];

export const COSMETIC_SLOTS = {
  skin: { list: SKINS, label: 'tabSkins', prefix: 'skin_' },
  fx: { list: EAT_FX, label: 'tabFx', prefix: 'fx_' },
  trail: { list: TRAILS, label: 'tabTrails', prefix: 'trail_' },
};

// ---------- Hole skins ----------

function fillHole(ctx, x, y, r, stops) {
  const g = ctx.createRadialGradient(x, y, r * 0.2, x, y, r);
  for (const [o, c] of stops) g.addColorStop(o, c);
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, TAU);
  ctx.fill();
}

function ring(ctx, x, y, r, width, color, glow) {
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  if (glow) {
    ctx.shadowColor = glow;
    ctx.shadowBlur = 18;
  }
  ctx.beginPath();
  ctx.arc(x, y, r, 0, TAU);
  ctx.stroke();
  ctx.shadowBlur = 0;
}

// Deterministic pseudo-random so star fields don't flicker between frames.
function hash(i) {
  const s = Math.sin(i * 127.1 + 311.7) * 43758.5453;
  return s - Math.floor(s);
}

const INSIDE = {
  comet: [[0, '#050d23'], [0.65, '#123246'], [1, '#6651a9']],
  atlas: [[0, '#031e29'], [0.7, '#10575a'], [1, '#27857d']],
  crown: [[0, '#110820'], [0.75, '#39223c'], [1, '#8d6533']],
  classic: [[0, '#000'], [0.75, '#0b0616'], [1, '#2a1650']],
  candy: [[0, '#000'], [0.8, '#1a0410'], [1, '#4d0f2a']],
  slime: [[0, '#000'], [0.8, '#0a1f00'], [1, '#1f4d00']],
  fire: [[0, '#000'], [0.7, '#1a0500'], [1, '#5a1600']],
  galaxy: [[0, '#000010'], [0.6, '#1a0b3d'], [1, '#3c1a78']],
  neon: [[0, '#000'], [0.8, '#0a0020'], [1, '#1d0045']],
  xmas: [[0, '#000'], [0.8, '#06140c'], [1, '#123d22']],
  gold: [[0, '#000'], [0.85, '#1a1400'], [1, '#4d3b00']],
};

export function drawSkinInside(ctx, id, x, y, r, time) {
  fillHole(ctx, x, y, r, INSIDE[id] || INSIDE.classic);
  if (id === 'atlas') {
    ctx.save();ctx.strokeStyle='rgba(146,245,216,0.3)';ctx.lineWidth=Math.max(1,r*0.02);
    for(const s of [0.35,0.7]) {ctx.beginPath();ctx.ellipse(x,y,r*s,r*0.85,0,0,TAU);ctx.stroke();ctx.beginPath();ctx.ellipse(x,y,r*0.85,r*s,0,0,TAU);ctx.stroke();}
    ctx.restore();
  }
  if (id === 'galaxy') {
    for (let i = 0; i < 26; i++) {
      const a = hash(i) * TAU + time * 0.15;
      const d = Math.sqrt(hash(i + 50)) * r * 0.85;
      ctx.globalAlpha = 0.4 + 0.6 * Math.abs(Math.sin(time * 2 + i));
      ctx.fillStyle = i % 5 === 0 ? '#ffd6ff' : '#fff';
      ctx.beginPath();
      ctx.arc(x + Math.cos(a) * d, y + Math.sin(a) * d, Math.max(1, r * 0.018 * (1 + hash(i + 9))), 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }
}

export function drawSkinRim(ctx, id, x, y, r, time, pulse) {
  const w = Math.max(3, r * 0.08);
  switch (id) {
    case 'comet':
      ring(ctx,x,y,r,w,'#97f6ee','#56e0da');
      for(let i=0;i<14;i++) {
        const a=time*1.4-i*0.08;ctx.fillStyle=`rgba(244,219,255,${1-i/15})`;
        ctx.beginPath();ctx.arc(x+Math.cos(a)*r,y+Math.sin(a)*r,w*(1-i/17),0,TAU);ctx.fill();
      }
      break;
    case 'atlas':
      ring(ctx,x,y,r,w,'#dfd19a');
      ctx.fillStyle='#b1ffe1';
      for(let i=0;i<4;i++) {const a=i*TAU/4;ctx.beginPath();ctx.moveTo(x+Math.cos(a)*(r+w*2.4),y+Math.sin(a)*(r+w*2.4));ctx.lineTo(x+Math.cos(a-0.09)*r,y+Math.sin(a-0.09)*r);ctx.lineTo(x+Math.cos(a+0.09)*r,y+Math.sin(a+0.09)*r);ctx.fill();}
      break;
    case 'crown':
      ring(ctx,x,y,r,w*1.6,'#ffc867','#ffb331');
      for(let i=0;i<8;i++) {const a=i*TAU/8+time*0.15;ctx.fillStyle=i%2?'#ff7cac':'#7ff7e9';ctx.beginPath();ctx.arc(x+Math.cos(a)*r,y+Math.sin(a)*r,w*0.6,0,TAU);ctx.fill();}
      break;
    case 'candy': {
      const n = 16;
      ctx.lineWidth = w * 1.4;
      for (let i = 0; i < n; i++) {
        const a0 = (i / n) * TAU + time * 0.8;
        ctx.strokeStyle = i % 2 ? '#fff' : '#ff4d6d';
        ctx.beginPath();
        ctx.arc(x, y, r, a0, a0 + TAU / n + 0.01);
        ctx.stroke();
      }
      break;
    }
    case 'slime': {
      ring(ctx, x, y, r, w * 1.2, '#7cff00', '#7cff00');
      ctx.fillStyle = '#7cff00';
      for (let i = 0; i < 10; i++) {
        const a = (i / 10) * TAU + Math.sin(time + i) * 0.1;
        const br = r * (0.05 + 0.03 * Math.sin(time * 3 + i * 2));
        ctx.beginPath();
        ctx.arc(x + Math.cos(a) * r, y + Math.sin(a) * r + br * 0.8, br, 0, TAU);
        ctx.fill();
      }
      break;
    }
    case 'fire': {
      const n = 26;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * TAU;
        const len = r * (0.14 + 0.08 * Math.sin(time * 9 + i * 1.7));
        const half = (TAU / n) * 0.6;
        const g = ctx.createLinearGradient(
          x + Math.cos(a) * r, y + Math.sin(a) * r,
          x + Math.cos(a) * (r + len), y + Math.sin(a) * (r + len)
        );
        g.addColorStop(0, '#ff3d00');
        g.addColorStop(1, 'rgba(255,214,0,0)');
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.moveTo(x + Math.cos(a - half) * r, y + Math.sin(a - half) * r);
        ctx.lineTo(x + Math.cos(a) * (r + len), y + Math.sin(a) * (r + len));
        ctx.lineTo(x + Math.cos(a + half) * r, y + Math.sin(a + half) * r);
        ctx.fill();
      }
      ring(ctx, x, y, r, w, '#ff6d00', '#ff9100');
      break;
    }
    case 'galaxy':
      ring(ctx, x, y, r, w, '#7df9ff', '#7df9ff');
      break;
    case 'neon': {
      const n = 36;
      ctx.lineWidth = w * 1.2;
      for (let i = 0; i < n; i++) {
        const a0 = (i / n) * TAU;
        const hue = (i * 10 + time * 140) % 360;
        ctx.strokeStyle = `hsl(${hue},100%,60%)`;
        ctx.shadowColor = ctx.strokeStyle;
        ctx.shadowBlur = 12;
        ctx.beginPath();
        ctx.arc(x, y, r, a0, a0 + TAU / n + 0.02);
        ctx.stroke();
      }
      ctx.shadowBlur = 0;
      break;
    }
    case 'xmas': {
      ring(ctx, x, y, r, w * 1.6, '#1b5e20');
      const n = Math.max(14, Math.round(r / 3));
      const leaf = Math.max(2.5, r * 0.085);
      for (let i = 0; i < n; i++) {
        const a = (i / n) * TAU;
        const off = (i % 2 ? 1 : -1) * leaf * 0.35;
        ctx.fillStyle = i % 2 ? '#2e7d32' : '#388e3c';
        ctx.beginPath();
        ctx.arc(x + Math.cos(a) * (r + off), y + Math.sin(a) * (r + off), leaf, 0, TAU);
        ctx.fill();
      }
      for (let i = 0; i < n; i += 3) {
        const a = (i / n) * TAU + 0.12;
        const bx = x + Math.cos(a) * r;
        const by = y + Math.sin(a) * r;
        const br = Math.max(2, r * 0.055);
        ctx.fillStyle = (i / 3) % 2 ? '#ffd54f' : '#e53935';
        ctx.beginPath();
        ctx.arc(bx, by, br, 0, TAU);
        ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.7)';
        ctx.beginPath();
        ctx.arc(bx - br * 0.3, by - br * 0.3, br * 0.35, 0, TAU);
        ctx.fill();
      }
      // Bow at the bottom of the wreath
      const bx = x;
      const by = y + r;
      const s = Math.max(4, r * 0.16);
      ctx.fillStyle = '#d32f2f';
      ctx.beginPath();
      ctx.moveTo(bx, by);
      ctx.lineTo(bx - s * 1.3, by - s * 0.7);
      ctx.lineTo(bx - s * 1.3, by + s * 0.7);
      ctx.closePath();
      ctx.moveTo(bx, by);
      ctx.lineTo(bx + s * 1.3, by - s * 0.7);
      ctx.lineTo(bx + s * 1.3, by + s * 0.7);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = '#b71c1c';
      ctx.beginPath();
      ctx.arc(bx, by, s * 0.4, 0, TAU);
      ctx.fill();
      for (let i = 0; i < 5; i++) {
        const a = hash(i + Math.floor(time * 2)) * TAU;
        ctx.globalAlpha = 0.8;
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.arc(x + Math.cos(a) * r * 1.08, y + Math.sin(a) * r * 1.08, Math.max(1.2, r * 0.02), 0, TAU);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
      break;
    }
    case 'gold': {
      const g = ctx.createLinearGradient(x - r, y - r, x + r, y + r);
      g.addColorStop(0, '#fff3b0');
      g.addColorStop(0.5, '#d4a017');
      g.addColorStop(1, '#8a6d00');
      ring(ctx, x, y, r, w * 1.5, g, '#ffd23f');
      const a = time * 1.5;
      ctx.strokeStyle = 'rgba(255,255,255,0.9)';
      ctx.lineWidth = w * 0.6;
      ctx.beginPath();
      ctx.arc(x, y, r, a, a + 0.5);
      ctx.stroke();
      break;
    }
    default:
      ring(ctx, x, y, r, w, pulse > 0 ? '#ffd23f' : '#8f5bff', '#8f5bff');
  }
}

// ---------- Particles ----------

function push(list, p) {
  if (list.length >= MAX_PARTICLES) list.shift();
  list.push({ rot: 0, vr: 0, g: 0, alpha: 1, ...p, t: 0 });
}

const rnd = (a, b) => a + Math.random() * (b - a);

export function emitEatFx(list, id, x, y, objR, holeR, color) {
  const n = Math.min(10, 3 + Math.floor(objR / 6));
  const s = holeR * 0.07 + objR * 0.15;
  const sp = holeR * 2.2;
  for (let i = 0; i < n; i++) {
    const a = rnd(0, TAU);
    const v = rnd(0.4, 1) * sp;
    const base = { x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: rnd(0.5, 0.9), size: s * rnd(0.6, 1.2), layer: 1 };
    switch (id) {
      case 'confetti':
        push(list, { ...base, shape: 'rect', color: `hsl(${rnd(0, 360)},90%,60%)`, vy: base.vy - sp, g: sp * 3, vr: rnd(-10, 10) });
        break;
      case 'hearts':
        push(list, { ...base, shape: 'heart', color: i % 2 ? '#ff4d8d' : '#ff8fab', vx: base.vx * 0.4, vy: -rnd(0.5, 1) * sp, life: 1.1 });
        break;
      case 'stars':
        push(list, { ...base, shape: 'star', color: i % 3 ? '#ffd23f' : '#fff', vr: rnd(-6, 6) });
        break;
      case 'coins':
        push(list, { ...base, shape: 'coin', color: '#ffc300', vy: -rnd(1, 1.6) * sp, g: sp * 4, vr: rnd(-4, 4) });
        break;
      case 'pixels':
        push(list, { ...base, shape: 'rect', color: color || '#9b5de5', g: sp * 2 });
        break;
      case 'snow':
        push(list, { ...base, shape: 'flake', color: '#fff', vx: base.vx * 0.5, vy: base.vy * 0.5, life: 1.2, vr: rnd(-2, 2) });
        break;
      default:
        push(list, { ...base, shape: 'circle', color: 'rgba(200,200,210,0.8)', vx: base.vx * 0.5, vy: base.vy * 0.5, life: 0.5 });
    }
  }
}

export function emitTrail(list, id, x, y, r, time) {
  if (id === 'none') return;
  const a = rnd(0, TAU);
  const d = r * rnd(0.85, 1.05);
  const px = x + Math.cos(a) * d;
  const py = y + Math.sin(a) * d;
  const s = r * 0.1;
  switch (id) {
    case 'bubbles':
      push(list, { x: px, y: py, vx: 0, vy: -r * 0.3, life: 1, size: s * rnd(0.6, 1.3), shape: 'ring', color: '#a0e7ff', layer: 0 });
      break;
    case 'sparkle':
      push(list, { x: px, y: py, vx: 0, vy: 0, life: 0.7, size: s * rnd(0.5, 1), shape: 'star', color: Math.random() < 0.5 ? '#fff' : '#ffd23f', vr: 4, layer: 0 });
      break;
    case 'snow':
      push(list, { x: px, y: py, vx: rnd(-5, 5), vy: r * 0.4, life: 1.3, size: s * rnd(0.4, 0.8), shape: 'circle', color: '#fff', layer: 0 });
      break;
    case 'fire':
      push(list, { x: px, y: py, vx: 0, vy: -r * 0.5, life: 0.6, size: s * rnd(0.8, 1.4), shape: 'circle', color: `hsl(${rnd(10, 45)},100%,55%)`, grow: 1.5, layer: 0 });
      break;
    case 'rainbow':
      push(list, { x: px, y: py, vx: 0, vy: 0, life: 0.9, size: s * 1.1, shape: 'circle', color: `hsl(${(time * 200) % 360},100%,60%)`, layer: 0 });
      break;
  }
}

export function updateParticles(list, dt) {
  let w = 0;
  for (let i = 0; i < list.length; i++) {
    const p = list[i];
    p.t += dt;
    if (p.t >= p.life) continue;
    p.vy += p.g * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.rot += p.vr * dt;
    list[w++] = p;
  }
  list.length = w;
}

function starPath(ctx, s) {
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const rr = i % 2 ? s * 0.45 : s;
    const a = (i / 10) * TAU - Math.PI / 2;
    ctx.lineTo(Math.cos(a) * rr, Math.sin(a) * rr);
  }
  ctx.closePath();
}

function heartPath(ctx, s) {
  ctx.beginPath();
  ctx.moveTo(0, s * 0.35);
  ctx.bezierCurveTo(s * 1.1, -s * 0.4, s * 0.5, -s * 1.1, 0, -s * 0.45);
  ctx.bezierCurveTo(-s * 0.5, -s * 1.1, -s * 1.1, -s * 0.4, 0, s * 0.35);
  ctx.closePath();
}

export function drawParticles(ctx, list, layer) {
  for (const p of list) {
    if (p.layer !== layer) continue;
    const k = p.t / p.life;
    const s = p.size * (p.grow ? 1 + k * p.grow : 1);
    ctx.save();
    ctx.globalAlpha = 1 - k;
    ctx.translate(p.x, p.y);
    ctx.rotate(p.rot);
    ctx.fillStyle = p.color;
    switch (p.shape) {
      case 'rect':
        ctx.fillRect(-s / 2, -s / 3, s, s * 0.66);
        break;
      case 'heart':
        heartPath(ctx, s);
        ctx.fill();
        break;
      case 'star':
        starPath(ctx, s);
        ctx.fill();
        break;
      case 'coin':
        ctx.beginPath();
        ctx.ellipse(0, 0, s * Math.abs(Math.cos(p.rot * 2)) + s * 0.15, s, 0, 0, TAU);
        ctx.fill();
        ctx.strokeStyle = '#b8860b';
        ctx.lineWidth = s * 0.2;
        ctx.stroke();
        break;
      case 'flake':
        ctx.strokeStyle = p.color;
        ctx.lineWidth = Math.max(1, s * 0.18);
        ctx.beginPath();
        for (let i = 0; i < 3; i++) {
          const a = (i / 3) * Math.PI;
          ctx.moveTo(Math.cos(a) * s, Math.sin(a) * s);
          ctx.lineTo(-Math.cos(a) * s, -Math.sin(a) * s);
        }
        ctx.stroke();
        break;
      case 'ring':
        ctx.strokeStyle = p.color;
        ctx.lineWidth = Math.max(1, s * 0.2);
        ctx.beginPath();
        ctx.arc(0, 0, s, 0, TAU);
        ctx.stroke();
        break;
      default:
        ctx.beginPath();
        ctx.arc(0, 0, s, 0, TAU);
        ctx.fill();
    }
    ctx.restore();
  }
}
