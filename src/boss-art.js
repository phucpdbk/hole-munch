// Shared decoded artwork: no loading or offscreen compositing in the render loop.
const artwork = new Map();
let loading;

export function getBossArt(type) { return artwork.get(type); }

export function preloadBossArt() {
  if (loading) return loading;
  if (typeof Image === 'undefined') return Promise.resolve();
  loading = new Promise(resolve => {
    const image = new Image();
    let settled = false;
    const finish = ok => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      image.onload = image.onerror = null;
      if (ok) artwork.set('duck', image);
      resolve(); // Missing art must never prevent the game from starting.
    };
    const timer = setTimeout(() => finish(false), 4000);
    image.onload = async () => {
      try {
        if (image.decode) await image.decode();
        finish(true);
      } catch { finish(false); }
    };
    image.onerror = () => finish(false);
    image.src = new URL('../assets/bosses/duck-cartoon-v2.webp', import.meta.url).href;
  });
  return loading;
}
