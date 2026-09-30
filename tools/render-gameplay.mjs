// Render the actual game HUD and boss phases at phone size for visual review.
import {createCanvas} from '@napi-rs/canvas';
import {mkdirSync,writeFileSync} from 'node:fs';
globalThis.window={devicePixelRatio:1,innerWidth:390,innerHeight:844,addEventListener(){}};
globalThis.document={documentElement:{}};
globalThis.requestAnimationFrame=()=>{};
globalThis.OffscreenCanvas=class {constructor(w,h){return createCanvas(w,h);}};
const {Game}=await import('../src/game.js');
const {getLevel}=await import('../src/levels.js');
const {emptyUpgrades}=await import('../src/upgrades.js');
const {setLanguage}=await import('../src/i18n.js');setLanguage('vi');
mkdirSync('tools/out',{recursive:true});
function setup(n) {
  const canvas=createCanvas(390,844);canvas.addEventListener=()=>{};
  const game=new Game(canvas,{});game.start(getLevel(n),emptyUpgrades());game.skipIntro();
  game.banner=null;game.startedMoving=true;return {game,canvas};
}
function shot(name,game,canvas) {
  game.render();writeFileSync(`tools/out/${name}.png`,canvas.toBuffer('image/png'));
}
const {game,canvas}=setup(2);
game.cam={x:game.hole.x,y:game.hole.y};game.zoom=0.85;
for(let i=0;i<12;i++) game.world.objects.push({kind:'cone',r:5,pts:2,x:game.hole.x+i%3,y:game.hole.y+i%4});
game.checkEating(0.02);game.updateObjective(0);game.update(0.05);
shot('gameplay-combo',game,canvas);
for(const [n,name] of [[14,'ufo'],[56,'crab']]) {
  const {game:g,canvas:c}=setup(n),b=g.world.boss;
  g.hole.x=b.x;g.hole.y=b.y+b.r*1.8;
  g.cam={x:b.x,y:b.y};g.zoom=390/(b.r*4.5);
  if(name==='ufo') {
    for(let i=0;i<6;i++) g.world.objects.push({kind:'car',r:12,w:30,h:16,pts:12,angle:0,color:'#ffd23f',x:b.x+90+i*8,y:b.y+50});
  }
  for(let i=0;i<(name==='ufo'?180:125);i++) g.behavior.update(0.02,g.hole);
  shot(`gameplay-${name}`,g,c);
}
for (const [n,name] of [[3,'candy'],[4,'parade'],[5,'garden']]) {
  const {game:g,canvas:c}=setup(n);
  g.encounter.activate(g);
  g.cam={x:g.encounter.anchor.x,y:g.encounter.anchor.y};g.zoom=1;
  shot(`event-${name}`,g,c);
  if(name==='garden') {
    g.encounter.gate.falling=true;g.encounter.update(0.02,g);
    shot('event-garden-open',g,c);
  }
}
console.log('Rendered combo, boss phases and all world events at 390 × 844');
