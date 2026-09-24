// Themes cycle; difficulty scales with the level number.
// Display text lives in locales under <boss>Name / <boss>Boss / <boss>Twist.
// weather: clear | rain | snow | wind | sun | fog | storm (see weather.js).
const BOSSES = {
  duck: { weather: 'clear', ground: '#7cc46b', road: '#4a4f63', block: '#a8d98f', roofs: ['#ff6b6b', '#ffa94d', '#74c0fc', '#b197fc'] },
  pizza: { weather: 'sun', ground: '#e9c46a', road: '#5b4a3f', block: '#f4d58d', roofs: ['#e76f51', '#f4a261', '#2a9d8f', '#e63946'] },
  frog: { weather: 'rain', ground: '#6c8a7a', road: '#343a46', block: '#8fb3a0', roofs: ['#5c7aea', '#3d5a80', '#98c1d9', '#ee6c4d'] },
  cow: { weather: 'wind', ground: '#b5c96a', road: '#7a5c3e', block: '#d4e09b', roofs: ['#bc4749', '#f2e8cf', '#a7c957', '#6a994e'] },
  dumbbell: { weather: 'clear', ground: '#8ecae6', road: '#3d405b', block: '#bde0fe', roofs: ['#ef476f', '#ffd166', '#06d6a0', '#118ab2'] },
  snowman: { weather: 'snow', ground: '#e3f2fd', road: '#90a4ae', block: '#f5fbff', roofs: ['#c62828', '#1565c0', '#2e7d32', '#6d4c41'] },
  cat: { weather: 'rain', ground: '#cdb4db', road: '#4a4e69', block: '#e2cfea', roofs: ['#ffafcc', '#a2d2ff', '#ffc8dd', '#bde0fe'] },
  pumpkin: { weather: 'fog', ground: '#3d2c4d', road: '#1f1a2b', block: '#54406b', roofs: ['#ff7b00', '#6a4c93', '#8ac926', '#3a0ca3'] },
  kraken: { weather: 'storm', ground: '#4f6d7a', road: '#2b3a42', block: '#6f8f9c', roofs: ['#e07a5f', '#3d405b', '#81b29a', '#f2cc8f'] },
  ufo: { weather: 'wind', ground: '#3a3f5c', road: '#1f2235', block: '#50577a', roofs: ['#9b5de5', '#f15bb5', '#00bbf9', '#00f5d4'] },
};

// Real-world landmarks take the boss slot on every third level.
// props: small themed objects mixed into sidewalks and parks (see props.js).
const LONDON_BUS = '#d62828';
const NY_TAXIS = ['#ffd000', '#ffd000', '#ffd000', '#f1faee', '#457b9d', '#e63946'];
const LANDMARKS = {
  eiffel: { weather: 'clear', ground: '#9bc47a', road: '#5a5a6e', block: '#c5dca0', roofs: ['#6c7a89', '#8d99ae', '#e5989b', '#b5838d'], props: ['cafe', 'lamp'] },
  pisa: { weather: 'clear', ground: '#a7c957', road: '#6b4f3a', block: '#dde5b6', roofs: ['#e07a5f', '#f2cc8f', '#d68c45', '#bc6c25'], props: ['gelato', 'column'] },
  pyramid: { weather: 'sun', ground: '#e9c46a', road: '#a47148', block: '#f1d9a0', roofs: ['#e76f51', '#f4a261', '#dda15e', '#bc6c25'], props: ['camel', 'palm', 'obelisk'] },
  bigben: { weather: 'rain', ground: '#6a8d73', road: '#3a3d4a', block: '#94b49f', roofs: ['#9e2a2b', '#540b0e', '#335c67', '#e09f3e'], props: ['phonebox', 'lamp'], busColor: LONDON_BUS },
  liberty: { weather: 'fog', ground: '#7fa7a0', road: '#343a40', block: '#a3c4bc', roofs: ['#f4f1de', '#e07a5f', '#3d405b', '#81b29a'], props: ['hotdog', 'lamp'], carColors: NY_TAXIS },
  colosseum: { weather: 'sun', ground: '#c9b37e', road: '#6d597a', block: '#e6d5a8', roofs: ['#b56576', '#e56b6f', '#eaac8b', '#6d597a'], props: ['column', 'amphora', 'gelato'] },
  fuji: { weather: 'snow', ground: '#e8f1f2', road: '#8d99ae', block: '#f8f9fa', roofs: ['#d62828', '#003049', '#f77f00', '#6a994e'], props: ['torii', 'sakura'] },
  turtle: { weather: 'fog', ground: '#7a9e7e', road: '#3e4a3d', block: '#a8c3a0', roofs: ['#c0392b', '#e9c46a', '#f4a261', '#588157'], props: ['lantern', 'cyclo'] },
  arc: { weather: 'wind', ground: '#a3b18a', road: '#4a4e69', block: '#c9d6b3', roofs: ['#9a8c98', '#c9ada7', '#4a4e69', '#e5989b'], props: ['cafe', 'lamp'] },
  stonehenge: { weather: 'storm', ground: '#588157', road: '#344e41', block: '#8fae7e', roofs: ['#6b705c', '#a5a58d', '#b7b7a4', '#3a5a40'], props: ['sheep', 'hay'] },
  parthenon: { weather: 'sun', ground: '#d4c79a', road: '#5e548e', block: '#ede0b8', roofs: ['#f8f9fa', '#4895ef', '#e9c46a', '#bde0fe'], props: ['column', 'amphora'] },
  greatwall: { weather: 'wind', ground: '#8cb369', road: '#5c4d3c', block: '#b5cf8f', roofs: ['#c1121f', '#f4a261', '#2a9d8f', '#6d597a'], props: ['lantern', 'panda'] },
  tajmahal: { weather: 'sun', ground: '#b7d68f', road: '#7b5e57', block: '#e3efc6', roofs: ['#f4978e', '#f8ad9d', '#90be6d', '#f9c74f'], props: ['elephant', 'palm'] },
  towerbridge: { weather: 'rain', ground: '#6f8f80', road: '#343a46', block: '#9bb5a6', roofs: ['#9e2a2b', '#335c67', '#e09f3e', '#6c757d'], props: ['phonebox', 'lamp'], busColor: LONDON_BUS },
  neuschwanstein: { weather: 'snow', ground: '#e3eef5', road: '#7d8597', block: '#f4f8fb', roofs: ['#3a86ff', '#8338ec', '#e63946', '#495057'], props: ['pine', 'sheep'] },
  chichen: { weather: 'rain', ground: '#5f8d4e', road: '#6b4f3a', block: '#8fbf7a', roofs: ['#f77f00', '#fcbf49', '#d62828', '#2a9d8f'], props: ['cactus', 'palm'] },
  machupicchu: { weather: 'fog', ground: '#7aa36b', road: '#5a4a3c', block: '#a7c796', roofs: ['#9c6644', '#b08968', '#7f5539', '#ddb892'], props: ['llama', 'hay'] },
  moai: { weather: 'clear', ground: '#90be6d', road: '#4a4e69', block: '#b9d89a', roofs: ['#f9844a', '#43aa8b', '#577590', '#f9c74f'], props: ['minimoai', 'palm'] },
};

