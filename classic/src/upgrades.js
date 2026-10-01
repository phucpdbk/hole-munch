export const STAT_UPGRADES = [
  { key: 'size', icon: '⚫', label: 'upSize', base: 80, max: 10, desc: '+1.5' },
  { key: 'speed', icon: '⚡', label: 'upSpeed', base: 70, max: 10, desc: '+5%' },
  { key: 'time', icon: '⏱', label: 'upTime', base: 100, max: 10, desc: '+3s' },
  { key: 'magnet', icon: '🧲', label: 'upMagnet', base: 150, max: 5, desc: '+15%' },
  { key: 'greed', icon: '💰', label: 'upGreed', base: 120, max: 10, desc: '+10%' },
];

const COST_GROWTH = 1.7;

export function upgradeCost(u, lvl) {
  return Math.round(u.base * Math.pow(COST_GROWTH, lvl));
}

export function emptyUpgrades() {
  return Object.fromEntries(STAT_UPGRADES.map((u) => [u.key, 0]));
}

export const BASE_START_R = 20;

// Per-level effects are kept small so upgrades help without trivialising the boss.
export function statsFor(up) {
  return {
    startR: BASE_START_R + (up.size || 0) * 1.5,
    speedMul: 1 + (up.speed || 0) * 0.05,
    bonusTime: (up.time || 0) * 3,
    magnet: up.magnet || 0,
    coinMul: 1 + (up.greed || 0) * 0.1,
  };
}
