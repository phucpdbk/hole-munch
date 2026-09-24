// Dev gallery: every boss/landmark and a top-down preview of each level, drawn with game code.
import { THEMES, getLevel } from '../src/levels.js';
import { generateWorld, drawGround, drawObject } from '../src/world.js';
import { Weather, WEATHER_ICONS } from '../src/weather.js';
import { PROP_KINDS, PROP_SIZES } from '../src/props.js';
import { setLanguage, t, getLang, LANGUAGES } from '../src/i18n.js';

const $ = (id) => document.getElementById(id);
const params = new URLSearchParams(location.search);
setLanguage(params.get('lang') || navigator.language);

// Only cards on screen animate; 100+ live canvases would otherwise starve a game tab open alongside.
const animated = [];
const onScreen = new WeakSet();
const observer = new IntersectionObserver((entries) => {
  for (const e of entries) {
    if (e.isIntersecting) onScreen.add(e.target);
    else onScreen.delete(e.target);
  }
});

function animate(canvas, draw) {
  observer.observe(canvas);
  animated.push({ canvas, draw, drawn: false });
}

function weatherLabel(type) {
  return type === 'clear' ? '☀️ clear' : `${WEATHER_ICONS[type]} ${t(`weather_${type}`)}`;
}

function setupCanvas(canvas, w, h) {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = w * dpr;
  canvas.height = h * dpr;
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return ctx;
}

function renderBosses() {
  const grid = $('bosses');
  grid.innerHTML = '';
  const seen = new Map();
  THEMES.forEach((theme, i) => {
    const entry = seen.get(theme.boss) || { theme, levels: [] };
    entry.levels.push(i + 1);
    seen.set(theme.boss, entry);
  });
  for (const { theme, levels } of seen.values()) {
    const card = document.createElement('div');
    card.className = 'card';
    const canvas = document.createElement('canvas');
    canvas.style.aspectRatio = '1';
    card.appendChild(canvas);
    const size = 220;
    const ctx = setupCanvas(canvas, size, size);
    const boss = { kind: 'boss', bossType: theme.boss, landmark: theme.landmark, r: 78, x: size / 2, y: size / 2 + 6 };
    animate(canvas, (time) => {
      ctx.fillStyle = theme.block;
      ctx.fillRect(0, 0, size, size);
      drawObject(ctx, boss, time);
    });
    card.insertAdjacentHTML(
      'beforeend',
      `<div class="title">${t(`${theme.boss}Boss`)}<span class="tag ${theme.landmark ? 'landmark' : ''}">${theme.landmark ? 'landmark' : 'boss'}</span></div>
       <div class="sub">${t(`${theme.boss}Name`)} · ${weatherLabel(theme.weather)}</div>
       <div class="sub">${t('level')} ${levels.join(', ')} · repeats every ${THEMES.length}</div>
       <div class="stats">"${t(`${theme.boss}Twist`)}"</div>`
    );
    grid.appendChild(card);
  }
}

const STRUCTURE_SIZES = {
  windmill: { r: 30 }, ferris: { r: 58 }, carousel: { r: 32 }, gas: { w: 130, h: 80 },
  pump: { r: 6 }, pool: { w: 110, h: 60 }, field: { w: 220, h: 130 },
};

function renderProps() {
  const grid = $('props');
  grid.innerHTML = '';
  for (const kind of PROP_KINDS) {
    const dims = PROP_SIZES[kind] || STRUCTURE_SIZES[kind];
    const extent = dims.r ? dims.r * 2.2 : Math.max(dims.w, dims.h) * 1.15;
    const size = 130;
    const zoom = Math.min(4, size / extent);
    const card = document.createElement('div');
    card.className = 'card';
    const canvas = document.createElement('canvas');
    canvas.style.aspectRatio = '1';
    card.appendChild(canvas);
    const ctx = setupCanvas(canvas, size, size);
    const o = { kind, x: 0, y: 0, angle: 0, ...dims, r: dims.r || Math.hypot(dims.w, dims.h) * 0.36 };
    animate(canvas, (time) => {
      ctx.fillStyle = '#c5dca0';
      ctx.fillRect(0, 0, size, size);
      ctx.save();
      ctx.translate(size / 2, size / 2);
      ctx.scale(zoom, zoom);
      drawObject(ctx, o, time);
      ctx.restore();
    });
    const levels = THEMES.flatMap((th, i) => (th.props?.includes(kind) ? [i + 1] : []));
    card.insertAdjacentHTML(
      'beforeend',
      `<div class="title">${kind}</div><div class="sub">${levels.length ? `${t('level')} ${levels.join(', ')}` : 'any level'}</div>`
    );
    grid.appendChild(card);
  }
}

