import { sdk } from './sdk.js';
import { audio } from './audio.js';
import { setLanguage, applyStaticText, t, getLang, isSupported, LANGUAGES } from './i18n.js';
import { getLevel, THEMES } from './levels.js';
import { Game } from './game.js';
import { drawObject } from './world.js';
import { STAT_UPGRADES, upgradeCost, emptyUpgrades } from './upgrades.js';
import { COSMETIC_SLOTS, drawSkinInside, drawSkinRim } from './cosmetics.js';

const SAVE_VERSION = 2;
const TABS = ['stats', 'skin', 'fx', 'trail'];
const TAB_LABELS = { stats: 'tabStats', skin: 'tabSkins', fx: 'tabFx', trail: 'tabTrails' };

function defaultCosmetics() {
  const owned = {};
  const look = {};
  for (const [slot, def] of Object.entries(COSMETIC_SLOTS)) {
    const free = def.list.filter((c) => c.price === 0).map((c) => c.id);
    owned[slot] = free;
    look[slot] = free[0];
  }
  return { owned, look };
}

const save = {
  v: SAVE_VERSION,
  level: 1,
  coins: 0,
  best: 0,
  up: emptyUpgrades(),
  ...defaultCosmetics(),
  lang: null,
  // Best stars per cleared level, indexed by level - 1 (missing for levels cleared before this existed).
  stars: [],
};

const $ = (id) => document.getElementById(id);
const screens = ['menu', 'shop', 'result', 'confirm', 'continue', 'levels'];

// Interstitials stay light for a young audience: none in the first levels, only on
// "Next" taps, at most one per INTERSTITIAL_EVERY level ends and INTERSTITIAL_GAP_MS.
const INTERSTITIAL_FROM_LEVEL = 4;
const INTERSTITIAL_EVERY = 3;
const INTERSTITIAL_GAP_MS = 150000;
const CONTINUE_SECONDS = 20;
// Reward IDs must stay stable per reward type and contain no user data.
const REWARD_DOUBLE_COINS = 'double-level-coins';
const REWARD_EXTRA_TIME = 'extra-time-20s';

// The game only runs when no one holds a pause: 'system' (YouTube onPause) or 'ad'.
const pauseReasons = new Set();
let previewLoopStopped = false;

function setPause(reason, on) {
  if (on) pauseReasons.add(reason);
  else pauseReasons.delete(reason);
  const paused = pauseReasons.size > 0;
  game.setPaused(paused);
  if (!paused && previewLoopStopped) {
    previewLoopStopped = false;
    requestAnimationFrame(drawPreviews);
  }
}

let adBusy = false;
let lastAdAt = Date.now();
let levelEndsSinceAd = 0;
let returnTo = 'menu';
let lastResult = null;
let activeTab = 'stats';

function show(id) {
  for (const s of screens) $(s).classList.toggle('hidden', s !== id);
}

function hideAll() {
  for (const s of screens) $(s).classList.add('hidden');
}

function persist() {
  sdk.saveData(save);
}

function renderMenu() {
  $('menu-level').textContent = `${t('level')} ${save.level}`;
  $('menu-coins').textContent = save.coins;
}

function makeCard({ visual, name, sub, button, equipped }) {
  const card = document.createElement('div');
  card.className = equipped ? 'card equipped' : 'card';
  card.appendChild(visual);
  const nameEl = document.createElement('div');
  nameEl.className = 'name';
  nameEl.textContent = name;
  card.appendChild(nameEl);
  const subEl = document.createElement('div');
  subEl.className = 'desc';
  subEl.textContent = sub;
  card.appendChild(subEl);
  card.appendChild(button);
  return card;
}

function makeButton(label, disabled, onClick) {
  const btn = document.createElement('button');
  btn.className = 'btn';
  btn.textContent = label;
  btn.disabled = disabled;
  btn.addEventListener('click', onClick);
  return btn;
}

function renderStatCards(list) {
  for (const u of STAT_UPGRADES) {
    const lvl = save.up[u.key];
    const maxed = lvl >= u.max;
    const cost = upgradeCost(u, lvl);
    const icon = document.createElement('div');
    icon.className = 'icon';
    icon.textContent = u.icon;
    const button = makeButton(maxed ? t('max') : `● ${cost}`, maxed || save.coins < cost, () => {
      if (maxed || save.coins < cost) return;
      save.coins -= cost;
      save.up[u.key]++;
      audio.grow();
      persist();
      renderShop();
    });
    list.appendChild(
      makeCard({ visual: icon, name: t(u.label), sub: `${u.desc} · ${t('lvl', { n: lvl })} / ${u.max}`, button })
    );
  }
}

