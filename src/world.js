import { BASE_START_R } from './upgrades.js';
import { drawBoss } from './bosses.js';
import { PROP_SIZES, drawProp } from './props.js';

const BLOCK = 320;
const ROAD = 70;
// A hole swallows objects up to this fraction of its own radius.
export const EAT_RATIO = 0.85;
const MIN_BOSS_R = 26;

const PEOPLE_COLORS = ['#ff595e', '#ffca3a', '#8ac926', '#1982c4', '#6a4c93', '#ff924c', '#f15bb5'];
const CAR_COLORS = ['#e63946', '#f1faee', '#457b9d', '#ffb703', '#8338ec', '#06d6a0', '#fb8500'];

function rand(a, b) {
  return a + Math.random() * (b - a);
}
function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function makeObj(kind, x, y, extra = {}) {
  const o = { kind, x, y, angle: 0, vx: 0, vy: 0, eaten: false, falling: false, fallT: 0, ...extra };
  if (o.w && o.h) o.r = Math.hypot(o.w, o.h) * 0.36;
  o.pts = Math.max(1, Math.round((o.r * o.r) / 12));
  return o;
}

// Rarer blocks built around one big attraction: fun fair, gas station, sports ground, farm.
function addSpecialBlock(add, x0, y0, type, theme) {
  const person = (x, y) => add('person', x, y, { r: 6, color: pick(PEOPLE_COLORS), walker: true });
  if (type < 0.25) {
    add('ferris', x0 + 105, y0 + 105, { r: 58 });
    add('carousel', x0 + 232, y0 + 225, { r: 32 });
    for (let i = 0; i < 8; i++) person(rand(x0 + 40, x0 + 170), rand(y0 + 190, y0 + 285));
    add('tree', x0 + 250, y0 + 70, { r: 16 });
    add('tree', x0 + 280, y0 + 120, { r: 13 });
  } else if (type < 0.5) {
    add('gas', x0 + 160, y0 + 100, { w: 130, h: 80 });
    for (let i = 0; i < 4; i++) add('pump', x0 + 110 + i * 33, y0 + 170, { r: 6 });
    add('house', x0 + 245, y0 + 245, { w: 75, h: 55, height: 16, color: pick(theme.roofs) });
    for (let i = 0; i < 2; i++) {
      add('car', x0 + 70 + i * 60, y0 + 245, { w: 30, h: 16, color: pick(theme.carColors || CAR_COLORS), angle: Math.PI / 2 });
    }
  } else if (type < 0.75) {
    add('field', x0 + 160, y0 + 100, { w: 220, h: 130 });
    add('pool', x0 + 105, y0 + 235, { w: 110, h: 60 });
    for (let i = 0; i < 3; i++) add('bench', x0 + 220 + i * 30, y0 + 215, { w: 22, h: 9, angle: Math.PI / 2 });
    for (let i = 0; i < 5; i++) person(rand(x0 + 200, x0 + 290), rand(y0 + 240, y0 + 290));
  } else {
    add('windmill', x0 + 95, y0 + 95, { r: 30 });
    add('windmill', x0 + 225, y0 + 215, { r: 30 });
    for (let i = 0; i < 4; i++) add('hay', rand(x0 + 170, x0 + 290), rand(y0 + 40, y0 + 130), { r: 9 });
    for (let i = 0; i < 5; i++) add('sheep', rand(x0 + 40, x0 + 150), rand(y0 + 180, y0 + 290), { r: 7, walker: true });
  }
}

