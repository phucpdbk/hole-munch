// One encounter per run. Event food belongs to the original map budget, so stars
// and boss size do not change when a gate opens or a candy truck arrives.
export class WorldEvent {
  constructor(world, level) {
    this.world = world;
    this.kind = level.number < 3 ? null : ['candy', 'parade', 'garden'][(level.number - 3) % 3];
    this.state = 'waiting';
    this.time = 0;
    this.activeTime = 0;
    this.noticeTime = 0;
    this.anchor = null;
    this.food = world.objects.filter(o => o.eventFood);
    this.trigger = 10 + level.number % 4 * 2;
    this.gate = null;
  }

  activate(game) {
    const h = game.hole, size = this.world.size;
    const clamp = v => Math.max(100, Math.min(size - 100, v));
    this.anchor = { x: clamp(h.x + Math.min(110, h.r * 1.1 + 35)), y: clamp(h.y - 50) };
    if (this.kind === 'garden') {
      this.gate = { kind: 'eventGate', x: this.anchor.x, y: this.anchor.y,
        r: Math.max(12, Math.min(30, h.r * 0.62)), pts: 0, angle: 0, eventGate: true };
      this.world.objects.push(this.gate);
    } else this.releaseFood();
    this.noticeTime = 4;
    this.state = 'active';
  }

  releaseFood() {
    const size = this.world.size;
    this.food.forEach((o, i) => {
      if (o.eaten || o.falling) return;
      const angle = i * 2.4;
      const spread = this.kind === 'parade' ? i * 20 - 100 : 24 + Math.sqrt(i) * 17;
      o.x = Math.max(o.r, Math.min(size - o.r, this.anchor.x + (this.kind === 'parade' ? spread : Math.cos(angle) * spread)));
      o.y = Math.max(o.r, Math.min(size - o.r, this.anchor.y + (this.kind === 'parade' ? 0 : Math.sin(angle) * spread)));
      o.hidden = false;
      if (this.kind === 'parade') { o.vx = 35; o.vy = 0; }
    });
  }

  update(dt, game) {
    if (!this.kind) return;
    this.time += dt;
    this.noticeTime = Math.max(0, this.noticeTime - dt);
    if (this.state === 'waiting' && this.time >= this.trigger) this.activate(game);
    if (this.state !== 'active') return;
    this.activeTime += dt;
    // Auto-open eventually so ignoring the gate cannot make completion impossible.
    if (this.kind === 'garden' && (this.gate.falling || this.gate.eaten || this.activeTime >= 9)) {
      this.releaseFood();
      this.gate.eaten = true;
      this.state = 'opened'; this.noticeTime = 3;
    }
    if (this.activeTime > 8 && this.kind === 'parade') {
      for (const o of this.food) { o.vx = 0; o.vy = 0; }
      this.state = 'opened';
    }
  }

  get title() { return this.state === 'opened' && this.kind === 'garden' ? 'eventGardenOpen' : `event_${this.kind}`; }

  draw(ctx) {
    if (!this.anchor || this.state === 'waiting') return;
    const {x,y} = this.anchor;
    ctx.save();
    if (this.kind === 'garden') {
      ctx.fillStyle = '#4f9a86';ctx.strokeStyle='#fce298';ctx.lineWidth=4;
      ctx.beginPath();ctx.ellipse(x,y,112,83,0,0,Math.PI*2);ctx.fill();ctx.stroke();
      for(let i=0;i<12;i++) {
        const a=i*Math.PI/6;ctx.fillStyle=i%2?'#ffb4d6':'#fff0ac';
        ctx.beginPath();ctx.arc(x+Math.cos(a)*101,y+Math.sin(a)*74,5,0,Math.PI*2);ctx.fill();
      }
    } else if (this.kind === 'candy' && this.activeTime < 7) {
      const exit = Math.max(0,this.activeTime-3)*65;
      ctx.translate(x-90-exit,y-45);ctx.fillStyle='#ec73b0';ctx.fillRect(-28,-16,56,32);
      ctx.fillStyle='#80eced';ctx.fillRect(9,-12,15,12);
      ctx.fillStyle='#ffefba';ctx.fillRect(-22,-10,22,20);
      ctx.fillStyle='#29344c';for(const px of [-17,17]) {ctx.beginPath();ctx.arc(px,17,7,0,Math.PI*2);ctx.fill();}
      ctx.fillStyle='#ef69a8';ctx.beginPath();ctx.arc(-11,0,7,0,Math.PI*2);ctx.fill();
    }
    ctx.restore();
  }
}