function renderCosmeticCards(list, slot) {
  const def = COSMETIC_SLOTS[slot];
  for (const item of def.list) {
    const owned = save.owned[slot].includes(item.id);
    const equipped = save.look[slot] === item.id;
    let visual;
    if (slot === 'skin') {
      visual = document.createElement('canvas');
      visual.className = 'preview';
      visual.dataset.skin = item.id;
    } else {
      visual = document.createElement('div');
      visual.className = 'icon big';
      visual.textContent = item.icon;
    }
    let label;
    if (equipped) label = t('equipped');
    else if (owned) label = t('equip');
    else label = `● ${item.price}`;
    const button = makeButton(label, equipped || (!owned && save.coins < item.price), () => {
      if (!owned) {
        if (save.coins < item.price) return;
        save.coins -= item.price;
        save.owned[slot].push(item.id);
        audio.win();
      } else {
        audio.click();
      }
      save.look[slot] = item.id;
      game.setLook(save.look);
      persist();
      renderShop();
    });
    list.appendChild(makeCard({ visual, name: t(def.prefix + item.id), sub: '', button, equipped }));
  }
}

function renderShop() {
  $('shop-coins').textContent = save.coins;
  const tabs = $('shop-tabs');
  tabs.innerHTML = '';
  for (const tab of TABS) {
    const b = document.createElement('button');
    b.className = tab === activeTab ? 'tab active' : 'tab';
    b.textContent = t(TAB_LABELS[tab]);
    b.addEventListener('click', () => {
      audio.click();
      activeTab = tab;
      renderShop();
    });
    tabs.appendChild(b);
  }
  const list = $('shop-list');
  list.innerHTML = '';
  if (activeTab === 'stats') renderStatCards(list);
  else renderCosmeticCards(list, activeTab);
}

function drawPreviews(ts) {
  if (pauseReasons.size) {
    previewLoopStopped = true;
    return;
  }
  requestAnimationFrame(drawPreviews);
  if ($('shop').classList.contains('hidden') || activeTab !== 'skin') return;
  const time = ts / 1000;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  for (const c of document.querySelectorAll('canvas.preview')) {
    const size = c.clientWidth || 72;
    if (c.width !== size * dpr) {
      c.width = size * dpr;
      c.height = size * dpr;
    }
    const ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, size, size);
    const r = size * 0.3;
    drawSkinInside(ctx, c.dataset.skin, size / 2, size / 2, r, time);
    drawSkinRim(ctx, c.dataset.skin, size / 2, size / 2, r, time, 0);
  }
}

function renderResult(r) {
  $('result-level').textContent = `${t('level')} ${r.level}`;
  $('result-title').textContent = r.cleared ? t('cleared') : t('failed');
  $('result-stars').innerHTML = [0, 1, 2]
    .map((i) => `<span class="${i < r.stars ? 'on' : 'off'}">★</span>`)
    .join('');
  $('result-twist').textContent = r.twist;
  $('result-score').textContent = r.score;
  $('result-eaten').textContent = `${Math.floor(r.pct * 100)}%`;
  $('result-coins').textContent = `+${r.doubled ? r.coins * 2 : r.coins}`;
  $('btn-next').textContent = r.cleared ? t('next') : t('retry');
  const double = $('btn-double');
  double.classList.toggle('hidden', !sdk.rewardedAdsAvailable || r.coins <= 0 || r.doubled);
  double.disabled = false;
  double.textContent = t('adDouble');
}

// Pauses the game around an ad so gameplay and audio never run underneath it.
async function runAd(show) {
  adBusy = true;
  setPause('ad', true);
  try {
    return await show();
  } finally {
    lastAdAt = Date.now();
    setPause('ad', false);
    adBusy = false;
  }
}

function shouldShowInterstitial() {
  return (
    save.level >= INTERSTITIAL_FROM_LEVEL &&
    levelEndsSinceAd >= INTERSTITIAL_EVERY &&
    Date.now() - lastAdAt >= INTERSTITIAL_GAP_MS
  );
}

function onTimeUp() {
  if (!sdk.rewardedAdsAvailable) return false;
  $('continue-text').textContent = t('continueAsk', { n: CONTINUE_SECONDS });
  const btn = $('btn-continue-ad');
  btn.textContent = t('watchAdTime', { n: CONTINUE_SECONDS });
  btn.disabled = false;
  show('continue');
  return true;
}

