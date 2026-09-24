// Time-free feasibility check: eat objects smallest-first and report how much of the
// map a hole could ever reach, and how big it must get to swallow the largest props.
// Usage: node tools/size-ladder.mjs [levels=10] [grow=level default]
globalThis.window = { addEventListener() {}, innerWidth: 1024, innerHeight: 576, devicePixelRatio: 1 };

const { generateWorld, EAT_RATIO } = await import('../src/world.js');
const { getLevel } = await import('../src/levels.js');
const { BASE_START_R: START_R } = await import('../src/upgrades.js');

const LEVELS = Number(process.argv[2]) || 10;
const GROW_OVERRIDE = Number(process.argv[3]) || 0;

console.log('lvl | grow | objs | pts by kind (top) | maxPropR | reach% | finalR | boss@%');
for (let n = 1; n <= LEVELS; n++) {
  const level = getLevel(n);
  const grow = GROW_OVERRIDE || level.growth;
  const world = generateWorld(level);
  const byKind = {};
  for (const o of world.objects) byKind[o.kind] = (byKind[o.kind] || 0) + o.pts;
  const top = Object.entries(byKind)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([k, p]) => `${k} ${Math.round((p / world.totalPts) * 100)}%`)
    .join(', ');
  const sorted = [...world.objects].sort((a, b) => a.r - b.r);
  let r = START_R;
  let eaten = 0;
  let bossAt = null;
  for (const o of sorted) {
    if (o.r > r * EAT_RATIO) break;
    r = Math.sqrt(r * r + o.r * o.r * grow);
    eaten += o.pts;
    if (o.isBoss) bossAt = eaten / world.totalPts;
  }
  const maxProp = Math.max(...world.objects.filter((o) => !o.isBoss).map((o) => o.r));
  console.log(
    `${String(n).padStart(3)} | ${grow.toFixed(2)} | ${String(world.objects.length).padStart(4)} | ${top.padEnd(34)} | ${maxProp.toFixed(0).padStart(4)} | ${((eaten / world.totalPts) * 100).toFixed(0).padStart(5)}% | ${r.toFixed(0).padStart(5)} | ${bossAt === null ? '  -' : (bossAt * 100).toFixed(0) + '%'}`
  );
}
