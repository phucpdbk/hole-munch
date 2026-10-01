import { audio } from './audio.js';

const TAU = Math.PI * 2;
const rnd = (a, b) => a + Math.random() * (b - a);

export const WEATHER_ICONS = {
  clear: '',
  sun: '☀️',
  rain: '🌧️',
  snow: '❄️',
  wind: '💨',
  fog: '🌫️',
  storm: '⛈️',
};

export class Weather {
  constructor(type = 'clear', power = 1) {
    this.type = type;
    this.power = power;
    this.t = 0;
    this.windAngle = rnd(0, TAU);
    this.windTarget = this.windAngle;
    this.windTimer = rnd(4, 7);
    this.drops = [];
    this.flash = 0;
    this.strike = null;
    this.strikeTimer = 5;
  }

  get rainy() {
    return this.type === 'rain' || this.type === 'storm';
  }

  get windy() {
    return this.type === 'wind' || this.type === 'storm';
  }

  // Multiplier on the hole's top speed.
  get speedMul() {
    if (this.type === 'rain') return 1 - 0.14 * this.power;
    if (this.type === 'storm') return 1 - 0.1 * this.power;
    return 1;
  }

  // How quickly the hole's velocity catches up to input; lower = icier.
  get grip() {
    return this.type === 'snow' ? 2.4 / this.power : Infinity;
  }

  // Radius lost per second to the heat. Capped so big late-game holes aren't crippled.
  shrinkPerSec(r) {
    return this.type === 'sun' ? Math.min(r * 0.006, 0.45) * this.power : 0;
  }

  windForce(speed) {
    if (!this.windy) return { x: 0, y: 0 };
    const s = speed * (this.type === 'wind' ? 0.38 : 0.25) * this.power;
    return { x: Math.cos(this.windAngle) * s, y: Math.sin(this.windAngle) * s };
  }

  updateGameplay(dt, game) {
    if (this.windy) {
      this.windTimer -= dt;
      if (this.windTimer <= 0) {
        this.windTimer = rnd(4, 7);
        this.windTarget = this.windAngle + rnd(-2.2, 2.2);
      }
      this.windAngle += (this.windTarget - this.windAngle) * Math.min(1, dt * 0.8);
    }

    if (this.type !== 'storm') return;
    const h = game.hole;
    if (!this.strike) {
      this.strikeTimer -= dt;
      if (this.strikeTimer <= 0) {
        const a = rnd(0, TAU);
        const d = rnd(0, h.r * 1.5);
        this.strike = { x: h.x + Math.cos(a) * d, y: h.y + Math.sin(a) * d, r: Math.max(70, h.r * 1.4), t: 0, warn: 1.4, hit: false };
        audio.warn();
      }
      return;
    }
    const s = this.strike;
    s.t += dt;
    if (!s.hit && s.t >= s.warn) {
      s.hit = true;
      this.flash = 1;
      audio.thunder();
      if (Math.hypot(h.x - s.x, h.y - s.y) < s.r + h.r * 0.3) {
        h.targetR = Math.max(h.startR, h.targetR * 0.88);
        game.floaters.push({ x: h.x, y: h.y - h.r, text: '-12%', t: 0, big: true, bad: true });
      }
    }
    if (s.t >= s.warn + 0.35) {
      this.strike = null;
      this.strikeTimer = rnd(5, 8) / this.power;
    }
  }

  updateVisual(dt, w, h) {
    this.t += dt;
    this.flash = Math.max(0, this.flash - dt * 2.5);
    const target = this.targetDropCount();
    while (this.drops.length < target) this.drops.push(this.newDrop(w, h, true));
    if (this.drops.length > target) this.drops.length = target;
    const wind = this.windy ? Math.cos(this.windAngle) : 0;
    for (const d of this.drops) {
      if (this.type === 'snow') {
        d.x += (Math.sin(this.t + d.phase) * 20 + wind * 60) * dt;
        d.y += d.speed * 0.25 * dt;
      } else if (this.type === 'wind') {
        d.x += Math.cos(this.windAngle) * d.speed * 1.6 * dt;
        d.y += Math.sin(this.windAngle) * d.speed * 1.6 * dt;
      } else {
        d.x += wind * d.speed * 0.35 * dt;
        d.y += d.speed * dt;
      }
      if (d.y > h + 20 || d.y < -40 || d.x < -60 || d.x > w + 60) Object.assign(d, this.newDrop(w, h, false));
    }
  }

  targetDropCount() {
    const p = this.power;
    switch (this.type) {
      case 'rain':
        return Math.min(220, Math.round(110 * p));
      case 'storm':
        return Math.min(260, Math.round(150 * p));
      case 'snow':
        return Math.min(180, Math.round(90 * p));
      case 'wind':
        return Math.min(60, Math.round(28 * p));
      default:
        return 0;
    }
  }