export function generateWorld(level) {
  const n = level.blocks;
  const size = n * (BLOCK + ROAD) + ROAD;
  const theme = level.theme;
  const objects = [];
  const center = Math.floor(n / 2);
  const d = level.density;

  const add = (kind, x, y, extra) => {
    const o = makeObj(kind, x, y, extra);
    objects.push(o);
    return o;
  };
  const addThemeProp = (x, y, angle = 0) => {
    const kind = pick(theme.props);
    add(kind, x, y, { ...PROP_SIZES[kind], angle });
  };
  const themed = () => theme.props && Math.random() < 0.3;

  for (let bx = 0; bx < n; bx++) {
    for (let by = 0; by < n; by++) {
      const x0 = ROAD + bx * (BLOCK + ROAD);
      const y0 = ROAD + by * (BLOCK + ROAD);

      if (bx === center && by === center) {
        for (let i = 0; i < 14 * d; i++) {
          const a = (i / 14) * Math.PI * 2;
          add('person', x0 + BLOCK / 2 + Math.cos(a) * 130, y0 + BLOCK / 2 + Math.sin(a) * 130, {
            r: 6,
            color: pick(PEOPLE_COLORS),
          });
        }
        continue;
      }

      // Sidewalk props along the block edge.
      const edge = 12;
      for (let s = 20; s < BLOCK - 10; s += rand(38, 60) / d) {
        const side = Math.floor(Math.random() * 4);
        const px = side === 0 ? x0 + s : side === 1 ? x0 + s : side === 2 ? x0 + edge : x0 + BLOCK - edge;
        const py = side === 0 ? y0 + edge : side === 1 ? y0 + BLOCK - edge : y0 + s;
        const roll = Math.random();
        if (themed()) addThemeProp(px, py, side < 2 ? 0 : Math.PI / 2);
        else if (roll < 0.35) add('person', px, py, { r: 6, color: pick(PEOPLE_COLORS), walker: true });
        else if (roll < 0.55) add('tree', px, py, { r: rand(11, 15) });
        else if (roll < 0.7) add('trash', px, py, { r: 6 });
        else if (roll < 0.82) add('hydrant', px, py, { r: 5 });
        else add('bench', px, py, { w: 22, h: 9, angle: side < 2 ? 0 : Math.PI / 2 });
      }

      const ix = x0 + 30;
      const iy = y0 + 30;
      const inner = BLOCK - 60;
      const special = Math.random() < 0.14;
      const type = Math.random();

      if (special) {
        addSpecialBlock(add, x0, y0, type, theme);
      } else if (type < 0.2) {
        // Park
        add('fountain', x0 + BLOCK / 2, y0 + BLOCK / 2, { r: 26 });
        for (let i = 0; i < 12 * d; i++) {
          const px = rand(ix, ix + inner);
          const py = rand(iy, iy + inner);
          if (Math.hypot(px - x0 - BLOCK / 2, py - y0 - BLOCK / 2) < 40) continue;
          const roll = Math.random();
          if (themed()) addThemeProp(px, py);
          else if (roll < 0.5) add('tree', px, py, { r: rand(12, 18) });
          else if (roll < 0.8) add('person', px, py, { r: 6, color: pick(PEOPLE_COLORS), walker: true });
          else add('bench', px, py, { w: 22, h: 9, angle: Math.random() < 0.5 ? 0 : Math.PI / 2 });
        }
      } else if (type < 0.6) {
        // Houses in a 2x2 or 3x3 grid
        const g = Math.random() < 0.5 ? 2 : 3;
        const cell = inner / g;
        for (let gx = 0; gx < g; gx++) {
          for (let gy = 0; gy < g; gy++) {
            const w = cell * rand(0.55, 0.75);
            const h = cell * rand(0.55, 0.75);
            add('house', ix + gx * cell + cell / 2, iy + gy * cell + cell / 2, {
              w,
              h,
              height: rand(14, 24),
              color: pick(theme.roofs),
            });
          }
        }
      } else if (type < 0.85) {
        // Mixed: a mid building + small shops
        add('building', x0 + BLOCK * 0.36, y0 + BLOCK * 0.4, {
          w: rand(100, 130),
          h: rand(100, 130),
          height: rand(40, 60),
          color: pick(theme.roofs),
        });
        for (let i = 0; i < 3; i++) {
          add('house', x0 + BLOCK * 0.78, y0 + 70 + i * 80, {
            w: rand(40, 55),
            h: rand(40, 55),
            height: rand(12, 18),
            color: pick(theme.roofs),
          });
        }
        for (let i = 0; i < 2; i++) {
          add('car', x0 + BLOCK * 0.25 + i * 55, y0 + BLOCK * 0.82, {
            w: 30,
            h: 16,
            color: pick(CAR_COLORS),
            angle: Math.PI / 2,
          });
        }
      } else {
        // Skyscraper
        add('tower', x0 + BLOCK / 2, y0 + BLOCK / 2, {
          w: rand(150, 190),
          h: rand(150, 190),
          height: rand(80, 120),
          color: pick(theme.roofs),
        });
      }
    }
  }

  // Roads: moving cars, buses, cones.
  for (let i = 0; i <= n; i++) {
    const roadPos = i * (BLOCK + ROAD) + ROAD / 2;
    const count = Math.round(n * 2.2 * d);
    for (let c = 0; c < count; c++) {
      const horizontal = c % 2 === 0;
      const along = rand(0, size);
      const lane = Math.random() < 0.5 ? -1 : 1;
      const isBus = Math.random() < 0.12;
      const speed = rand(40, 80) * lane;
      const x = horizontal ? along : roadPos + lane * 16;
      const y = horizontal ? roadPos + lane * 16 : along;
      add(isBus ? 'bus' : 'car', x, y, {
        w: isBus ? 64 : 30,
        h: isBus ? 24 : 16,
        color: isBus ? theme.busColor || '#ffbe0b' : pick(theme.carColors || CAR_COLORS),
        angle: horizontal ? (lane > 0 ? 0 : Math.PI) : lane > 0 ? Math.PI / 2 : -Math.PI / 2,
        vx: horizontal ? speed : 0,
        vy: horizontal ? 0 : speed,
      });
    }
    for (let c = 0; c < n * d; c++) {
      const along = rand(0, size);
      if (Math.random() < 0.5) add('cone', along, roadPos + rand(-30, 30), { r: 5 });
      else add('cone', roadPos + rand(-30, 30), along, { r: 5 });
    }
  }

  const bossX = ROAD + center * (BLOCK + ROAD) + BLOCK / 2;
  const bossY = ROAD + center * (BLOCK + ROAD) + BLOCK / 2;
  if (level.number <= 5) {
    // A readable snack trail along the spawn road removes the random slow start.
    // Its area is included before sizing the boss and calculating completion.
    const spawnY = bossY + BLOCK / 2 + ROAD / 2;
    for (const side of [-1, 1]) {
      for (let i = 1; i <= 12; i++) {
        add(i % 3 === 0 ? 'tree' : 'cone', bossX + side * i * 22, spawnY,
          { r: i % 3 === 0 ? 11 : 5, starter: true });
      }
      if (level.number === 4) for (let i=0;i<3;i++) {
        add('car',bossX+side*(70+i*65),spawnY+25,{w:30,h:16,color:'#ffd23f',starter:true});
      }
    }
  }
  // Size the boss from what this map can actually feed: the hole must eat bossShare of
  // the props' area first, so every level stays winnable however large it gets.
  const area = objects.reduce((s, o) => s + o.r * o.r, 0);
  const needR = Math.sqrt(BASE_START_R * BASE_START_R + level.bossShare * level.growth * area);
  const boss = add('boss', bossX, bossY, {
    r: Math.max(MIN_BOSS_R, needR * EAT_RATIO),
    bossType: theme.boss,
    landmark: theme.landmark,
    isBoss: true,
  });
  boss.pts = 0;

  const totalPts = objects.reduce((s, o) => s + o.pts, 0);
  return {
    size,
    objects,
    boss,
    totalPts,
    theme,
    center: { x: bossX, y: bossY },
    spawn: { x: bossX, y: bossY + BLOCK / 2 + ROAD / 2 },
  };
}

