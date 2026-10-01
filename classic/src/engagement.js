export const COMBO_WINDOW = 1;
export const comboMultiplier = count => count >= 30 ? 3 : count >= 16 ? 2 : count >= 8 ? 1.5 : 1;

// One small lesson at a time. Later levels rotate optional replay challenges.
export function objectiveFor(level) {
  const lessons = [
    { key: 'missionSnack', kind: 'objects', goal: 12, hint: 'lessonMove' },
    { key: 'missionCombo', kind: 'combo', goal: 8, hint: 'lessonCombo' },
    { key: 'missionGrow', kind: 'growth', goal: 2, hint: 'lessonGrow' },
    { key: 'missionCars', kind: 'cars', goal: 6, hint: 'lessonCars' },
    { key: 'missionBoss', kind: 'boss', goal: 1, hint: 'lessonBoss' },
  ];
  const challenge = level <= 5 ? lessons[level - 1] : [
    { key: 'missionCombo', kind: 'combo', goal: 20 },
    { key: 'missionCars', kind: 'cars', goal: 12 },
    { key: 'missionSnack', kind: 'objects', goal: 80 },
  ][(level - 6) % 3];
  return { ...challenge, progress: 0, complete: false, celebration: 0 };
}

export function objectiveProgress(objective, game) {
  return Math.min(objective.goal, {
    objects: game.swallowed,
    combo: game.bestCombo,
    growth: Math.floor(game.hole.targetR / game.hole.startR * 10) / 10,
    cars: game.carsEaten,
    boss: game.bossEaten ? 1 : 0,
  }[objective.kind]);
}