// Any level up to the furthest unlocked one can be (re)played.
function startLevel(n = save.level) {
  audio.unlock();
  audio.click();
  hideAll();
  game.start(getLevel(Math.min(n, save.level)), save.up, save.look);
}

function onLevelEnd(r) {
  lastResult = r;
  levelEndsSinceAd++;
  save.coins += r.coins;
  if (r.cleared) {
    save.stars[r.level - 1] = Math.max(save.stars[r.level - 1] || 0, r.stars);
    if (r.level === save.level) save.level++;
  }
  if (r.score > save.best) {
    save.best = r.score;
    sdk.sendScore(save.best);
  }
  persist();
  renderResult(r);
  show('result');
}

// Boss portraits are drawn once, not animated: dozens of live canvases would cost frames.
function drawBossPortrait(canvas, theme) {
  const size = 72;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = size * dpr;
  canvas.height = size * dpr;
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  drawObject(ctx, { kind: 'boss', bossType: theme.boss, landmark: theme.landmark, r: 27, x: size / 2, y: size / 2 + 3 }, 0);
}

function levelTile(n) {
  const theme = getLevel(n).theme;
  const tile = document.createElement('button');
  tile.className = 'level-tile';
  const add = (tag, cls, text) => {
    const el = document.createElement(tag);
    el.className = cls;
    if (text !== undefined) el.textContent = text;
    tile.appendChild(el);
    return el;
  };
  if (theme.landmark) add('span', 'badge', '🏛️');

  if (n < save.level) {
    if (theme.landmark) tile.classList.add('landmark');
    drawBossPortrait(add('canvas', ''), theme);
    add('span', 'num', `${t('level')} ${n}`);
    add('span', 'boss-name', t(`${theme.boss}Boss`));
    const stars = save.stars[n - 1];
    const starEl = add('span', 'mini-stars');
    if (stars !== undefined) {
      starEl.innerHTML = [0, 1, 2].map((i) => `<span class="${i < stars ? 'on' : 'off'}">★</span>`).join('');
    }
    tile.addEventListener('click', () => startLevel(n));
  } else if (n === save.level) {
    tile.classList.add('current');
    add('span', 'play', '▶');
    add('span', 'num', `${t('level')} ${n}`);
    add('span', 'boss-name', t('play'));
    add('span', 'mini-stars');
    tile.addEventListener('click', () => startLevel(n));
  } else {
    tile.classList.add('locked');
    tile.disabled = true;
    add('span', 'lock', '🔒');
    add('span', 'num', `${t('level')} ${n}`);
    add('span', 'boss-name', '');
    add('span', 'mini-stars');
  }
  return tile;
}

function openLevels() {
  audio.click();
  const grid = $('level-grid');
  grid.innerHTML = '';
  const count = Math.ceil(save.level / THEMES.length) * THEMES.length;
  for (let n = 1; n <= count; n++) grid.appendChild(levelTile(n));
  show('levels');
  grid.querySelector('.current')?.scrollIntoView({ block: 'center' });
}

function openShop(from) {
  audio.click();
  returnTo = from;
  renderShop();
  show('shop');
}

const game = new Game($('game'), {
  onFirstFrame: () => sdk.firstFrameReady(),
  onLevelEnd,
  onTimeUp,
});

$('btn-play').addEventListener('click', () => startLevel());
$('btn-next').addEventListener('click', async () => {
  if (adBusy) return;
  if (shouldShowInterstitial()) {
    await runAd(() => sdk.showInterstitial());
    levelEndsSinceAd = 0;
  }
  const r = lastResult;
  startLevel(r ? (r.cleared ? r.level + 1 : r.level) : save.level);
});

$('btn-double').addEventListener('click', async () => {
  const r = lastResult;
  if (adBusy || !r || r.doubled) return;
  audio.click();
  const btn = $('btn-double');
  btn.disabled = true;
  const earned = await runAd(() => sdk.showRewarded(REWARD_DOUBLE_COINS));
  if (earned) {
    r.doubled = true;
    save.coins += r.coins;
    persist();
    audio.grow();
    renderResult(r);
  } else {
    btn.textContent = t('adUnavailable');
  }
});