export function updateObjects(world, dt, time) {
  const size = world.size;
  for (const o of world.objects) {
    if (o.eaten || o.falling || o.abducted) continue;
    if (o.vx || o.vy) {
      o.x += o.vx * dt;
      o.y += o.vy * dt;
      if (o.x < -40) o.x += size + 80;
      if (o.x > size + 40) o.x -= size + 80;
      if (o.y < -40) o.y += size + 80;
      if (o.y > size + 40) o.y -= size + 80;
    } else if (o.walker) {
      o.x += Math.sin(time * 0.8 + o.y) * 6 * dt;
      o.y += Math.cos(time * 0.7 + o.x) * 6 * dt;
    }
  }
}

export function drawGround(ctx, world, view) {
  const { theme, size } = world;
  ctx.fillStyle = theme.road;
  ctx.fillRect(-200, -200, size + 400, size + 400);

  const step = BLOCK + ROAD;
  const n = Math.round((size - ROAD) / step);
  for (let bx = 0; bx < n; bx++) {
    for (let by = 0; by < n; by++) {
      const x0 = ROAD + bx * step;
      const y0 = ROAD + by * step;
      if (x0 > view.x1 || y0 > view.y1 || x0 + BLOCK < view.x0 || y0 + BLOCK < view.y0) continue;
      ctx.fillStyle = '#c9c9c9';
      ctx.fillRect(x0 - 6, y0 - 6, BLOCK + 12, BLOCK + 12);
      ctx.fillStyle = theme.block;
      ctx.fillRect(x0, y0, BLOCK, BLOCK);
      // Inset sidewalks, paving joints and a landscaped central boss plaza.
      ctx.strokeStyle = 'rgba(255,255,255,0.22)';ctx.lineWidth = 2;
      ctx.strokeRect(x0+9,y0+9,BLOCK-18,BLOCK-18);
      ctx.fillStyle='rgba(40,55,75,0.08)';
      for(let i=32;i<BLOCK;i+=32) {
        ctx.fillRect(x0+i,y0-6,1,6);ctx.fillRect(x0-6,y0+i,6,1);
      }
      if(bx===Math.floor(n/2)&&by===Math.floor(n/2)) {
        const cx=x0+BLOCK/2,cy=y0+BLOCK/2;
        const garden=ctx.createRadialGradient(cx-35,cy-45,10,cx,cy,155);
        garden.addColorStop(0,theme.block);garden.addColorStop(1,theme.ground);
        ctx.fillStyle=garden;ctx.beginPath();ctx.arc(cx,cy,148,0,Math.PI*2);ctx.fill();
        ctx.strokeStyle='rgba(255,248,216,0.5)';ctx.lineWidth=8;ctx.stroke();
        ctx.strokeStyle='rgba(40,55,75,0.13)';ctx.lineWidth=2;
        ctx.beginPath();ctx.arc(cx,cy,125,0,Math.PI*2);ctx.stroke();
      }
    }
  }

  // Lane markings
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.lineWidth = 3;
  ctx.setLineDash([18, 16]);
  ctx.beginPath();
  for (let i = 0; i <= n; i++) {
    const p = i * step + ROAD / 2;
    ctx.moveTo(0, p);
    ctx.lineTo(size, p);
    ctx.moveTo(p, 0);
    ctx.lineTo(p, size);
  }
  ctx.stroke();
  ctx.setLineDash([]);

  // Map border
  ctx.strokeStyle = 'rgba(0,0,0,0.5)';
  ctx.lineWidth = 12;
  ctx.strokeRect(0, 0, size, size);
}

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.max(0, Math.min(255, (n >> 16) + amt));
  const g = Math.max(0, Math.min(255, ((n >> 8) & 255) + amt));
  const b = Math.max(0, Math.min(255, (n & 255) + amt));
  return `rgb(${r},${g},${b})`;
}

