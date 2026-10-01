// Extra structures and themed props. Drawn top-down like the rest of the city,
// centred on the object's position (the caller has already translated there).

// Sizes of themed props; objects with w/h get their radius from makeObj.
export const PROP_SIZES = {
  cafe: { r: 12 },
  lamp: { r: 4 },
  gelato: { w: 22, h: 12 },
  column: { r: 8 },
  amphora: { r: 6 },
  camel: { w: 26, h: 12, walker: true },
  palm: { r: 14 },
  obelisk: { r: 8 },
  phonebox: { w: 12, h: 12 },
  hotdog: { w: 22, h: 12 },
  torii: { w: 30, h: 8 },
  sakura: { r: 14 },
  lantern: { r: 5 },
  cyclo: { w: 22, h: 12 },
  sheep: { r: 7, walker: true },
  hay: { r: 9 },
  panda: { r: 9, walker: true },
  elephant: { w: 30, h: 18, walker: true },
  cactus: { r: 8 },
  minimoai: { r: 8 },
  llama: { r: 7, walker: true },
  pine: { r: 12 },
};

// Everything this file can draw, for the dev gallery.
export const PROP_KINDS = [
  ...Object.keys(PROP_SIZES),
  'windmill', 'ferris', 'carousel', 'gas', 'pump', 'pool', 'field',
];

function shadow(ctx, r, off = 3) {
  ctx.fillStyle = 'rgba(0,0,0,0.22)';
  ctx.beginPath();
  ctx.ellipse(off, off, r, r * 0.9, 0, 0, Math.PI * 2);
  ctx.fill();
}

function disc(ctx, x, y, r, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
}

function box(ctx, w, h, color, radius = 3) {
  ctx.fillStyle = 'rgba(0,0,0,0.22)';
  ctx.fillRect(-w / 2 + 3, -h / 2 + 3, w, h);
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.roundRect(-w / 2, -h / 2, w, h, radius);
  ctx.fill();
}

function flower(ctx, r, petals, color, center, spin = 0) {
  ctx.fillStyle = color;
  for (let i = 0; i < petals; i++) {
    const a = spin + (i / petals) * Math.PI * 2;
    ctx.beginPath();
    ctx.arc(Math.cos(a) * r * 0.5, Math.sin(a) * r * 0.5, r * 0.5, 0, Math.PI * 2);
    ctx.fill();
  }
  disc(ctx, 0, 0, r * 0.35, center);
}

// Four-legged animal seen from above, facing +x.
function animal(ctx, len, wid, body, head) {
  ctx.fillStyle = 'rgba(0,0,0,0.2)';
  ctx.beginPath();
  ctx.ellipse(2, 2, len / 2, wid / 2, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = shade(body, -40);
  for (const [lx, ly] of [[-0.3, -0.5], [-0.3, 0.5], [0.25, -0.5], [0.25, 0.5]]) {
    ctx.fillRect(lx * len - 1.5, ly * wid - 1.5, 3, 3);
  }
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.ellipse(0, 0, len * 0.4, wid * 0.42, 0, 0, Math.PI * 2);
  ctx.fill();
  disc(ctx, len * 0.42, 0, wid * 0.3, head);
}

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.max(0, Math.min(255, (n >> 16) + amt));
  const g = Math.max(0, Math.min(255, ((n >> 8) & 255) + amt));
  const b = Math.max(0, Math.min(255, (n & 255) + amt));
  return `rgb(${r},${g},${b})`;
}