export const LANDMARK_IDS = new Set(Object.keys(LANDMARKS));

// 54-level loop: boss, boss, landmark. Ordered so each weather debuts gradually
// (sun 2, rain 4, wind 5, snow 8, fog 11, storm 13) and no three harsh weathers line up.
const SEQUENCE = [
  'duck', 'pizza', 'eiffel',
  'frog', 'cow', 'pisa',
  'dumbbell', 'snowman', 'pyramid',
  'cat', 'pumpkin', 'bigben',
  'kraken', 'ufo', 'liberty',
  'duck', 'pizza', 'colosseum',
  'frog', 'cow', 'fuji',
  'dumbbell', 'snowman', 'turtle',
  'cat', 'pumpkin', 'arc',
  'kraken', 'ufo', 'stonehenge',
  'duck', 'cat', 'parthenon',
  'pizza', 'snowman', 'greatwall',
  'dumbbell', 'frog', 'tajmahal',
  'cow', 'pumpkin', 'towerbridge',
  'duck', 'kraken', 'neuschwanstein',
  'pizza', 'ufo', 'chichen',
  'cat', 'snowman', 'machupicchu',
  'dumbbell', 'kraken', 'moai',
];

export const THEMES = SEQUENCE.map((id) => ({
  boss: id,
  landmark: LANDMARK_IDS.has(id),
  ...(BOSSES[id] || LANDMARKS[id]),
}));

// Difficulty curve: 0 at level 1, 1 at level 20, then a slow climb.
// Tuned with tools/balance-sim.mjs against attempts-per-success targets
// (~1.0 early, ~1.3 mid, spikes ~1.6-1.9).
const RAMP_LEVELS = 20;
const LATE_SLOPE = 0.1;
// Past level 30 the climb flattens so the long tail stays playable.
const PLATEAU_LEVEL = 30;
const PLATEAU_SLOPE = 0.02;
// Sawtooth within each boss-boss-landmark triple: the second boss is the peak and
// the landmark is a breather; each loop opens with a bigger breather.
const TRIPLE_SAW = [0, 0.04, -0.04];
const LOOP_OPENER_SAW = -0.08;

const lerp = (a, b, t) => a + (b - a) * t;

export function difficulty(n) {
  const t = n - 1;
  const late = Math.min(t, PLATEAU_LEVEL - 1) - RAMP_LEVELS + 1;
  const plateau = Math.max(0, t - PLATEAU_LEVEL + 1);
  const base = t < RAMP_LEVELS ? t / (RAMP_LEVELS - 1) : 1 + late * LATE_SLOPE + plateau * PLATEAU_SLOPE;
  if (n === 1) return base;
  const p = t % THEMES.length;
  return Math.max(0, base + (p === 0 ? LOOP_OPENER_SAW : TRIPLE_SAW[p % 3]));
}

export function getLevel(n) {
  const theme = THEMES[(n - 1) % THEMES.length];
  const d = difficulty(n);
  const early = Math.min(d, 1);
  const late = Math.max(0, d - 1);
  return {
    number: n,
    theme,
    weather: theme.weather,
    difficulty: d,
    // Fraction of an eaten object's area the hole gains; high early so the snowball is fast.
    growth: Math.max(0.12, lerp(0.3, 0.15, Math.pow(early, 0.4)) - late * 0.03),
    weatherPower: Math.min(1.4, lerp(0.3, 0.85, early) + late * 0.25),
    blocks: Math.min(5 + Math.round(d * 4), 9),
    density: 1 + d * 0.6,
    // Share of the map's prop area the hole must eat before it can swallow the boss.
    bossShare: Math.min(0.8, lerp(0.2, 0.5, early) + late * 0.15),
    duration: Math.max(60, Math.round(lerp(110, 80, Math.sqrt(early)) - late * 8)),
  };
}
