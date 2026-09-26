import assert from 'node:assert/strict';
globalThis.window = {addEventListener(){},innerWidth:390,innerHeight:844,devicePixelRatio:1};
globalThis.requestAnimationFrame = () => {};
const {Game} = await import('../src/game.js');
const {getLevel} = await import('../src/levels.js');
const {emptyUpgrades} = await import('../src/upgrades.js');
const {BossBehavior} = await import('../src/boss-behavior.js');
const {comboMultiplier,COMBO_WINDOW} = await import('../src/engagement.js');
const {generateWorld} = await import('../src/world.js');

const create = n => {
  const game = new Game({getContext:()=>({}),addEventListener(){}},{});
  game.start(getLevel(n),emptyUpgrades());game.skipIntro();return game;
};
const tick = (game, seconds) => {for(let t=0;t<seconds;t+=0.02) game.update(0.02);};
const food = (x,y) => ({kind:'cone',r:5,pts:2,x,y,vx:0,vy:0,angle:0});

const g=create(1),timer=g.timeLeft;
const snack=food(g.hole.x,g.hole.y);
g.world.objects=[snack,g.world.boss];g.world.totalPts=2;
tick(g,3);
assert.equal(g.timeLeft,timer,'First lesson must wait for movement');
assert.equal(g.swallowed,0,'Waiting must not farm moving traffic');
g.input.keys.add('d');g.update(0.02);g.input.keys.clear();
assert(g.timeLeft<timer);assert.equal(g.swallowed,1);
g.world.objects=[g.world.boss];
for(let i=0;i<19;i++) {
  g.world.objects.push(food(g.hole.x,g.hole.y));g.checkEating(0.02);
}
assert.equal(g.bestCombo,20);assert.equal(comboMultiplier(g.combo),3);
assert.equal(g.eatenPts,40,'Combo must not inflate completion percentage');
assert(g.score>g.eatenPts,'Combos should award bonus score');
const beforeReward=g.timeLeft;g.updateObjective(0);
assert.equal(g.timeLeft,beforeReward+5);g.updateObjective(1);
assert.equal(g.timeLeft,beforeReward+5,'Challenge reward is one-time');
g.setPaused(true);const beforePause=g.comboTime;tick(g,3);
assert.equal(g.comboTime,beforePause);g.setPaused(false);
g.world.objects=[g.world.boss];tick(g,COMBO_WINDOW+0.1);
assert.equal(g.combo,0);assert.equal(g.bestCombo,20);
g.state='offer';g.comboTime=1;tick(g,1);assert.equal(g.comboTime,1);
g.start(getLevel(2),emptyUpgrades());
assert.equal(g.bestCombo,0);assert.equal(g.objective.complete,false);assert.equal(g.ripples.length,0);

for(let n=1;n<=5;n++) {
  const world=generateWorld(getLevel(n));
  const trail=world.objects.filter(o=>o.starter);
  assert(trail.length>=24);
  assert(trail.some(o=>o.r<17));
  assert.equal(world.totalPts,world.objects.reduce((sum,o)=>sum+o.pts,0));
  if(n===4) assert.equal(trail.filter(o=>o.kind==='car').length,6);
}

function arena(type) {
  const boss={bossType:type,r:50,x:500,y:500,isBoss:true,pts:0};
  const objects=[boss,...Array.from({length:10},(_,i)=>food(540+i*3,500))];
  const world={boss,objects,size:1000};return {world,behavior:new BossBehavior(world),hole:{x:450,y:500,r:75}};
}
const duck=arena('duck');
for(let i=0;i<6000;i++) duck.behavior.update(0.02,duck.hole);
assert(duck.behavior.drops>0 && duck.behavior.drops<=8);
assert(Math.abs(duck.world.boss.x-500)<=140);
assert(duck.world.objects.filter(o=>o.bonusFood).every(o=>o.pts===0));
const crab=arena('crab');const initial=crab.world.objects[1].x;
for(let i=0;i<105;i++) crab.behavior.update(0.02,crab.hole);
assert.equal(crab.behavior.phase,'warn');assert.equal(crab.world.objects[1].x,initial);
for(let i=0;i<65;i++) crab.behavior.update(0.02,crab.hole);
assert(crab.world.objects[1].x>initial,'Claw sweep moves snacks after warning');
const ufo=arena('ufo');const total=ufo.world.objects.reduce((s,o)=>s+o.pts,0);
for(let i=0;i<180;i++) ufo.behavior.update(0.02,ufo.hole);
assert.equal(ufo.behavior.phase,'beam');assert.equal(ufo.behavior.cargo.length,6);
assert(ufo.behavior.cargo.every(o=>o.abducted && o.lift>0));
ufo.world.boss.falling=true;ufo.behavior.update(0.02,ufo.hole);
assert(ufo.world.objects.every(o=>!o.abducted && !o.lift));
assert.equal(ufo.world.objects.reduce((s,o)=>s+o.pts,0),total);
assert.equal(ufo.world.objects.length,11);
console.log('PASS: combos, scoring, timeout, pause, retry, reward, 5 starter routes and 3 boss behaviors');
