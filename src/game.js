import { generateWorld, updateObjects, drawGround, drawObject, EAT_RATIO } from './world.js';
import { audio } from './audio.js';
import { t } from './i18n.js';
import { statsFor } from './upgrades.js';
import { drawSkinInside, drawSkinRim, emitEatFx, emitTrail, updateParticles, drawParticles } from './cosmetics.js';
import { Weather, WEATHER_ICONS } from './weather.js';
import { BossFx } from './bossfx.js';
import { BossBehavior } from './boss-behavior.js';
import { COMBO_WINDOW, comboMultiplier, objectiveFor, objectiveProgress } from './engagement.js';
import { WorldEvent } from './world-events.js';
import { World3D } from './world3d.js';

export const STAR2_PCT = 0.75;
export const STAR3_PCT = 0.9;
const FALL_TIME = 0.45;
const BASE_SPEED = 170;
const JOY_RADIUS = 60;
const TRAIL_INTERVAL = 0.025;
const DEFAULT_LOOK = { skin: 'classic', fx: 'dust', trail: 'none' };
// Level intro: the camera holds on the boss, then pans back to the hole.
const INTRO_TIME = 2.8;
const INTRO_HOLD = 0.6;
const BOSS_SLOWMO = 0.5;
const MOVE_KEYS = new Set(['w', 'a', 's', 'd', 'arrowup', 'arrowleft', 'arrowdown', 'arrowright']);

export class Game {
  constructor(canvas, callbacks) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.view3d = World3D.create(canvas);
    this.cb = callbacks;
    this.state = 'idle';
    this.paused = false;
    this.time = 0;
    this.world = null;
    this.input = { active: false, sx: 0, sy: 0, dx: 0, dy: 0, keys: new Set() };
    this.floaters = [];
    this.particles = [];
    this.weather = new Weather();
    this.fx = new BossFx();
    this.look = { ...DEFAULT_LOOK };
    this.lastTs = 0;

