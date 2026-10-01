// Procedural WebAudio SFX so the bundle ships with zero audio files.
let ctx = null;
let master = null;
let enabled = true;
let suspendedBySystem = false;

function ensure() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return null;
  ctx = new AC();
  master = ctx.createGain();
  master.gain.value = enabled ? 0.5 : 0;
  master.connect(ctx.destination);
  return ctx;
}

function tone({ freq, to = freq, dur = 0.12, type = 'sine', vol = 0.3, delay = 0 }) {
  if (!enabled || suspendedBySystem || !ensure()) return;
  const t0 = ctx.currentTime + delay;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  osc.frequency.exponentialRampToValueAtTime(Math.max(20, to), t0 + dur);
  gain.gain.setValueAtTime(vol, t0);
  gain.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
  osc.connect(gain).connect(master);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

let lastPop = 0;

export const audio = {
  unlock() {
    if (ensure() && ctx.state === 'suspended' && !suspendedBySystem) ctx.resume();
  },

  setEnabled(on) {
    enabled = on;
    if (master) master.gain.value = on ? 0.5 : 0;
  },

  pause() {
    suspendedBySystem = true;
    if (ctx && ctx.state === 'running') ctx.suspend();
  },

  resume() {
    suspendedBySystem = false;
    if (ctx && ctx.state === 'suspended') ctx.resume();
  },

  // Bigger objects make deeper pops.
  pop(size) {
    const now = performance.now();
    if (now - lastPop < 35) return;
    lastPop = now;
    const f = Math.max(90, 900 - size * 9);
    tone({ freq: f, to: f * 0.4, dur: 0.1 + Math.min(size, 80) / 400, type: 'triangle', vol: 0.25 });
    if (size > 35) tone({freq:90,to:35,dur:0.19,type:'sine',vol:0.16});
  },

  challenge() {
    [659, 880, 1046].forEach((freq,i) => tone({freq,dur:0.15,type:'triangle',vol:0.13,delay:i*0.08}));
  },

  grow() {
    tone({ freq: 400, to: 800, dur: 0.15, type: 'square', vol: 0.08 });
  },

  boss() {
    [0, 0.12, 0.24, 0.36].forEach((d, i) =>
      tone({ freq: 300 + i * 120, to: 600 + i * 150, dur: 0.18, type: 'square', vol: 0.12, delay: d })
    );
    tone({ freq: 120, to: 40, dur: 0.8, type: 'sawtooth', vol: 0.2 });
  },

  tick() {
    tone({ freq: 1000, dur: 0.05, type: 'square', vol: 0.06 });
  },

  win() {
    [523, 659, 784, 1046].forEach((f, i) => tone({ freq: f, dur: 0.2, type: 'triangle', vol: 0.2, delay: i * 0.1 }));
  },

  lose() {
    [400, 320, 250].forEach((f, i) => tone({ freq: f, to: f * 0.8, dur: 0.25, type: 'sawtooth', vol: 0.12, delay: i * 0.15 }));
  },

  warn() {
    tone({ freq: 880, dur: 0.12, type: 'square', vol: 0.08 });
    tone({ freq: 880, dur: 0.12, type: 'square', vol: 0.08, delay: 0.25 });
  },

  thunder() {
    tone({ freq: 160, to: 30, dur: 1.1, type: 'sawtooth', vol: 0.3 });
    tone({ freq: 90, to: 25, dur: 1.4, type: 'square', vol: 0.12, delay: 0.05 });
  },

  click() {
    tone({ freq: 600, to: 900, dur: 0.06, type: 'triangle', vol: 0.15 });
  },
};