function renderLevels() {
  const grid = $('levels');
  grid.innerHTML = '';
  const from = Math.max(1, Number($('from').value) || 1);
  const count = Math.min(60, Math.max(1, Number($('count').value) || THEMES.length));
  for (let n = from; n < from + count; n++) {
    const level = getLevel(n);
    const world = generateWorld(level);
    const card = document.createElement('div');
    card.className = 'card';
    const canvas = document.createElement('canvas');
    canvas.style.aspectRatio = '1';
    card.appendChild(canvas);
    const size = 300;
    const ctx = setupCanvas(canvas, size, size);

    // The map itself is static; draw it once and only animate the weather on top.
    const map = document.createElement('canvas');
    map.width = map.height = size * 2;
    const mctx = map.getContext('2d');
    const scale = (size * 2) / world.size;
    mctx.scale(scale, scale);
    drawGround(mctx, world, { x0: 0, y0: 0, x1: world.size, y1: world.size });
    for (const o of [...world.objects].sort((a, b) => a.y - b.y)) drawObject(mctx, o, 0);

    const weather = new Weather(level.weather, level.weatherPower);
    const hole = { x: (world.spawn.x / world.size) * size, y: (world.spawn.y / world.size) * size, r: 20 * (size / world.size) * 3 };
    let last = 0;
    animate(canvas, (time) => {
      const dt = last ? Math.min(0.05, time - last) : 0;
      last = time;
      ctx.drawImage(map, 0, 0, size, size);
      weather.updateVisual(dt, size, size);
      weather.drawScreen(ctx, size, size, hole.x, hole.y, hole.r);
      ctx.fillStyle = '#000';
      ctx.beginPath();
      ctx.arc(hole.x, hole.y, Math.max(3, hole.r / 3), 0, Math.PI * 2);
      ctx.fill();
    });

    const lang = getLang();
    card.insertAdjacentHTML(
      'beforeend',
      `<div class="title">${t('level')} ${n} · ${t(`${level.theme.boss}Name`)}<span class="tag ${level.theme.landmark ? 'landmark' : ''}">${t(`${level.theme.boss}Boss`)}</span></div>
       <div class="sub">${weatherLabel(level.weather)} ×${level.weatherPower.toFixed(2)}</div>
       <div class="stats">difficulty ${level.difficulty.toFixed(2)} · growth ${level.growth.toFixed(3)}<br>
       boss r ${world.boss.r.toFixed(0)} (eat ${Math.round(level.bossShare * 100)}% first) · ${level.blocks}×${level.blocks} blocks<br>
       ${level.duration}s · ${world.objects.length} objects</div>
       <a class="play" href="/?dev=1&level=${n}&lang=${lang}" target="_blank">▶ Play level ${n}</a>`
    );
    grid.appendChild(card);
  }
}

function renderAll() {
  observer.disconnect();
  animated.length = 0;
  renderBosses();
  renderProps();
  renderLevels();
}

function loop(ts) {
  requestAnimationFrame(loop);
  const time = ts / 1000;
  const idle = document.hidden || !document.hasFocus();
  for (const a of animated) {
    if (a.drawn && (idle || !onScreen.has(a.canvas))) continue;
    a.draw(time);
    a.drawn = true;
  }
}

const langSelect = $('lang');
for (const { code, name } of LANGUAGES) langSelect.add(new Option(name, code));
langSelect.value = getLang();
langSelect.addEventListener('change', () => {
  setLanguage(langSelect.value);
  renderAll();
});
$('from').addEventListener('change', renderAll);
$('count').addEventListener('change', renderAll);
$('reroll').addEventListener('click', renderAll);

renderAll();
requestAnimationFrame(loop);