const DRAW = {
  // --- themed small props ---
  cafe(ctx, o) {
    shadow(ctx, o.r);
    ctx.fillStyle = '#6d4c41';
    for (const a of [0, Math.PI / 2, Math.PI, -Math.PI / 2]) ctx.fillRect(Math.cos(a) * o.r * 0.8 - 2, Math.sin(a) * o.r * 0.8 - 2, 4, 4);
    for (let i = 0; i < 8; i++) {
      ctx.fillStyle = i % 2 ? '#ffffff' : '#e63946';
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.arc(0, 0, o.r * 0.75, (i / 8) * Math.PI * 2, ((i + 1) / 8) * Math.PI * 2);
      ctx.fill();
    }
  },
  lamp(ctx, o, time) {
    disc(ctx, 1, 1, o.r, 'rgba(0,0,0,0.25)');
    disc(ctx, 0, 0, o.r, '#2b2d42');
    disc(ctx, 0, 0, o.r * 0.55, `rgba(255,230,140,${0.75 + Math.sin(time * 3 + o.x) * 0.2})`);
  },
  gelato(ctx, o) {
    box(ctx, o.w, o.h, '#90e0ef');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(-o.w / 2, -o.h / 2, o.w, o.h * 0.3);
    disc(ctx, -o.w * 0.25, 0, 3, '#ffafcc');
    disc(ctx, 0, 0, 3, '#fff3b0');
    disc(ctx, o.w * 0.25, 0, 3, '#a7c957');
  },
  column(ctx, o) {
    shadow(ctx, o.r);
    disc(ctx, 0, 0, o.r, '#d6ccc2');
    ctx.strokeStyle = '#b8ab9c';
    ctx.lineWidth = 1;
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * o.r * 0.4, Math.sin(a) * o.r * 0.4);
      ctx.lineTo(Math.cos(a) * o.r, Math.sin(a) * o.r);
      ctx.stroke();
    }
    disc(ctx, 0, 0, o.r * 0.4, '#e8e0d5');
  },
  amphora(ctx, o) {
    shadow(ctx, o.r, 2);
    disc(ctx, 0, 0, o.r, '#c1502e');
    disc(ctx, 0, 0, o.r * 0.55, '#7f2f1a');
    ctx.strokeStyle = '#1b1b1b';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(0, 0, o.r * 0.8, 0, Math.PI * 2);
    ctx.stroke();
  },
  camel(ctx, o) {
    animal(ctx, o.w, o.h, '#c68b59', '#a9744f');
    disc(ctx, -o.w * 0.08, 0, o.h * 0.28, '#b07a4f');
  },
  palm(ctx, o, time) {
    shadow(ctx, o.r, 5);
    const sway = Math.sin(time * 1.5 + o.x) * 0.08;
    ctx.fillStyle = '#2d6a4f';
    for (let i = 0; i < 6; i++) {
      const a = sway + (i / 6) * Math.PI * 2;
      ctx.beginPath();
      ctx.ellipse(Math.cos(a) * o.r * 0.5, Math.sin(a) * o.r * 0.5 - 3, o.r * 0.55, o.r * 0.2, a, 0, Math.PI * 2);
      ctx.fill();
    }
    disc(ctx, 0, -3, o.r * 0.18, '#7f5539');
  },
  obelisk(ctx, o) {
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.fillRect(-o.r * 0.4, -o.r * 0.4, o.r * 2.2, o.r * 0.8);
    ctx.fillStyle = '#e0c088';
    ctx.fillRect(-o.r * 0.55, -o.r * 0.55, o.r * 1.1, o.r * 1.1);
    ctx.fillStyle = '#c9a66b';
    ctx.beginPath();
    ctx.moveTo(-o.r * 0.55, -o.r * 0.55);
    ctx.lineTo(0, 0);
    ctx.lineTo(o.r * 0.55, -o.r * 0.55);
    ctx.fill();
    ctx.fillStyle = '#f2d98d';
    ctx.fillRect(-o.r * 0.12, -o.r * 0.12, o.r * 0.24, o.r * 0.24);
  },
  phonebox(ctx, o) {
    box(ctx, o.w, o.h, '#d62828', 2);
    ctx.fillStyle = '#9d0208';
    ctx.fillRect(-o.w * 0.3, -o.h * 0.3, o.w * 0.6, o.h * 0.6);
    ctx.fillStyle = '#ffd166';
    ctx.fillRect(-o.w * 0.12, -o.h * 0.12, o.w * 0.24, o.h * 0.24);
  },
  hotdog(ctx, o) {
    box(ctx, o.w, o.h, '#adb5bd');
    for (let i = 0; i < 4; i++) {
      ctx.fillStyle = i % 2 ? '#ffffff' : '#1d6fd8';
      ctx.fillRect(-o.w / 2 + (i * o.w) / 4, -o.h / 2, o.w / 4, o.h * 0.45);
    }
    ctx.fillStyle = '#e76f51';
    ctx.beginPath();
    ctx.roundRect(-o.w * 0.25, o.h * 0.08, o.w * 0.5, o.h * 0.22, 3);
    ctx.fill();
  },
  torii(ctx, o) {
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.fillRect(-o.w / 2 + 3, -o.h / 2 + 3, o.w, o.h);
    ctx.fillStyle = '#d62828';
    ctx.fillRect(-o.w / 2, -o.h / 2, o.w, o.h * 0.45);
    ctx.fillStyle = '#1b1b1b';
    ctx.fillRect(-o.w / 2 - 2, -o.h / 2 - 1, o.w + 4, o.h * 0.2);
    ctx.fillStyle = '#b71c1c';
    ctx.fillRect(-o.w * 0.35 - 2, -o.h / 2, 4, o.h);
    ctx.fillRect(o.w * 0.35 - 2, -o.h / 2, 4, o.h);
  },
  sakura(ctx, o, time) {
    shadow(ctx, o.r, 4);
    disc(ctx, 0, -4, o.r, '#ffafcc');
    disc(ctx, -o.r * 0.25, -4 - o.r * 0.25, o.r * 0.6, '#ffc8dd');
    ctx.fillStyle = '#ffffff';
    for (let i = 0; i < 4; i++) {
      const a = time * 0.6 + i * 1.7 + o.x;
      ctx.fillRect(Math.cos(a) * o.r * 0.7, -4 + Math.sin(a * 1.3) * o.r * 0.7, 2, 2);
    }
  },
  lantern(ctx, o, time) {
    disc(ctx, 0, 0, o.r * 1.6, `rgba(255,120,60,${0.18 + Math.sin(time * 4 + o.y) * 0.08})`);
    disc(ctx, 0, 0, o.r, '#e63946');
    ctx.fillStyle = '#ffd166';
    ctx.fillRect(-o.r * 0.9, -1, o.r * 1.8, 2);
  },
  cyclo(ctx, o) {
    ctx.fillStyle = 'rgba(0,0,0,0.22)';
    ctx.fillRect(-o.w / 2 + 2, -o.h / 2 + 2, o.w, o.h);
    ctx.fillStyle = '#1b1b1b';
    disc(ctx, -o.w * 0.2, -o.h / 2, 2.5, '#1b1b1b');
    disc(ctx, -o.w * 0.2, o.h / 2, 2.5, '#1b1b1b');
    disc(ctx, o.w * 0.42, 0, 2.5, '#1b1b1b');
    ctx.fillStyle = '#2a9d8f';
    ctx.beginPath();
    ctx.roundRect(-o.w / 2, -o.h * 0.4, o.w * 0.5, o.h * 0.8, 4);
    ctx.fill();
    ctx.fillStyle = '#6c757d';
    ctx.fillRect(0, -1, o.w * 0.42, 2);
    disc(ctx, o.w * 0.2, 0, 3, '#ffd6a5');
  },
  sheep(ctx, o) {
    shadow(ctx, o.r, 2);
    flower(ctx, o.r, 6, '#f8f9fa', '#e9ecef');
    disc(ctx, o.r * 0.85, 0, o.r * 0.38, '#343a40');
  },
  hay(ctx, o) {
    shadow(ctx, o.r);
    disc(ctx, 0, 0, o.r, '#e9c46a');
    ctx.strokeStyle = '#c9a227';
    ctx.lineWidth = 1.5;
    for (const k of [0.35, 0.7]) {
      ctx.beginPath();
      ctx.arc(0, 0, o.r * k, 0, Math.PI * 2);
      ctx.stroke();
    }
  },
  panda(ctx, o) {
    shadow(ctx, o.r, 2);
    disc(ctx, 0, 0, o.r, '#f8f9fa');
    disc(ctx, -o.r * 0.1, 0, o.r * 0.55, '#212529');
    disc(ctx, o.r * 0.55, 0, o.r * 0.5, '#f8f9fa');
    disc(ctx, o.r * 0.6, -o.r * 0.42, o.r * 0.2, '#212529');
    disc(ctx, o.r * 0.6, o.r * 0.42, o.r * 0.2, '#212529');
  },
  elephant(ctx, o) {
    animal(ctx, o.w, o.h, '#adb5bd', '#9ca3ab');
    ctx.fillStyle = '#8d949c';
    ctx.beginPath();
    ctx.ellipse(o.w * 0.36, -o.h * 0.32, o.h * 0.2, o.h * 0.3, 0.3, 0, Math.PI * 2);
    ctx.ellipse(o.w * 0.36, o.h * 0.32, o.h * 0.2, o.h * 0.3, -0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#e63946';
    ctx.fillRect(-o.w * 0.15, -o.h * 0.3, o.w * 0.25, o.h * 0.6);
  },
  cactus(ctx, o) {
    shadow(ctx, o.r, 2);
    disc(ctx, 0, 0, o.r * 0.6, '#52b788');
    disc(ctx, -o.r * 0.6, -o.r * 0.1, o.r * 0.35, '#40916c');
    disc(ctx, o.r * 0.6, o.r * 0.1, o.r * 0.35, '#40916c');
    disc(ctx, 0, 0, o.r * 0.22, '#ff8fab');
  },
  minimoai(ctx, o) {
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.fillRect(-o.r * 0.3, -o.r * 0.3, o.r * 1.6, o.r * 1.2);
    ctx.fillStyle = '#6c757d';
    ctx.beginPath();
    ctx.roundRect(-o.r * 0.6, -o.r * 0.9, o.r * 1.2, o.r * 1.6, 3);
    ctx.fill();
    ctx.fillStyle = '#495057';
    ctx.fillRect(-o.r * 0.6, -o.r * 0.9, o.r * 1.2, o.r * 0.35);
    ctx.fillRect(-o.r * 0.12, -o.r * 0.5, o.r * 0.24, o.r * 0.7);
  },
  llama(ctx, o) {
    animal(ctx, o.r * 2.4, o.r * 1.4, '#f1e3d3', '#e0cdb8');
    disc(ctx, 0, 0, o.r * 0.35, '#e07a5f');
  },
  pine(ctx, o) {
    shadow(ctx, o.r, 4);
    for (const [k, c] of [[1, '#1b4332'], [0.68, '#2d6a4f'], [0.36, '#40916c']]) {
      ctx.fillStyle = c;
      ctx.beginPath();
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        const rr = o.r * k * (i % 2 ? 0.7 : 1);
        ctx.lineTo(Math.cos(a) * rr, Math.sin(a) * rr - 4);
      }
      ctx.fill();
    }
  },

  // --- big structures for special city blocks ---
  windmill(ctx, o, time) {
    shadow(ctx, o.r * 0.6, 5);
    disc(ctx, 0, 0, o.r * 0.5, '#f1faee');
    disc(ctx, 0, 0, o.r * 0.34, '#bc4749');
    ctx.save();
    ctx.rotate(time * 1.2 + o.x);
    for (let i = 0; i < 4; i++) {
      ctx.rotate(Math.PI / 2);
      ctx.fillStyle = '#6d4c41';
      ctx.fillRect(-1.5, 0, 3, o.r);
      ctx.fillStyle = 'rgba(241,250,238,0.9)';
      ctx.fillRect(1.5, o.r * 0.25, o.r * 0.22, o.r * 0.75);
    }
    ctx.restore();
    disc(ctx, 0, 0, o.r * 0.1, '#343a40');
  },
  ferris(ctx, o, time) {
    ctx.fillStyle = 'rgba(0,0,0,0.2)';
    ctx.beginPath();
    ctx.ellipse(8, 8, o.r, o.r * 0.9, 0, 0, Math.PI * 2);
    ctx.fill();
    const spin = time * 0.35;
    ctx.strokeStyle = '#ced4da';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.arc(0, 0, o.r * 0.85, 0, Math.PI * 2);
    ctx.stroke();
    ctx.lineWidth = 2;
    const colors = ['#ff595e', '#ffca3a', '#8ac926', '#1982c4', '#6a4c93', '#f15bb5'];
    for (let i = 0; i < 12; i++) {
      const a = spin + (i / 12) * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(Math.cos(a) * o.r * 0.85, Math.sin(a) * o.r * 0.85);
      ctx.stroke();
    }
    for (let i = 0; i < 12; i++) {
      const a = spin + (i / 12) * Math.PI * 2;
      disc(ctx, Math.cos(a) * o.r * 0.85, Math.sin(a) * o.r * 0.85, o.r * 0.1, colors[i % colors.length]);
    }
    disc(ctx, 0, 0, o.r * 0.14, '#495057');
  },
  carousel(ctx, o, time) {
    shadow(ctx, o.r, 5);
    const spin = time * 0.8;
    for (let i = 0; i < 10; i++) {
      ctx.fillStyle = i % 2 ? '#ffffff' : '#f15bb5';
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.arc(0, 0, o.r, spin + (i / 10) * Math.PI * 2, spin + ((i + 1) / 10) * Math.PI * 2);
      ctx.fill();
    }
    disc(ctx, 0, 0, o.r * 0.18, '#ffd166');
  },
  gas(ctx, o) {
    box(ctx, o.w, o.h, '#f8f9fa', 4);
    ctx.fillStyle = '#e63946';
    ctx.fillRect(-o.w / 2, -o.h / 2, o.w, o.h * 0.14);
    ctx.fillStyle = '#dee2e6';
    for (let i = 0; i < 3; i++) ctx.fillRect(-o.w * 0.38 + i * o.w * 0.28, -o.h * 0.1, o.w * 0.2, o.h * 0.45);
  },
  pump(ctx, o) {
    box(ctx, o.r * 1.4, o.r * 1.8, '#2a9d8f', 2);
    ctx.fillStyle = '#e9f5db';
    ctx.fillRect(-o.r * 0.45, -o.r * 0.6, o.r * 0.9, o.r * 0.5);
  },
  pool(ctx, o, time) {
    ctx.fillStyle = 'rgba(0,0,0,0.15)';
    ctx.fillRect(-o.w / 2 - 6, -o.h / 2 - 6, o.w + 12, o.h + 12);
    ctx.fillStyle = '#f1faee';
    ctx.fillRect(-o.w / 2 - 4, -o.h / 2 - 4, o.w + 8, o.h + 8);
    ctx.fillStyle = '#48cae4';
    ctx.fillRect(-o.w / 2, -o.h / 2, o.w, o.h);
    ctx.strokeStyle = 'rgba(255,255,255,0.7)';
    ctx.lineWidth = 2;
    for (let i = 1; i < 4; i++) {
      const y = -o.h / 2 + (i * o.h) / 4;
      ctx.beginPath();
      for (let x = -o.w / 2; x <= o.w / 2; x += 8) ctx.lineTo(x, y + Math.sin(time * 3 + x * 0.1) * 1.5);
      ctx.stroke();
    }
  },
  field(ctx, o) {
    ctx.fillStyle = 'rgba(0,0,0,0.12)';
    ctx.fillRect(-o.w / 2 + 4, -o.h / 2 + 4, o.w, o.h);
    const stripes = 8;
    for (let i = 0; i < stripes; i++) {
      ctx.fillStyle = i % 2 ? '#52b788' : '#40916c';
      ctx.fillRect(-o.w / 2 + (i * o.w) / stripes, -o.h / 2, o.w / stripes + 0.5, o.h);
    }
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 2;
    ctx.strokeRect(-o.w / 2 + 4, -o.h / 2 + 4, o.w - 8, o.h - 8);
    ctx.beginPath();
    ctx.moveTo(0, -o.h / 2 + 4);
    ctx.lineTo(0, o.h / 2 - 4);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(0, 0, o.h * 0.16, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeRect(-o.w / 2 + 4, -o.h * 0.22, o.w * 0.1, o.h * 0.44);
    ctx.strokeRect(o.w / 2 - 4 - o.w * 0.1, -o.h * 0.22, o.w * 0.1, o.h * 0.44);
  },
};

// Returns false for kinds this module does not know.
export function drawProp(ctx, o, time) {
  const draw = DRAW[o.kind];
  if (!draw) return false;
  if (o.angle) ctx.rotate(o.angle);
  draw(ctx, o, time);
  return true;
}