function shadowCircle(ctx, r, off) {
  ctx.fillStyle = 'rgba(0,0,0,0.22)';
  ctx.beginPath();
  ctx.ellipse(off, off, r, r * 0.9, 0, 0, Math.PI * 2);
  ctx.fill();
}

function drawBlockBuilding(ctx, o, windows) {
  const { w, h, height, color } = o;
  const lift = height * 0.45;
  ctx.fillStyle = 'rgba(0,0,0,0.25)';
  ctx.fillRect(-w / 2 + lift * 0.4, -h / 2 + lift * 0.4, w, h);
  ctx.fillStyle = shade(color, -70);
  ctx.fillRect(-w / 2, -h / 2 - lift, w, h + lift);
  if (windows) {
    ctx.fillStyle = 'rgba(255,240,170,0.8)';
    const cols = Math.max(2, Math.floor(w / 22));
    const rows = Math.max(1, Math.floor(lift / 14));
    for (let c = 0; c < cols; c++) {
      for (let r = 0; r < rows; r++) {
        ctx.fillRect(-w / 2 + 6 + c * ((w - 12) / cols), h / 2 - lift + 4 + r * 14, (w - 12) / cols - 6, 7);
      }
    }
  }
  ctx.fillStyle = color;
  ctx.fillRect(-w / 2, -h / 2 - lift, w, h);
  ctx.strokeStyle = shade(color, -40);
  ctx.lineWidth = 3;
  ctx.strokeRect(-w / 2 + 6, -h / 2 - lift + 6, w - 12, h - 12);
}