  newDrop(w, h, anywhere) {
    const d = { x: rnd(-40, w + 40), y: anywhere ? rnd(0, h) : -20, speed: rnd(500, 800), len: rnd(10, 20), phase: rnd(0, TAU), size: rnd(1.5, 3.5) };
    if (this.type === 'wind' && !anywhere) {
      // Respawn on the upwind edge so streaks sweep across the screen.
      const cx = Math.cos(this.windAngle);
      const cy = Math.sin(this.windAngle);
      if (Math.abs(cx) > Math.abs(cy)) {
        d.x = cx > 0 ? -50 : w + 50;
        d.y = rnd(0, h);
      } else {
        d.y = cy > 0 ? -30 : h + 10;
        d.x = rnd(0, w);
      }
    }
    return d;
  }

  // World-space: lightning warning ring and bolt.
  drawWorld(ctx, zoom) {
    const s = this.strike;
    if (!s) return;
    if (!s.hit) {
      const k = s.t / s.warn;
      ctx.strokeStyle = `rgba(255,${Math.floor(220 - k * 180)},60,${0.5 + 0.5 * Math.abs(Math.sin(s.t * 12))})`;
      ctx.lineWidth = 5 / zoom;
      ctx.setLineDash([14 / zoom, 10 / zoom]);
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, TAU);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = `rgba(255,80,40,${0.12 + k * 0.2})`;
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r * k, 0, TAU);
      ctx.fill();
    } else {
      ctx.strokeStyle = '#fffbe0';
      ctx.lineWidth = 6 / zoom;
      ctx.shadowColor = '#ffe066';
      ctx.shadowBlur = 25;
      ctx.beginPath();
      let x = s.x + rnd(-30, 30);
      let y = s.y - 900;
      ctx.moveTo(x, y);
      while (y < s.y) {
        y += rnd(60, 110);
        x += rnd(-40, 40);
        ctx.lineTo(x, Math.min(y, s.y));
      }
      ctx.lineTo(s.x, s.y);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }
  }

  // Screen-space overlays drawn over the world, under the HUD.
  drawScreen(ctx, w, h, holeX, holeY, holeR) {
    switch (this.type) {
      case 'sun': {
        const pulse = 0.22 + Math.sin(this.t * 1.5) * 0.04;
        const g = ctx.createRadialGradient(w, 0, 0, w, 0, Math.max(w, h) * 0.9);
        g.addColorStop(0, `rgba(255,220,120,${pulse + 0.15})`);
        g.addColorStop(1, 'rgba(255,140,40,0)');
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = 'rgba(255,150,50,0.07)';
        ctx.fillRect(0, 0, w, h);
        break;
      }
      case 'fog': {
        const inner = holeR * 2 + 90 / this.power;
        const g = ctx.createRadialGradient(holeX, holeY, inner, holeX, holeY, inner * 2);
        g.addColorStop(0, 'rgba(190,190,210,0)');
        g.addColorStop(1, `rgba(190,190,210,${Math.min(0.97, 0.88 + 0.05 * this.power)})`);
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, w, h);
        break;
      }
      case 'storm':
        ctx.fillStyle = 'rgba(10,20,40,0.3)';
        ctx.fillRect(0, 0, w, h);
        break;
      case 'rain':
        ctx.fillStyle = 'rgba(40,60,90,0.14)';
        ctx.fillRect(0, 0, w, h);
        break;
      case 'snow':
        ctx.fillStyle = 'rgba(220,235,255,0.12)';
        ctx.fillRect(0, 0, w, h);
        break;
    }

    if (this.rainy) {
      const slant = this.windy ? Math.cos(this.windAngle) * 0.35 : 0.08;
      ctx.strokeStyle = 'rgba(200,220,255,0.55)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      for (const d of this.drops) {
        ctx.moveTo(d.x, d.y);
        ctx.lineTo(d.x - slant * d.len, d.y - d.len);
      }
      ctx.stroke();
    } else if (this.type === 'snow') {
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      for (const d of this.drops) {
        ctx.beginPath();
        ctx.arc(d.x, d.y, d.size, 0, TAU);
        ctx.fill();
      }
    } else if (this.type === 'wind') {
      const cx = Math.cos(this.windAngle);
      const cy = Math.sin(this.windAngle);
      ctx.strokeStyle = 'rgba(255,255,255,0.4)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (const d of this.drops) {
        const l = d.len * 4;
        ctx.moveTo(d.x, d.y);
        ctx.lineTo(d.x - cx * l, d.y - cy * l);
      }
      ctx.stroke();
    }

    if (this.flash > 0) {
      ctx.fillStyle = `rgba(255,255,255,${this.flash * 0.6})`;
      ctx.fillRect(0, 0, w, h);
    }
  }

  // Small arrow showing wind direction, drawn in the HUD.
  drawWindIndicator(ctx, x, y) {
    if (!this.windy) return;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(this.windAngle);
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-12, 0);
    ctx.lineTo(12, 0);
    ctx.moveTo(5, -6);
    ctx.lineTo(12, 0);
    ctx.lineTo(5, 6);
    ctx.stroke();
    ctx.restore();
  }
}
