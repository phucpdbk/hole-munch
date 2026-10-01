// Boss tricks only run during active play. They relocate food; they never remove it
// from the map or change its score, so every original star remains obtainable.
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
export class BossBehavior {
  constructor(world) {
    this.world = world;
    this.boss = world.boss;
    this.clock = 0;
    this.phase = 'rest';
    this.phaseTime = 2;
    this.drops = 0;
    this.cargo = [];
    this.home = { x: this.boss.x, y: this.boss.y };
  }

  get hint() {
    return { duck: 'trickDuck', crab: 'trickCrab', ufo: 'trickUfo' }[this.boss.bossType];
  }

  release() {
    for (const o of this.cargo) {
      o.lift = 0;
      o.abducted = false;
    }
    this.cargo = [];
  }

  update(dt, hole) {
    const b = this.boss;
    if (b.eaten || b.falling) { this.release(); return; }
    this.clock += dt;
    this.phaseTime -= dt;
    const dx = b.x - hole.x, dy = b.y - hole.y;
    const distance = Math.hypot(dx, dy);
    if (b.bossType === 'duck') {
      // Short sprints followed by a long breather, always slower than the hole.
      if (this.phase === 'rest' && this.phaseTime <= 0 && distance < b.r + hole.r + 150) {
        this.phase = 'dash'; this.phaseTime = 0.85;
        this.dir = { x: dx / (distance || 1), y: dy / (distance || 1) };
        if (!distance) this.dir.x = 1;
        if (this.drops < 8) {
          this.world.objects.push({ kind: 'duckling', x: b.x, y: b.y + b.r * 0.7,
            r: 10, pts: 0, bonusFood: true, angle: 0, vx: 0, vy: 0, fallT: 0 });
          this.drops++;
        }
      }
      if (this.phase === 'dash') {
        b.x += this.dir.x * 80 * dt; b.y += this.dir.y * 80 * dt;
        if (this.phaseTime <= 0) { this.phase = 'rest'; this.phaseTime = 3; }
      }
    } else if (b.bossType === 'crab') {
      if (this.phaseTime <= 0) {
        this.phase = this.phase === 'rest' ? 'warn' : this.phase === 'warn' ? 'sweep' : 'rest';
        this.phaseTime = { warn: 1.1, sweep: 0.9, rest: 3 }[this.phase];
      }
      if (this.phase === 'sweep') {
        b.x += Math.sin(this.clock * 1.4) * 95 * dt;
        for (const o of this.world.objects) {
          if (o.isBoss || o.eaten || o.falling || o.hidden || o.r > 24) continue;
          if (Math.hypot(o.x - b.x, o.y - b.y) > b.r + 100) continue;
          const side = o.x < b.x ? -1 : 1;
          o.x = clamp(o.x + side * 125 * dt, o.r, this.world.size - o.r);
        }
      }
    } else if (b.bossType === 'ufo') {
      if (this.phaseTime <= 0) {
        if (this.phase === 'rest') { this.phase = 'warn'; this.phaseTime = 1.2; }
        else if (this.phase === 'warn') {
          this.phase = 'beam'; this.phaseTime = 2.4;
          this.cargo = this.world.objects.filter(o => !o.isBoss && !o.eaten && !o.falling && !o.hidden && o.r <= 24
            && Math.hypot(o.x - b.x, o.y - b.y) < b.r + 230)
            .sort((a, z) => Math.hypot(a.x-b.x,a.y-b.y)-Math.hypot(z.x-b.x,z.y-b.y)).slice(0, 6);
          for (const o of this.cargo) o.abducted = true;
        } else { this.release(); this.phase = 'rest'; this.phaseTime = 3.5; }
      }
      this.cargo.forEach((o, i) => {
        if (o.eaten || o.falling) { o.lift = 0; o.abducted = false; return; }
        const angle = this.clock * 0.9 + i * Math.PI / 3;
        const radius = b.r + 65;
        const tx = b.x + Math.cos(angle) * radius, ty = b.y + Math.sin(angle) * radius;
        o.x += (tx - o.x) * Math.min(1, dt * 1.8);
        o.y += (ty - o.y) * Math.min(1, dt * 1.8);
        o.lift = Math.sin(Math.min(1, (2.4 - this.phaseTime) / 0.4) * Math.PI / 2) * 18;
      });
    }
    // All movement is confined to the central arena; bosses cannot flee off-map.
    b.x = clamp(b.x, this.home.x - 140, this.home.x + 140);
    b.y = clamp(b.y, this.home.y - 140, this.home.y + 140);
  }

  draw(ctx) {
    const b = this.boss;
    if (b.eaten || b.falling || !this.hint) return;
    ctx.save();
    if (this.phase === 'warn' || this.phase === 'sweep') {
      ctx.strokeStyle = '#ffba62'; ctx.fillStyle = 'rgba(255,165,64,0.12)';
      ctx.lineWidth = 4; ctx.setLineDash([12, 10]);
      const radius = b.r + (b.bossType === 'ufo' ? 230 : 100);
      ctx.beginPath(); ctx.arc(b.x,b.y,radius,0,Math.PI*2);ctx.fill();ctx.stroke();
    }
    if (this.phase === 'beam') {
      for (const o of this.cargo) {
        if(o.eaten || o.falling) continue;
        ctx.strokeStyle = 'rgba(122,255,223,0.65)';ctx.lineWidth = 3;
        ctx.beginPath();ctx.moveTo(b.x,b.y);ctx.lineTo(o.x,o.y-(o.lift||0));ctx.stroke();
      }
    }
    if (b.bossType === 'duck' && this.phase === 'dash') {
      ctx.strokeStyle = '#fff1a7';ctx.lineWidth = 4;
      for(let i=0;i<3;i++) {
        const x=b.x-this.dir.x*(b.r+12+i*12),y=b.y-this.dir.y*(b.r+12+i*12);
        ctx.beginPath();ctx.moveTo(x-8,y-5);ctx.lineTo(x+8,y+5);ctx.stroke();
      }
    }
    ctx.restore();
  }
}