export function drawObject(ctx, o, time) {
  ctx.save();
  ctx.translate(o.x, o.y);
  switch (o.kind) {
    case 'duckling':
      shadowCircle(ctx, o.r, 2);
      ctx.fillStyle='#ffdb55';ctx.beginPath();ctx.ellipse(0,0,o.r,o.r*0.7,0,0,Math.PI*2);ctx.fill();
      ctx.beginPath();ctx.arc(o.r*0.35,-o.r*0.55,o.r*0.55,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#fff1a3';ctx.beginPath();ctx.ellipse(-o.r*0.25,-o.r*0.05,o.r*0.42,o.r*0.28,-0.3,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#ff8b38';ctx.fillRect(o.r*0.65,-o.r*0.55,o.r*0.55,o.r*0.22);
      ctx.fillStyle='#23334a';ctx.beginPath();ctx.arc(o.r*0.48,-o.r*0.65,o.r*0.1,0,Math.PI*2);ctx.fill();
      break;
    case 'person':
      shadowCircle(ctx, o.r, 2);
      ctx.fillStyle = o.color;
      ctx.beginPath();
      ctx.arc(0, 0, o.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#ffd6a5';
      ctx.beginPath();
      ctx.arc(0, -o.r * 0.3, o.r * 0.55, 0, Math.PI * 2);
      ctx.fill();
      break;
    case 'tree':
      shadowCircle(ctx, o.r, 4);
      ctx.fillStyle = '#2d6a4f';
      ctx.beginPath();
      ctx.arc(0, -4, o.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#40916c';
      ctx.beginPath();
      ctx.arc(-o.r * 0.25, -4 - o.r * 0.25, o.r * 0.6, 0, Math.PI * 2);
      ctx.fill();
      break;
    case 'trash':
      shadowCircle(ctx, o.r, 2);
      ctx.fillStyle = '#495057';
      ctx.beginPath();
      ctx.arc(0, 0, o.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#6c757d';
      ctx.beginPath();
      ctx.arc(0, -1, o.r * 0.6, 0, Math.PI * 2);
      ctx.fill();
      break;
    case 'hydrant':
      ctx.fillStyle = '#d00000';
      ctx.beginPath();
      ctx.arc(0, 0, o.r, 0, Math.PI * 2);
      ctx.fill();
      break;
    case 'cone':
      ctx.fillStyle = '#ff7b00';
      ctx.beginPath();
      ctx.moveTo(0, -o.r * 1.4);
      ctx.lineTo(o.r, o.r);
      ctx.lineTo(-o.r, o.r);
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.fillRect(-o.r * 0.55, -o.r * 0.1, o.r * 1.1, o.r * 0.35);
      break;
    case 'fountain':
      shadowCircle(ctx, o.r, 3);
      ctx.fillStyle = '#adb5bd';
      ctx.beginPath();
      ctx.arc(0, 0, o.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#4cc9f0';
      ctx.beginPath();
      ctx.arc(0, 0, o.r * 0.75, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#caf0f8';
      ctx.beginPath();
      ctx.arc(0, 0, o.r * (0.2 + Math.sin(time * 5) * 0.05), 0, Math.PI * 2);
      ctx.fill();
      break;
    case 'bench':
      ctx.rotate(o.angle);
      ctx.fillStyle = 'rgba(0,0,0,0.2)';
      ctx.fillRect(-o.w / 2 + 2, -o.h / 2 + 2, o.w, o.h);
      ctx.fillStyle = '#9c6644';
      ctx.fillRect(-o.w / 2, -o.h / 2, o.w, o.h);
      break;
    case 'car':
    case 'bus':
      ctx.rotate(o.angle);
      ctx.fillStyle = 'rgba(0,0,0,0.25)';
      ctx.fillRect(-o.w / 2 + 3, -o.h / 2 + 3, o.w, o.h);
      ctx.fillStyle = o.color;
      ctx.beginPath();
      ctx.roundRect(-o.w / 2, -o.h / 2, o.w, o.h, 4);
      ctx.fill();
      ctx.fillStyle = 'rgba(30,40,60,0.75)';
      if (o.kind === 'car') {
        ctx.fillRect(o.w * 0.08, -o.h / 2 + 2, o.w * 0.2, o.h - 4);
        ctx.fillRect(-o.w * 0.32, -o.h / 2 + 2, o.w * 0.14, o.h - 4);
      } else {
        for (let i = 0; i < 5; i++) ctx.fillRect(-o.w / 2 + 6 + i * 11, -o.h / 2 + 2, 7, 4);
        for (let i = 0; i < 5; i++) ctx.fillRect(-o.w / 2 + 6 + i * 11, o.h / 2 - 6, 7, 4);
      }
      break;
    case 'house':
      drawBlockBuilding(ctx, o, false);
      break;
    case 'building':
    case 'tower':
      drawBlockBuilding(ctx, o, true);
      break;
    case 'boss':
      drawBoss(ctx, o, time);
      break;
    default:
      drawProp(ctx, o, time);
  }
  ctx.restore();
}