$('btn-continue-ad').addEventListener('click', async () => {
  if (adBusy) return;
  audio.click();
  const btn = $('btn-continue-ad');
  btn.disabled = true;
  const earned = await runAd(() => sdk.showRewarded(REWARD_EXTRA_TIME));
  if (earned) {
    hideAll();
    game.resolveContinue(CONTINUE_SECONDS);
  } else {
    $('continue-text').textContent = t('adUnavailable');
  }
});
$('btn-continue-no').addEventListener('click', () => {
  if (adBusy) return;
  audio.click();
  hideAll();
  game.resolveContinue(0);
});
$('btn-levels').addEventListener('click', openLevels);
$('btn-levels-back').addEventListener('click', () => {
  audio.click();
  renderMenu();
  show('menu');
});
$('btn-shop').addEventListener('click', () => openShop('menu'));
$('btn-result-shop').addEventListener('click', () => openShop('result'));
$('btn-shop-back').addEventListener('click', () => {
  audio.click();
  if (returnTo === 'result' && lastResult) {
    show('result');
  } else {
    renderMenu();
    show('menu');
  }
});

// Local testing only (?dev=1 outside YouTube): a full wipe would desync the saved best
// score from the Playables leaderboard, which certification forbids.
const DEV_TOOLS = !sdk.inPlayables && new URLSearchParams(location.search).get('dev') === '1';

function resetProgress() {
  Object.assign(save, { v: SAVE_VERSION, level: 1, coins: 0, best: 0, up: emptyUpgrades(), ...defaultCosmetics(), stars: [] });
  lastResult = null;
  activeTab = 'stats';
  persist();
  game.setLook(save.look);
  game.showWorldBackdrop(getLevel(save.level));
}

$('btn-reset').classList.toggle('hidden', !DEV_TOOLS);
$('btn-reset').addEventListener('click', () => {
  if (!DEV_TOOLS) return;
  audio.click();
  show('confirm');
});
$('btn-reset-no').addEventListener('click', () => {
  audio.click();
  show('menu');
});
$('btn-reset-yes').addEventListener('click', () => {
  if (!DEV_TOOLS) return;
  audio.lose();
  resetProgress();
  renderMenu();
  show('menu');
});

sdk.onPause(() => {
  setPause('system', true);
  persist();
});
sdk.onResume(() => setPause('system', false));
audio.setEnabled(sdk.isAudioEnabled());
sdk.onAudioEnabledChange((on) => audio.setEnabled(on));

window.addEventListener('error', (e) => sdk.logError(e.error || e.message));

const clampInt = (v, min, max) => Math.min(max, Math.max(min, v | 0));

// Accepts v1 saves (no cosmetics) as well as v2.
function restore(data) {
  if (!data || (data.v !== 1 && data.v !== 2)) return;
  save.level = clampInt(data.level, 1, 1e6);
  save.coins = clampInt(data.coins, 0, 1e9);
  save.best = clampInt(data.best, 0, 1e12);
  for (const u of STAT_UPGRADES) save.up[u.key] = clampInt(data.up?.[u.key], 0, u.max);
  for (const [slot, def] of Object.entries(COSMETIC_SLOTS)) {
    const valid = new Set(def.list.map((c) => c.id));
    const owned = (data.owned?.[slot] || []).filter((id) => valid.has(id));
    for (const id of save.owned[slot]) if (!owned.includes(id)) owned.push(id);
    save.owned[slot] = owned;
    const equipped = data.look?.[slot];
    if (owned.includes(equipped)) save.look[slot] = equipped;
  }
  if (isSupported(data.lang)) save.lang = data.lang;
  if (Array.isArray(data.stars)) {
    save.stars = data.stars.slice(0, save.level).map((s) => (s == null ? undefined : clampInt(s, 0, 3)));
  }
}

function initLanguagePicker() {
  const select = $('lang-select');
  for (const { code, name } of LANGUAGES) select.add(new Option(name, code));
  select.value = getLang();
  select.addEventListener('change', () => {
    audio.click();
    save.lang = select.value;
    setLanguage(save.lang);
    persist();
    applyStaticText();
    renderMenu();
  });
}

async function boot() {
  const [lang, data] = await Promise.all([sdk.getLanguage(), sdk.loadData()]);
  restore(data);
  const devLevel = Number(new URLSearchParams(location.search).get('level'));
  if (DEV_TOOLS && devLevel >= 1) save.level = Math.floor(devLevel);
  setLanguage(save.lang || lang);
  initLanguagePicker();
  applyStaticText();
  game.setLook(save.look);
  game.showWorldBackdrop(getLevel(save.level));
  renderMenu();
  show('menu');
  requestAnimationFrame(drawPreviews);
  sdk.gameReady();
}

boot();