    this.resize();
    window.addEventListener('resize', () => this.resize());
    this.bindInput();
    requestAnimationFrame((ts) => this.frame(ts));
  }

  resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.dpr = dpr;
    this.w = window.innerWidth;
    this.h = window.innerHeight;
    this.canvas.width = Math.floor(this.w * dpr);
    this.canvas.height = Math.floor(this.h * dpr);
    this.view3d?.resize(this.w, this.h, dpr);
  }

  bindInput() {
    const c = this.canvas;
    c.addEventListener('pointerdown', (e) => {
      audio.unlock();
      if (this.state === 'intro') this.skipIntro();
      this.input.active = true;
      this.input.sx = e.clientX;
      this.input.sy = e.clientY;
      this.input.dx = 0;
      this.input.dy = 0;
      c.setPointerCapture?.(e.pointerId);
    });
    c.addEventListener('pointermove', (e) => {
      if (!this.input.active) return;
      let dx = e.clientX - this.input.sx;
      let dy = e.clientY - this.input.sy;
      const len = Math.hypot(dx, dy);
      // Drag the joystick anchor along so direction changes feel immediate.
      if (len > JOY_RADIUS) {
        this.input.sx += (dx / len) * (len - JOY_RADIUS);
        this.input.sy += (dy / len) * (len - JOY_RADIUS);
        dx = e.clientX - this.input.sx;
        dy = e.clientY - this.input.sy;
      }
      this.input.dx = dx;
      this.input.dy = dy;
    });
    const end = () => {
      this.input.active = false;
      this.input.dx = 0;
      this.input.dy = 0;
    };
    c.addEventListener('pointerup', end);
    c.addEventListener('pointercancel', end);
    window.addEventListener('keydown', (e) => {
      if (this.state === 'intro') this.skipIntro();
      this.input.keys.add(e.key.toLowerCase());
    });
    window.addEventListener('keyup', (e) => this.input.keys.delete(e.key.toLowerCase()));
  }

  setLook(look) {
    this.look = { ...DEFAULT_LOOK, ...look };
  }

  start(level, upgrades, look) {
    this.level = level;
    this.world = generateWorld(level);
    this.behavior = new BossBehavior(this.world);
    this.encounter = new WorldEvent(this.world, level);
    this.elapsedPlay = 0;
    this.bossCaughtAt = null;
    this.combo = 0;
    this.comboTime = 0;
    this.bestCombo = 0;
    this.swallowed = 0;
    this.carsEaten = 0;
    this.objective = objectiveFor(level.number);
    this.startedMoving = level.number !== 1;
    this.playTime = 0;
    this.growCooldown = 0;
    this.growthMilestone = 1;
    this.ripples = [];
    this.bitePulse = 0;
    this.scorePop = 0;
    this.scorePopTime = 0;
    this.input.active = false;
    this.input.dx = this.input.dy = 0;
    this.input.keys.clear();
    if (look) this.setLook(look);
    this.stats = statsFor(upgrades);
    const startR = this.stats.startR;
    this.particles = [];
    this.trailT = 0;
    this.hole = {
      x: this.world.spawn.x,
      y: this.world.spawn.y,
      r: startR,
      targetR: startR,
      startR,
      tier: 0,
      pulse: 0,
      vx: 0,
      vy: 0,
    };
    this.weather = new Weather(level.weather, level.weatherPower);
    this.speedMul = this.stats.speedMul;
    this.timeLeft = level.duration + this.stats.bonusTime;
    this.bossAnnounced = false;
    this.continueOffered = false;
    this.score = 0;
    this.eatenPts = 0;
    this.bossEaten = false;
    this.floaters = [];
    this.banner = null;
    this.endTimer = 0;
    this.lastTick = Math.ceil(this.timeLeft);
    this.fx.reset();
    this.slowmo = 0;
    const boss = this.world.boss;
    this.cam = { x: boss.x, y: boss.y };
    this.zoom = this.introZoom();
    this.intro = { t: 0 };
    this.state = 'intro';
  }

  introZoom() {
    return Math.min(this.w, this.h) / (this.world.boss.r * 5.5);
  }

  skipIntro() {
    if (this.state !== 'intro') return;
    this.state = 'playing';
    this.intro = null;
    const level = this.level;
    const weatherHint =
      level.weather === 'clear' ? '' : `${WEATHER_ICONS[level.weather]} ${t(`weather_${level.weather}`)}`;
    this.showBanner(t(`${level.theme.boss}Name`), t('eatBoss', { boss: this.bossName() }), 2.6,
      this.behavior.hint ? t(this.behavior.hint) : weatherHint);
  }

  // Boss reacts to the hole: looks at it, and gets scared once it is close enough to be eaten.
  updateBossMood(dt) {
    const b = this.world.boss;
    if (!b || this.bossEaten) return;
    const h = this.hole;
    const dx = h.x - b.x;
    const dy = h.y - b.y;
    const d = Math.hypot(dx, dy) || 1;
    const canEat = b.r <= h.targetR * EAT_RATIO;
    const near = Math.max(0, Math.min(1, 1 - (d - h.r - b.r) / (b.r * 1.5)));
    const target = this.state === 'intro' ? 0 : canEat ? near : near * 0.3;
    const k = Math.min(1, dt * 5);
    b.ready = canEat && this.state === 'playing';
    b.fear = (b.fear || 0) + (target - (b.fear || 0)) * k;
    const look = Math.min(1, (b.r * 4) / d);
    b.lookX = (b.lookX || 0) + ((dx / d) * look - (b.lookX || 0)) * k;
    b.lookY = (b.lookY || 0) + ((dy / d) * look - (b.lookY || 0)) * k;
  }

  bossName() {
    return t(`${this.level.theme.boss}Boss`);
  }

  twist() {
    return t(`${this.level.theme.boss}Twist`);
  }

  showBanner(title, sub, dur, sub2 = '', kicker = '') {
    this.banner = { title, sub, sub2, kicker, t: 0, dur };
  }

  targetZoom() {
    return Math.min(this.w, this.h) / (this.hole.r * 15 + 280);
  }

  // Playables certification: while paused nothing may run, rendering included,
  // so the frame loop stops entirely and is restarted on resume.
  setPaused(p) {
    if (p === this.paused) return;
    this.paused = p;
    if (p) {
      audio.pause();
    } else {
      audio.resume();
      this.lastTs = 0;
      if (this.loopStopped) {
        this.loopStopped = false;
        requestAnimationFrame((n) => this.frame(n));
      }
    }
  }

  frame(ts) {
    if (this.paused) {
      this.loopStopped = true;
      return;
    }
    requestAnimationFrame((n) => this.frame(n));
    const dt = this.lastTs ? Math.min((ts - this.lastTs) / 1000, 0.05) : 0;
    this.lastTs = ts;
    if (dt > 0) this.update(dt);
    this.render();
    if (!this.firstFrameSent) {
      this.firstFrameSent = true;
      this.cb.onFirstFrame?.();
    }
  }

  update(dt) {
    if (this.paused) return;
    if (this.slowmo > 0) {
      this.slowmo -= dt;
      dt *= 0.35;
    }
    this.time += dt;
    if (!this.world) return;
    updateObjects(this.world, dt, this.time);
    this.weather.updateVisual(dt, this.w, this.h);
    this.updateBossMood(dt);
    this.fx.update(dt);

    if (this.state === 'intro') {
      this.intro.t += dt;
      if (this.intro.t >= INTRO_TIME) this.skipIntro();
    } else if (this.state === 'playing') {
      const input = this.input;
      if ([...input.keys].some(key => MOVE_KEYS.has(key)) || (input.active && Math.hypot(input.dx,input.dy)>4)) this.startedMoving = true;
      this.playTime += dt;
      this.growCooldown = Math.max(0, this.growCooldown - dt);
      this.comboTime = Math.max(0, this.comboTime - dt);
      if (!this.comboTime) this.combo = 0;
      if (this.startedMoving) {
        this.elapsedPlay += dt;
        this.weather.updateGameplay(dt, this);
        this.moveHole(dt);
        this.behavior.update(dt, this.hole);
        this.encounter.update(dt, this);
        this.checkEating(dt);
        this.updateObjective(dt);
        const shrink = this.weather.shrinkPerSec(this.hole.targetR);
        if (shrink) this.hole.targetR = Math.max(this.hole.startR, this.hole.targetR - shrink * dt);
        this.timeLeft -= dt;
      }
      const sec = Math.ceil(this.timeLeft);
      if (sec <= 5 && sec < this.lastTick && sec > 0) audio.tick();
      this.lastTick = sec;
      const allEaten = this.eatenPts >= this.world.totalPts && this.bossEaten;
      if (this.timeLeft <= 0 && !this.bossEaten && !this.continueOffered) {
        this.timeLeft = 0;
        this.continueOffered = true;
        if (this.cb.onTimeUp?.()) {
          this.state = 'offer';
          this.input.active = false;
          this.input.keys.clear();
          audio.warn();
          return;
        }
      }
      if (this.timeLeft <= 0 || allEaten) this.finish();
    } else if (this.state === 'ending') {
      this.endTimer -= dt;
      if (this.endTimer <= 0) {
        this.state = 'done';
        this.cb.onLevelEnd?.(this.results());
      }
    }

    // Falling animations keep running during the ending phase.
    for (const o of this.world.objects) {
      if (!o.falling) continue;
      o.fallT += dt / (o.fallDuration || FALL_TIME);
      if (o.fallT >= 1) {
        o.falling = false;
        o.eaten = true;
      }
    }

    const h = this.hole;
    h.r += (h.targetR - h.r) * Math.min(1, dt * 4);
    h.pulse = Math.max(0, h.pulse - dt * 2);
    this.bitePulse = Math.max(0, (this.bitePulse || 0) - dt * 4);
    this.ripples = (this.ripples || []).filter(p => (p.t += dt) < 0.55);

    const holding = this.state === 'intro' && this.intro.t < INTRO_TIME * INTRO_HOLD;
    const focus = holding ? this.world.boss : h;
    const camRate = this.state === 'intro' ? 3 : 8;
    this.zoom += ((holding ? this.introZoom() : this.targetZoom()) - this.zoom) * Math.min(1, dt * (holding ? 3 : 2));
    this.cam.x += (focus.x - this.cam.x) * Math.min(1, dt * camRate);
    this.cam.y += (focus.y - this.cam.y) * Math.min(1, dt * camRate);

    for (const f of this.floaters) {
      f.t += dt;
      f.y -= 65 * dt / Math.max(this.zoom, 0.4);
    }
    this.floaters = this.floaters.filter((f) => f.t < 0.9).slice(-40);
    this.scorePopTime = Math.max(0, (this.scorePopTime || 0) - dt);
    if (this.scorePop > 0 && !this.scorePopTime && !this.floaters.some(f => f.big)) {
      this.floaters.push({x:h.x,y:h.y-h.r,text:`+${this.scorePop}`,t:0});
      this.scorePop = 0;
      this.scorePopTime = 0.35;
    }
    updateParticles(this.particles, dt);
    if (this.banner) {
      this.banner.t += dt;
      if (this.banner.t > this.banner.dur) this.banner = null;
    }
  }

  finish() {
    this.behavior?.release();
    this.timeLeft = Math.max(0, this.timeLeft);
    this.state = 'ending';
    this.endTimer = 1.6;
    this.showBanner(this.bossEaten ? t('cleared') : t('failed'), '', 1.6);
    this.bossEaten ? audio.win() : audio.lose();
  }

  // Answer to onTimeUp: extra seconds keep the level going, 0 ends it as a fail.
  resolveContinue(extraSeconds) {
    if (this.state !== 'offer') return;
    if (extraSeconds > 0) {
      this.timeLeft = extraSeconds;
      this.lastTick = Math.ceil(extraSeconds);
      this.state = 'playing';
      this.lastTs = 0;
    } else {
      this.finish();
    }
  }

  moveHole(dt) {
    let dx = 0;
    let dy = 0;
    const k = this.input.keys;
    if (k.has('arrowleft') || k.has('a')) dx -= 1;
    if (k.has('arrowright') || k.has('d')) dx += 1;
    if (k.has('arrowup') || k.has('w')) dy -= 1;
    if (k.has('arrowdown') || k.has('s')) dy += 1;
    let mag = 0;
    if (dx || dy) {
      const l = Math.hypot(dx, dy);
      dx /= l;
      dy /= l;
      mag = 1;
    } else if (this.input.active) {
      const l = Math.hypot(this.input.dx, this.input.dy);
      if (l > 4) {
        dx = this.input.dx / l;
        dy = this.input.dy / l;
        mag = Math.min(1, l / JOY_RADIUS);
      }
    }
    const h = this.hole;
    const w = this.weather;
    const speed = BASE_SPEED * this.speedMul * w.speedMul * (1 + Math.min(2.2, h.r / 145));
    const tvx = dx * speed * mag;
    const tvy = dy * speed * mag;
    const follow = Math.min(1, dt * w.grip);
    h.vx += (tvx - h.vx) * follow;
    h.vy += (tvy - h.vy) * follow;
    const wind = w.windForce(BASE_SPEED * (1 + h.r / 90));
    h.x = Math.max(h.r * 0.5, Math.min(this.world.size - h.r * 0.5, h.x + (h.vx + wind.x) * dt));
    h.y = Math.max(h.r * 0.5, Math.min(this.world.size - h.r * 0.5, h.y + (h.vy + wind.y) * dt));

    if (mag > 0.2 && this.look.trail !== 'none') {
      this.trailT += dt;
      while (this.trailT > TRAIL_INTERVAL) {
        this.trailT -= TRAIL_INTERVAL;
        emitTrail(this.particles, this.look.trail, h.x, h.y, h.r, this.time);
      }
    }
  }

  checkEating(dt) {
    const h = this.hole;
    const maxR = h.r * EAT_RATIO;
    const magnet = this.stats.magnet;
    const magR = magnet ? h.r * (1.25 + magnet * 0.15) : 0;
    const pull = (60 + magnet * 30) * (1 + h.r / 90) * dt;
    for (const o of this.world.objects) {
      if (o.eaten || o.falling || o.hidden || o.r > maxR) continue;
      let ddx = o.x - h.x;
      let ddy = o.y - h.y;
      // Magnet only tugs small props; dragging whole buildings around looks wrong.
      if (magR && !o.isBoss && o.r < maxR * 0.6) {
        const d2 = ddx * ddx + ddy * ddy;
        if (d2 < magR * magR) {
          const d = Math.sqrt(d2) || 1;
          const step = Math.min(pull, d);
          o.x -= (ddx / d) * step;
          o.y -= (ddy / d) * step;
          ddx = o.x - h.x;
          ddy = o.y - h.y;
        }
      }
      const reach = h.r - o.r * 0.4;
      if (ddx * ddx + ddy * ddy > reach * reach) continue;
      o.falling = true;
      o.fallT = 0;
      o.fallDuration = o.isBoss ? 0.85 : 0.32 + Math.min(0.28, o.r / 220);
      o.fallSpin = (ddx < 0 ? -1 : 1) * (o.isBoss ? 0.7 : 1.3);
      o.lift = 0;
      o.abducted = false;
      o.fx = o.x;
      o.fy = o.y;
      o.vx = 0;
      o.vy = 0;
      this.eatenPts += o.pts;
      h.targetR = Math.sqrt(h.targetR * h.targetR + o.r * o.r * this.level.growth);
      this.bitePulse = Math.max(this.bitePulse, Math.min(0.65, o.r / 75));
      audio.pop(o.r);
      emitEatFx(this.particles, this.look.fx, o.x, o.y, o.r, h.r, o.color);

      if (o.isBoss) {
        this.bossEaten = true;
        this.bossCaughtAt = this.elapsedPlay;
        this.scorePop = 0;
        this.floaters = [];
        this.behavior.release();
        this.fx.burst(o.x, o.y, o.r, this.zoom);
        this.slowmo = BOSS_SLOWMO;
        const bonus = 500 * this.level.number;
        this.score += bonus;
        this.floaters.push({ x: o.x, y: o.y - o.r, text: `+${bonus}`, t: 0, big: true });
        this.showBanner(t('cleared'), this.twist(), 3);
        audio.boss();
      } else if (!o.eventGate) {
        this.swallowed++;
        if (o.kind === 'car') this.carsEaten++;
        this.combo++;
        this.comboTime = COMBO_WINDOW;
        this.bestCombo = Math.max(this.bestCombo, this.combo);
        const multiplier = comboMultiplier(this.combo);
        const points = Math.round(o.pts * multiplier);
        this.score += points;
        this.scorePop += points;
        if (o.r >= 20 && this.ripples.length < 20) {
          this.ripples.push({x:h.x,y:h.y,r:h.r,t:0});
        }
      }

      const tier = Math.floor((h.targetR - h.startR) / 8);
      if (tier > h.tier) {
        h.tier = tier;
        h.pulse = 1;
        if (!this.growCooldown) { audio.grow(); this.growCooldown = 0.3; }
        const boss = this.world.boss;
        if (!this.bossEaten && boss.r <= h.targetR * EAT_RATIO && !this.bossAnnounced) {
          this.bossAnnounced = true;
          this.showBanner('', t('bossReady', { boss: this.bossName() }), 2);
        }
      }
    }
    const sizeRatio = h.targetR / h.startR;
    if (!this.bossEaten && sizeRatio >= this.growthMilestone * 1.6) {
      this.growthMilestone = sizeRatio;
      this.floaters.push({x:h.x,y:h.y-h.r,text:t('sizeUp'),t:0,big:true});
      this.ripples.push({x:h.x,y:h.y,r:h.r,t:0});
    }
  }

  updateObjective(dt) {
    const objective = this.objective;
    objective.celebration = Math.max(0, objective.celebration - dt);
    objective.progress = objectiveProgress(objective, this);
    if (!objective.complete && objective.progress >= objective.goal) {
      objective.complete = true;
      objective.celebration = 3;
      if (this.level.number <= 5) this.timeLeft += 5;
      audio.challenge();
    }
  }

  results() {
    const pct = this.world.totalPts ? this.eatenPts / this.world.totalPts : 0;
    const cleared = this.bossEaten;
    const stars = cleared ? 1 + (pct >= STAR2_PCT ? 1 : 0) + (pct >= STAR3_PCT ? 1 : 0) : 0;
    // Combo score is for records. Coins follow unmultiplied food and a bounded
    // clear reward, preventing combo farming from buying all upgrades too early.
    const baseCoins = cleared ? this.eatenPts / 150 + stars * 12 + Math.min(80, this.level.number * 2) : this.eatenPts / 350;
    const coins = Math.floor(baseCoins * this.stats.coinMul);
    return {
      level: this.level.number,
      cleared,
      stars,
      pct,
      score: Math.floor(this.score),
      coins,
      bestCombo: this.bestCombo,
      objectiveComplete: this.objective.complete,
      medals: cleared ? [
        ...(this.objective.complete ? ['task'] : []),
        ...(this.bossCaughtAt !== null && this.bossCaughtAt <= this.level.quickTarget ? ['quick'] : []),
        ...(pct >= 0.9 ? ['clean'] : []),
      ] : [],
      quickTarget: this.level.quickTarget,
      twist: cleared ? this.twist() : t('bossFailed', { boss: this.bossName() }),
    };
  }

  // ---------- Rendering ----------

  render() {
    const { ctx, dpr } = this;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (!this.world) {
      this.renderAttract();
      return;
    }

    if (this.view3d && !this.view3d.lost) {
      this.view3d.render(this);
      ctx.clearRect(0, 0, this.w, this.h);
      for (const f of this.floaters) {
        const p = this.view3d.project(f.x, f.y, 25);
        ctx.save();
        ctx.globalAlpha = Math.max(0, 1 - f.t / 0.9);
        ctx.textAlign = 'center';
        ctx.font = `bold ${f.big ? 36 : 18}px Trebuchet MS, sans-serif`;
        ctx.strokeStyle = '#172439'; ctx.lineWidth = 4;
        ctx.fillStyle = f.bad ? '#ff4f4f' : f.big ? '#ffd23f' : '#fff';
        ctx.strokeText(f.text, p.x, p.y); ctx.fillText(f.text, p.x, p.y);
        ctx.restore();
      }
      const hp = this.view3d.project(this.hole.x, this.hole.y);
      this.weather.drawScreen(ctx, this.w, this.h, hp.x, hp.y, this.hole.r * this.zoom);
      this.fx.drawScreen(ctx, this.w, this.h);
      if (this.state === 'playing' || this.state === 'ending') this.drawHud(ctx);
      this.drawJoystick(ctx); this.drawIntro(ctx); this.drawBanner(ctx);
      return;
    }

    const z = this.zoom;
    const view = {
      x0: this.cam.x - this.w / 2 / z,
      y0: this.cam.y - this.h / 2 / z,
      x1: this.cam.x + this.w / 2 / z,
      y1: this.cam.y + this.h / 2 / z,
    };

    ctx.fillStyle = '#1b1f2e';
    ctx.fillRect(0, 0, this.w, this.h);
    ctx.save();
    const shake = this.fx.offset(this.time);
    ctx.translate(this.w / 2 + shake.x, this.h / 2 + shake.y);
    ctx.scale(z, z);
    ctx.translate(-this.cam.x, -this.cam.y);

    drawGround(ctx, this.world, view);
    this.encounter?.draw(ctx);
    if (this.state === 'playing') this.behavior?.draw(ctx);
    drawParticles(ctx, this.particles, 0);
    this.drawHole(ctx);
    for (const p of this.ripples || []) {
      ctx.save();ctx.globalAlpha=1-p.t/0.55;ctx.strokeStyle='#fff0a0';ctx.lineWidth=3/z;
      ctx.beginPath();ctx.arc(p.x,p.y,p.r*(1+p.t*1.4),0,Math.PI*2);ctx.stroke();ctx.restore();
    }

    const pad = 200;
    const visible = [];
    for (const o of this.world.objects) {
      if (o.eaten || o.hidden || (o.falling && o.fallT >= 0.24)) continue;
      if (o.x < view.x0 - pad || o.x > view.x1 + pad || o.y < view.y0 - pad || o.y > view.y1 + pad) continue;
      visible.push(o);
    }
    visible.sort((a, b) => a.y - b.y);
    for (const o of visible) {
      if (o.falling) this.drawSwallow(ctx, o);
      else {
        ctx.save();
        if(o.lift) ctx.translate(0,-o.lift);
        drawObject(ctx, o, this.time);
        ctx.restore();
      }
    }
    drawParticles(ctx, this.particles, 1);
    this.fx.drawWorld(ctx, z);
    this.weather.drawWorld(ctx, z);

    ctx.font = 'bold 18px Trebuchet MS, sans-serif';
    ctx.textAlign = 'center';
    for (const f of this.floaters) {
      ctx.globalAlpha = 1 - f.t / 0.9;
      ctx.fillStyle = f.bad ? '#ff4f4f' : f.big ? '#ffd23f' : '#fff';
      ctx.strokeStyle = '#000';
      ctx.lineWidth = 4 / z;
      const size = (f.big ? 44 : 18) / Math.max(z, 0.4);
      ctx.font = `bold ${size}px Trebuchet MS, sans-serif`;
      ctx.strokeText(f.text, f.x, f.y);
      ctx.fillText(f.text, f.x, f.y);
    }
    ctx.globalAlpha = 1;
    ctx.restore();

    const hx = (this.hole.x - this.cam.x) * z + this.w / 2;
    const hy = (this.hole.y - this.cam.y) * z + this.h / 2;
    this.weather.drawScreen(ctx, this.w, this.h, hx, hy, this.hole.r * z);
    this.fx.drawScreen(ctx, this.w, this.h);

    if (this.state === 'playing' || this.state === 'ending') this.drawHud(ctx);
    this.drawJoystick(ctx);
    this.drawIntro(ctx);
    this.drawBanner(ctx);
  }

  drawIntro(ctx) {
    if (this.state !== 'intro' || !this.intro) return;
    const { w, h } = this;
    const tt = this.intro.t;
    const inK = Math.min(1, tt / 0.35);
    const outK = Math.min(1, (INTRO_TIME - tt) / 0.4);
    const k = Math.max(0, Math.min(inK, outK));
    const ease = 1 - (1 - k) * (1 - k);
    const bar = h * 0.12 * ease;
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, w, bar);
    ctx.fillRect(0, h - bar, w, bar);

    const theme = this.level.theme;
    const pop = tt < 0.5 ? 1 + Math.sin(Math.min(1, tt / 0.5) * Math.PI) * 0.15 : 1;
    ctx.save();
    ctx.globalAlpha = k;
    ctx.translate(w / 2, h * 0.74);
    ctx.textAlign = 'center';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = '#000';
    const kicker = `${theme.landmark ? '🏛️ ' : ''}${t('level')} ${this.level.number}`;
    ctx.font = `bold ${Math.min(22, w / 20)}px Trebuchet MS, sans-serif`;
    ctx.lineWidth = 5;
    ctx.fillStyle = '#fff';
    ctx.strokeText(kicker, 0, -48);
    ctx.fillText(kicker, 0, -48);
    ctx.save();
    ctx.scale(pop, pop);
    ctx.font = `bold ${Math.min(52, w / 10)}px Trebuchet MS, sans-serif`;
    ctx.lineWidth = 9;
    ctx.fillStyle = '#ffd23f';
    ctx.strokeText(this.bossName(), 0, 0);
    ctx.fillText(this.bossName(), 0, 0);
    ctx.restore();
    ctx.font = `bold ${Math.min(20, w / 22)}px Trebuchet MS, sans-serif`;
    ctx.lineWidth = 5;
    ctx.fillStyle = '#9fe7ff';
    ctx.strokeText(t(`${theme.boss}Name`), 0, 36);
    ctx.fillText(t(`${theme.boss}Name`), 0, 36);
    ctx.restore();
  }

  drawHole(ctx) {
    const h = this.hole;
    const r = h.r * (1 + h.pulse * 0.08 + (this.bitePulse || 0) * 0.035);

    ctx.save();
    drawSkinInside(ctx, this.look.skin, h.x, h.y, r, this.time);
    ctx.beginPath();
    ctx.arc(h.x, h.y, r, 0, Math.PI * 2);
    ctx.clip();
    for (const o of this.world.objects) {
      if (!o.falling) continue;
      if (o.fallT >= 0.24) this.drawSwallow(ctx, o);
    }
    ctx.restore();

    drawSkinRim(ctx, this.look.skin, h.x, h.y, r, this.time, h.pulse);
  }

  drawSwallow(ctx, o) {
    const h = this.hole, p = o.fallT, e = p*p;
    const size = 1-e*0.94;
    ctx.save();ctx.globalAlpha=1-e*0.85;
    ctx.translate(o.fx+(h.x-o.fx)*p,o.fy+(h.y-o.fy)*p+e*h.r*0.25);
    ctx.rotate((o.fallSpin || 1)*p*p*2.5);
    // The object first tips toward the rim, then sinks into the depth of the hole.
    ctx.scale(size*(1+Math.sin(p*Math.PI)*0.08),size*(1-Math.sin(p*Math.PI)*0.35));
    ctx.translate(-o.x,-o.y);drawObject(ctx,o,this.time);ctx.restore();
  }

  drawHud(ctx) {
    const pad = 14;
    const w = this.w;

    const sec = Math.max(0, Math.ceil(this.timeLeft));
    const mm = Math.floor(sec / 60);
    const ss = String(sec % 60).padStart(2, '0');
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.font = 'bold 34px Trebuchet MS, sans-serif';
    ctx.lineWidth = 6;
    ctx.strokeStyle = '#000';
    ctx.fillStyle = sec <= 10 ? '#ff4f7b' : '#fff';
    ctx.strokeText(`${mm}:${ss}`, w / 2, pad);
    ctx.fillText(`${mm}:${ss}`, w / 2, pad);

    ctx.textAlign = 'left';
    ctx.font = 'bold 20px Trebuchet MS, sans-serif';
    ctx.fillStyle = '#fff';
    ctx.strokeText(`${this.score}`, pad, pad + 4);
    ctx.fillText(`${this.score}`, pad, pad + 4);
    const levelLabel = `${t('level')} ${this.level.number}`;
    ctx.font = 'bold 15px Trebuchet MS, sans-serif';
    ctx.lineWidth = 4;
    ctx.fillStyle = '#ffd23f';
    ctx.strokeText(levelLabel, pad, pad + 30);
    ctx.fillText(levelLabel, pad, pad + 30);
    ctx.font = 'bold 20px Trebuchet MS, sans-serif';
    ctx.lineWidth = 6;
    ctx.fillStyle = '#fff';

    const pct = Math.floor((this.eatenPts / this.world.totalPts) * 100);
    ctx.textAlign = 'right';
    ctx.strokeText(`${pct}%`, w - pad, pad + 4);
    ctx.fillText(`${pct}%`, w - pad, pad + 4);
    const icon = WEATHER_ICONS[this.weather.type];
    if (icon) {
      ctx.font = '22px sans-serif';
      ctx.fillText(icon, w - pad, pad + 32);
      this.weather.drawWindIndicator(ctx, w - pad - 46, pad + 44);
    }

    const boss = this.world.boss;
    if (!this.bossEaten) {
      const need = boss.r / EAT_RATIO;
      const prog = Math.min(1, (this.hole.targetR - this.hole.startR) / (need - this.hole.startR));
      const bw = Math.min(260, w * 0.6);
      const bx = w / 2 - bw / 2;
      const by = pad + 48;
      ctx.fillStyle = 'rgba(0,0,0,0.5)';
      ctx.beginPath();
      ctx.roundRect(bx, by, bw, 14, 7);
      ctx.fill();
      ctx.fillStyle = prog >= 1 ? '#06d6a0' : '#ffd23f';
      ctx.beginPath();
      ctx.roundRect(bx, by, Math.max(14, bw * prog), 14, 7);
      ctx.fill();
      ctx.font = 'bold 13px Trebuchet MS, sans-serif';
      ctx.textAlign = 'center';
      ctx.lineWidth = 3;
      ctx.strokeText(this.bossName(), w / 2, by + 18);
      ctx.fillStyle = '#fff';
      ctx.fillText(this.bossName(), w / 2, by + 18);
      this.drawBossArrow(ctx, boss);
    }
    ctx.textBaseline = 'alphabetic';
    this.drawChallenges(ctx);
  }

  drawChallenges(ctx) {
    if (!this.objective) return;
    const w=this.w, objective=this.objective;
    ctx.save();ctx.textAlign='center';ctx.textBaseline='middle';
    if (this.encounter?.noticeTime > 0) {
      const eventWidth=Math.min(360,w-28);
      ctx.fillStyle='rgba(35,48,66,0.94)';ctx.beginPath();ctx.roundRect((w-eventWidth)/2,164,eventWidth,48,12);ctx.fill();
      ctx.fillStyle='#abffe2';ctx.font='bold 14px Trebuchet MS, sans-serif';
      ctx.fillText(t(this.encounter.title),w/2,181,eventWidth-18);
      ctx.fillStyle='#fff';ctx.font='12px Trebuchet MS, sans-serif';
      const hintKey = this.encounter.kind === 'garden' && this.encounter.state === 'opened' ? 'eventHint_gardenOpen' : `eventHint_${this.encounter.kind}`;
      ctx.fillText(t(hintKey),w/2,198,eventWidth-18);
    }
    const width=Math.min(370,w-28),x=(w-width)/2,y=this.h-86;
    ctx.fillStyle='rgba(18,18,43,0.88)';ctx.beginPath();ctx.roundRect(x,y,width,67,15);ctx.fill();
    ctx.fillStyle=objective.complete?'#92ffe4':'#ffdf73';ctx.font='bold 14px Trebuchet MS, sans-serif';
    const title=objective.complete?t('missionDone'):t(objective.key,{n:objective.goal});
    ctx.fillText(title,w/2,y+19,width-24);
    ctx.fillStyle='#cad8ee';ctx.font='12px Trebuchet MS, sans-serif';
    const hint=!this.startedMoving?t('lessonMove'):objective.celebration>0?t(this.level.number<=5?'timeGift':'medalOnClear'):
      objective.complete?t('medalGoals',{s:this.level.quickTarget}):objective.hint && this.playTime<16?t(objective.hint):
        `${objective.progress}/${objective.goal} · ${t(this.level.number<=5?'rewardTime':'medalOnClear')}`;
    ctx.fillText(hint,w/2,y+39,width-24);
    ctx.fillStyle=objective.complete?'#5eeac7':'#ffcf63';
    ctx.fillRect(x+12,y+56,(width-24)*objective.progress/objective.goal,3);
    ctx.restore();
  }

  drawBossArrow(ctx, boss) {
    const z = this.zoom;
    const projected = this.view3d && !this.view3d.lost ? this.view3d.project(boss.x, boss.y) : null;
    const sx = projected ? projected.x : (boss.x - this.cam.x) * z + this.w / 2;
    const sy = projected ? projected.y : (boss.y - this.cam.y) * z + this.h / 2;
    const margin = 40;
    if (sx > margin && sx < this.w - margin && sy > margin + 80 && sy < this.h - margin) return;
    const cx = this.w / 2;
    const cy = this.h / 2;
    const a = Math.atan2(sy - cy, sx - cx);
    const rx = this.w / 2 - margin;
    const ry = this.h / 2 - margin - 40;
    const k = Math.min(rx / Math.abs(Math.cos(a) || 1e-6), ry / Math.abs(Math.sin(a) || 1e-6));
    const ax = cx + Math.cos(a) * k;
    const ay = cy + 20 + Math.sin(a) * k;
    ctx.save();
    ctx.translate(ax, ay);
    ctx.rotate(a);
    ctx.fillStyle = '#ffd23f';
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(18, 0);
    ctx.lineTo(-10, -12);
    ctx.lineTo(-4, 0);
    ctx.lineTo(-10, 12);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  drawJoystick(ctx) {
    if (!this.input.active || this.state !== 'playing') return;
    const { sx, sy, dx, dy } = this.input;
    ctx.strokeStyle = 'rgba(255,255,255,0.35)';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(sx, sy, JOY_RADIUS, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.45)';
    ctx.beginPath();
    ctx.arc(sx + dx, sy + dy, 22, 0, Math.PI * 2);
    ctx.fill();
  }

  drawBanner(ctx) {
    const b = this.banner;
    if (!b) return;
    const inT = Math.min(1, b.t / 0.25);
    const outT = Math.min(1, (b.dur - b.t) / 0.3);
    const a = Math.max(0, Math.min(inT, outT));
    const scale = 0.7 + 0.3 * inT;
    ctx.save();
    ctx.globalAlpha = a;
    ctx.translate(this.w / 2, this.h * 0.32);
    ctx.scale(scale, scale);
    ctx.textAlign = 'center';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = '#000';
    if (b.kicker) {
      ctx.font = `bold ${Math.min(24, this.w / 20)}px Trebuchet MS, sans-serif`;
      ctx.lineWidth = 5;
      ctx.fillStyle = '#fff';
      ctx.strokeText(b.kicker, 0, -54);
      ctx.fillText(b.kicker, 0, -54);
    }
    if (b.title) {
      ctx.font = `bold ${Math.min(56, this.w / 9)}px Trebuchet MS, sans-serif`;
      ctx.lineWidth = 8;
      ctx.fillStyle = '#ffd23f';
      ctx.strokeText(b.title, 0, 0);
      ctx.fillText(b.title, 0, 0);
    }
    if (b.sub) {
      ctx.font = `bold ${Math.min(24, this.w / 20)}px Trebuchet MS, sans-serif`;
      ctx.lineWidth = 5;
      ctx.fillStyle = '#fff';
      ctx.strokeText(b.sub, 0, 44);
      ctx.fillText(b.sub, 0, 44);
    }
    if (b.sub2) {
      ctx.font = `bold ${Math.min(20, this.w / 24)}px Trebuchet MS, sans-serif`;
      ctx.lineWidth = 5;
      ctx.fillStyle = '#9fe7ff';
      ctx.strokeText(b.sub2, 0, 78);
      ctx.fillText(b.sub2, 0, 78);
    }
    ctx.restore();
  }

  renderAttract() {
    const { ctx } = this;
    ctx.fillStyle = '#2a2f4a';
    ctx.fillRect(0, 0, this.w, this.h);
    const cx = this.w / 2;
    const cy = this.h / 2;
    const r = Math.min(this.w, this.h) * 0.35 + Math.sin(this.time * 2) * 6;
    const grad = ctx.createRadialGradient(cx, cy, r * 0.2, cx, cy, r);
    grad.addColorStop(0, '#000');
    grad.addColorStop(1, '#2a1650');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();
  }

  showWorldBackdrop(level) {
    this.encounter = null;
    this.behavior?.release();
    this.behavior = null;
    this.ripples = [];
    this.level = level;
    this.world = generateWorld(level);
    const c = this.world.center;
    const s = this.world.spawn;
    this.hole = { x: s.x, y: s.y, r: 60, targetR: 60, startR: 60, tier: 0, pulse: 0, vx: 0, vy: 0 };
    this.weather = new Weather(level.weather, level.weatherPower);
    this.zoom = Math.min(this.w, this.h) / 1400;
    this.cam = { x: c.x, y: c.y };
    this.state = 'idle';
  }
}
