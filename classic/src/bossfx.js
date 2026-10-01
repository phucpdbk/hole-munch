// Celebration when the boss goes down: shockwave, confetti, fireworks, flash and shake.
const CONFETTI = ['#ff595e', '#ffca3a', '#8ac926', '#1982c4', '#6a4c93', '#f15bb5', '#ffffff'];
const TAU = Math.PI * 2;

export class BossFx {
  constructor() {
    this.reset();
  }

  reset() {
    this.bits = [];
    this.rings = [];
    this.pending = [];
    this.shake = 0;
    this.flash = 0;
  }

  // x, y, r in world units; zoom (screen px per world unit) keeps bits readable at any camera distance.
  burst(x, y, r, zoom) {
    const u = 1 / zoom;
    this.shake = 1;
    this.flash = 1;
    this.rings.push({ x, y, r, t: 0 }, { x, y, r, t: -0.15 });
    for (let i = 0; i < 140; i++) {
      const a = Math.random() * TAU;
      const sp = (250 + Math.random() * 550) * u;
      this.bits.push({
        kind: 'confetti', x, y, g: 420 * u,
        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 250 * u,
        rot: Math.random() * TAU, vr: (Math.random() - 0.5) * 12,
        size: (4 + Math.random() * 4) * u,
        color: CONFETTI[i % CONFETTI.length], life: 1.6 + Math.random() * 0.8, t: 0,
      });
    }
    for (let i = 0; i < 6; i++) {
      const a = Math.random() * TAU;
      const d = (90 + Math.random() * 130) * u;
      this.pending.push({ at: 0.15 + i * 0.22, x: x + Math.cos(a) * d, y: y + Math.sin(a) * d - 40 * u, u });
    }
  }

  firework(x, y, u) {
    const color = CONFETTI[Math.floor(Math.random() * 6)];
    for (let i = 0; i < 36; i++) {
      const a = (i / 36) * TAU;
      const sp = (260 + Math.random() * 90) * u;
      this.bits.push({ kind: 'spark', x, y, g: 200 * u, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, size: 3.5 * u, color, life: 0.9, t: 0 });
    }
    this.rings.push({ x, y, r: 30 * u, t: 0, thin: true, color });
  }

  get active() {
    return this.bits.length > 0 || this.rings.length > 0 || this.pending.length > 0 || this.shake > 0 || this.flash > 0;
  }

  update(dt) {
    this.shake = Math.max(0, this.shake - dt * 1.4);
    this.flash = Math.max(0, this.flash - dt * 2.5);
    for (const p of this.pending) {
      p.at -= dt;
      if (p.at <= 0) this.firework(p.x, p.y, p.u);
    }
    this.pending = this.pending.filter((p) => p.at > 0);
    for (const b of this.bits) {
      b.t += dt;
      const drag = b.kind === 'confetti' ? 1.8 : 2.5;
      b.vx *= 1 - dt * drag;
      b.vy = b.vy * (1 - dt * drag) + b.g * dt;
      if (b.kind === 'confetti') b.rot += b.vr * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    this.bits = this.bits.filter((b) => b.t < b.life);
    for (const g of this.rings) g.t += dt;
    this.rings = this.rings.filter((g) => g.t < 0.7);
  }

  // Screen-space camera offset for the shake.
  offset(time) {
    const s = this.shake * this.shake * 14;
    return { x: Math.sin(time * 71) * s, y: Math.cos(time * 57) * s };
  }

  drawWorld(ctx, zoom) {
    for (const g of this.rings) {
      if (g.t < 0) continue;
      const p = g.t / 0.7;
      ctx.strokeStyle = g.color || '#fff6c2';
      ctx.globalAlpha = 1 - p;
      ctx.lineWidth = (g.thin ? 3 : 10) / zoom * (1 - p * 0.6);
      ctx.beginPath();
      ctx.arc(g.x, g.y, g.r * (1 + p * (g.thin ? 3 : 2.5)), 0, TAU);
      ctx.stroke();
    }
    for (const b of this.bits) {
      const fade = Math.min(1, (b.life - b.t) * 3);
      ctx.globalAlpha = fade;
      ctx.fillStyle = b.color;
      if (b.kind === 'confetti') {
        ctx.save();
        ctx.translate(b.x, b.y);
        ctx.rotate(b.rot);
        ctx.scale(1, Math.abs(Math.cos(b.rot * 1.7)) + 0.2);
        ctx.fillRect(-b.size, -b.size * 0.5, b.size * 2, b.size);
        ctx.restore();
      } else {
        ctx.beginPath();
        ctx.arc(b.x, b.y, b.size * (1 - b.t / b.life * 0.5), 0, TAU);
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;
  }

  drawScreen(ctx, w, h) {
    if (this.flash <= 0) return;
    ctx.fillStyle = `rgba(255,255,240,${this.flash * this.flash * 0.7})`;
    ctx.fillRect(0, 0, w, h);
  }
}
