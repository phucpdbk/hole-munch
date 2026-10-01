// Thin wrapper around the YouTube Playables SDK with a localStorage fallback for local dev
// and the web, plus AdMob and app lifecycle events in the Android app.
import { native } from './native.js';

const yt = window.ytgame;
const inPlayables = !!(yt && yt.IN_PLAYABLES_ENV);
const LOCAL_KEY = 'holemunch_save';
// Local dev only: ?mockads=1 fakes ads with a short overlay so ad flows can be tested.
const mockAds = !inPlayables && new URLSearchParams(location.search).get('mockads') === '1';

let loadCompleted = false;

function mockAd(label) {
  return new Promise((resolve) => {
    const el = document.createElement('div');
    el.className = 'mock-ad';
    el.textContent = `AD (mock): ${label}`;
    document.body.appendChild(el);
    setTimeout(() => {
      el.remove();
      resolve();
    }, 1500);
  });
}

function safe(fn) {
  try {
    return fn();
  } catch (err) {
    console.warn('[sdk]', err);
    return undefined;
  }
}

export const sdk = {
  inPlayables,

  firstFrameReady() {
    if (inPlayables) safe(() => yt.game.firstFrameReady());
  },

  gameReady() {
    if (inPlayables) safe(() => yt.game.gameReady());
  },

  async loadData() {
    let raw = '';
    try {
      raw = inPlayables ? await yt.game.loadData() : localStorage.getItem(LOCAL_KEY) || '';
    } catch (err) {
      console.warn('[sdk] loadData failed', err);
    }
    loadCompleted = true;
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch {
      return null;
    }
  },

  async saveData(obj) {
    // The SDK rejects saveData calls made before loadData has resolved.
    if (!loadCompleted) return;
    const raw = JSON.stringify(obj);
    try {
      if (inPlayables) await yt.game.saveData(raw);
      else localStorage.setItem(LOCAL_KEY, raw);
    } catch (err) {
      console.warn('[sdk] saveData failed', err);
    }
  },

  sendScore(value) {
    if (inPlayables) safe(() => yt.engagement.sendScore({ value: Math.floor(value) }));
  },

  async getLanguage() {
    if (inPlayables) {
      try {
        return await yt.system.getLanguage();
      } catch {
        /* fall through */
      }
    }
    return new URLSearchParams(location.search).get('lang') || navigator.language || 'en';
  },

  isAudioEnabled() {
    if (inPlayables) return safe(() => yt.system.isAudioEnabled()) !== false;
    return true;
  },

  onAudioEnabledChange(cb) {
    if (inPlayables) safe(() => yt.system.onAudioEnabledChange(cb));
  },

  // Certification forbids the Page Visibility API inside Playables; it is only a local fallback.
  onPause(cb) {
    if (inPlayables) return void safe(() => yt.system.onPause(cb));
    document.addEventListener('visibilitychange', () => document.hidden && cb());
    native.onAppStateChange((active) => !active && cb());
  },

  onResume(cb) {
    if (inPlayables) return void safe(() => yt.system.onResume(cb));
    document.addEventListener('visibilitychange', () => !document.hidden && cb());
    native.onAppStateChange((active) => active && cb());
  },

  onBackButton: native.onBackButton,
  minimizeApp: native.minimizeApp,

  logError(err) {
    if (inPlayables) safe(() => yt.health.logError(err));
  },

  rewardedAdsAvailable: inPlayables || !!native.ads || mockAds,

  // Resolves when the ad flow ends; never rejects, since a missing ad must not block play.
  async showInterstitial() {
    try {
      if (inPlayables) await yt.ads.requestInterstitialAd();
      else if (native.ads) await native.ads.showInterstitial();
      else if (mockAds) await mockAd('interstitial');
    } catch (err) {
      console.warn('[sdk] interstitial failed', err);
    }
  },

  // Resolves true only when the player earned the reward; false on skip or failure.
  async showRewarded(rewardId) {
    try {
      if (inPlayables) return (await yt.ads.requestRewardedAd(rewardId)) === true;
      if (native.ads) return await native.ads.showRewarded();
      if (mockAds) {
        await mockAd(rewardId);
        return true;
      }
    } catch (err) {
      console.warn('[sdk] rewarded ad failed', err);
    }
    return false;
  },
};
