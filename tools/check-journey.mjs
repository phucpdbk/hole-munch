import assert from 'node:assert/strict';
import {emptyJourney,restoreJourney,recordJourney,claimReward,journeyCounts,REWARDS} from '../src/progression.js';
import {generateWorld} from '../src/world.js';
import {getLevel} from '../src/levels.js';
import {WorldEvent} from '../src/world-events.js';
import {SKINS} from '../src/cosmetics.js';
globalThis.window={addEventListener(){},innerWidth:390,innerHeight:844,devicePixelRatio:1};
globalThis.requestAnimationFrame=()=>{};
const {Game}=await import('../src/game.js');
const {emptyUpgrades}=await import('../src/upgrades.js');

const old=restoreJourney(undefined,55);
assert.equal(old.stamps.length,18,'Older progress restores landmarks without reset');
assert.equal(journeyCounts(old).medals,0,'Legacy saves must not invent challenge completions');
const journey=emptyJourney(),owned={skin:['classic'],fx:['dust'],trail:['none']};
assert.equal(claimReward(journey,owned,'comet18'),false);
assert.deepEqual(recordJourney(journey,{level:3,cleared:false,medals:['task']}),{medals:0,stamp:null});
assert.deepEqual(recordJourney(journey,{level:3,cleared:true,medals:['task','quick']}),{medals:2,stamp:'eiffel'});
assert.deepEqual(recordJourney(journey,{level:3,cleared:true,medals:['task','clean']}),{medals:1,stamp:null});
assert.equal(recordJourney(journey,{level:3,cleared:true,medals:['task','quick','clean']}).medals,0);
for(let n=1;n<=6;n++) recordJourney(journey,{level:n,cleared:true,medals:['task','quick','clean']});
assert.equal(journeyCounts(journey).medals,18);
assert(claimReward(journey,owned,'comet18'));assert(!claimReward(journey,owned,'comet18'));
assert.equal(owned.skin.filter(id=>id==='comet').length,1);
const restored=restoreJourney(JSON.parse(JSON.stringify(journey)),7);
assert.deepEqual(restored,journey,'Medals, stamps and claimed rewards survive a reload');
const malformed=restoreJourney({medals:{0:['task'],99:['task'],2:['bogus','task','task']},stamps:['eiffel','fake','eiffel'],claimed:['fake']},4);
assert.deepEqual(malformed.medals,{'2':['task']});assert.deepEqual(malformed.stamps,['eiffel']);assert.deepEqual(malformed.claimed,[]);
assert(SKINS.filter(s=>s.rewardOnly).every(s=>s.price!==0 && REWARDS.some(r=>r.item===s.id)));

for(let n=3;n<=5;n++) {
  const level=getLevel(n),world=generateWorld(level),event=new WorldEvent(world,level);
  const total=world.totalPts,food=world.objects.filter(o=>o.eventFood);
  const g={hole:{x:world.spawn.x,y:world.spawn.y,r:20}};
  assert.equal(food.length,12);assert(food.every(o=>o.hidden));
  event.update(event.trigger-0.01,g);assert.equal(event.state,'waiting');
  event.update(0.02,g);assert.equal(event.state,'active');
  if(n===5) {
    assert(food.every(o=>o.hidden));event.gate.falling=true;event.update(0.02,g);
    assert.equal(event.state,'opened');
  }
  assert(food.every(o=>!o.hidden));
  assert.equal(world.totalPts,total);assert.equal(world.objects.reduce((s,o)=>s+o.pts,0),total);
  for(let i=0;i<1000;i++) event.update(0.02,g);
  assert.equal(world.objects.filter(o=>o.eventFood).length,12,'Events cannot repeat-farm food');
}
const gardenWorld=generateWorld(getLevel(5)),garden=new WorldEvent(gardenWorld,getLevel(5));
garden.activate({hole:{...gardenWorld.spawn,r:20}});garden.update(9.1,{hole:{...gardenWorld.spawn,r:20}});
assert(garden.food.every(o=>!o.hidden),'Ignored gates auto-open before the timer ends');

const game=new Game({getContext:()=>({}),addEventListener(){}},{});
game.start(getLevel(9),emptyUpgrades());game.skipIntro();
const before=game.encounter.time;game.setPaused(true);game.update(2);assert.equal(game.encounter.time,before);game.setPaused(false);
game.bossEaten=true;game.bossCaughtAt=game.level.quickTarget;game.eatenPts=game.world.totalPts*0.91;game.objective.complete=true;
assert.deepEqual(game.results().medals,['task','quick','clean']);
game.bossCaughtAt=game.level.quickTarget+0.01;assert(!game.results().medals.includes('quick'));
const coins=game.results().coins;game.score+=999999;assert.equal(game.results().coins,coins,'Combo score cannot inflate upgrade income');
game.bossEaten=false;assert.deepEqual(game.results().medals,[],'Failed rounds cannot bank medals');
console.log('PASS: 3 event types, score conservation, gate fallback, pause, migration, medals and one-time cosmetic rewards');
