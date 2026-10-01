import { THEMES, getLevel } from './levels.js';

export const MEDAL_IDS = ['task', 'quick', 'clean'];
export const DESTINATIONS = [...new Map(THEMES.filter(t => t.landmark).map(t => [t.boss, t])).values()];
export const REWARDS = [
  { id: 'confetti6', track: 'medals', need: 6, slot: 'fx', item: 'confetti' },
  { id: 'comet18', track: 'medals', need: 18, slot: 'skin', item: 'comet' },
  { id: 'rainbow36', track: 'medals', need: 36, slot: 'trail', item: 'rainbow' },
  { id: 'atlas6', track: 'stamps', need: 6, slot: 'skin', item: 'atlas' },
  { id: 'crown24', track: 'stamps', need: 24, slot: 'skin', item: 'crown' },
];

export function emptyJourney() { return { medals: {}, stamps: [], claimed: [] }; }
export function journeyCounts(journey) {
  return { medals: Object.values(journey.medals).reduce((n, ids) => n + ids.length, 0), stamps: journey.stamps.length };
}

export function restoreJourney(data, unlockedLevel) {
  const journey = emptyJourney();
  const landmarks = new Set(DESTINATIONS.map(t => t.boss));
  journey.stamps = [...new Set((Array.isArray(data?.stamps) ? data.stamps : []).filter(id => landmarks.has(id)))];
  for (const [n, ids] of Object.entries(data?.medals || {})) {
    if (!/^\d+$/.test(n) || Number(n) < 1 || Number(n) >= unlockedLevel || !Array.isArray(ids)) continue;
    journey.medals[n] = [...new Set(ids.filter(id => MEDAL_IDS.includes(id)))];
  }
  // Previous versions stored a sequential unlocked level, enough to restore stamps.
  for (let n = 1; n < Math.min(unlockedLevel, THEMES.length + 1); n++) {
    const theme = getLevel(n).theme;
    if (theme.landmark && !journey.stamps.includes(theme.boss)) journey.stamps.push(theme.boss);
  }
  journey.claimed = [...new Set((Array.isArray(data?.claimed) ? data.claimed : []).filter(id => REWARDS.some(r => r.id === id)))];
  return journey;
}

// Called once per result; repeated/replayed results cannot award the same medal twice.
export function recordJourney(journey, result) {
  if (!result.cleared) return { medals: 0, stamp: null };
  const held = journey.medals[result.level] ||= [];
  let medals = 0;
  for (const id of result.medals || []) {
    if (MEDAL_IDS.includes(id) && !held.includes(id)) { held.push(id); medals++; }
  }
  const theme = getLevel(result.level).theme;
  let stamp = null;
  if (theme.landmark && !journey.stamps.includes(theme.boss)) {
    stamp = theme.boss; journey.stamps.push(stamp);
  }
  return { medals, stamp };
}

export function claimReward(journey, owned, id) {
  const reward = REWARDS.find(r => r.id === id);
  if (!reward || journey.claimed.includes(id) || journeyCounts(journey)[reward.track] < reward.need) return false;
  const items = owned[reward.slot];
  if (!items) return false;
  if (!items.includes(reward.item)) items.push(reward.item);
  journey.claimed.push(id);
  return true;
}
