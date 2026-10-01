// Capacitor (Android/iOS app) integration. The plugin globals only exist in the app build, where
// tools/build-app.mjs adds their script tags, so the web and YouTube builds get `null` here.
import { ADMOB_UNITS } from './ads-config.js';

const cap = window.Capacitor;
const admob = window.capacitorAdMob;
const appPlugin = window.capacitorApp?.App;
const isNative = !!cap?.isNativePlatform?.();
const platform = cap?.getPlatform?.();

// Listeners must be attached before an ad is shown; `result` settles with the first event's value.
async function listen(AdMob, outcomes) {
  let settle;
  const result = new Promise((r) => (settle = r));
  const handles = await Promise.all(
    Object.entries(outcomes).map(([event, value]) => AdMob.addListener(event, () => settle(value))),
  );
  return { result, stop: () => handles.forEach((h) => h.remove()) };
}

function createAds() {
  const units = ADMOB_UNITS[platform];
  if (!isNative || !admob || !units) return null;
  const { AdMob, InterstitialAdPluginEvents: IE, RewardAdPluginEvents: RE, MaxAdContentRating } = admob;
  const loaded = { interstitial: false, rewarded: false };

  // The game targets families, so every request is child-directed with G-rated content only.
  const ready = AdMob.initialize({
    tagForChildDirectedTreatment: true,
    tagForUnderAgeOfConsent: true,
    maxAdContentRating: MaxAdContentRating.General,
  });

  const prepare = {
    interstitial: () => AdMob.prepareInterstitial({ adId: units.interstitial }),
    rewarded: () => AdMob.prepareRewardVideoAd({ adId: units.rewarded }),
  };

  async function load(kind) {
    try {
      await ready;
      await prepare[kind]();
      loaded[kind] = true;
    } catch (err) {
      loaded[kind] = false;
      console.warn('[admob] load failed', kind, err);
    }
  }

  load('interstitial');
  load('rewarded');

  return {
    // Skips silently when nothing is loaded: a missing ad must never make the player wait.
    async showInterstitial() {
      if (!loaded.interstitial) return void load('interstitial');
      loaded.interstitial = false;
      const ad = await listen(AdMob, { [IE.Dismissed]: true, [IE.FailedToShow]: false });
      try {
        await AdMob.showInterstitial();
        await ad.result;
      } finally {
        ad.stop();
        load('interstitial');
      }
    },

    async showRewarded() {
      if (!loaded.rewarded) await load('rewarded');
      if (!loaded.rewarded) return false;
      loaded.rewarded = false;
      let earned = false;
      const reward = await AdMob.addListener(RE.Rewarded, () => (earned = true));
      const ad = await listen(AdMob, { [RE.Dismissed]: true, [RE.FailedToShow]: false });
      try {
        await AdMob.showRewardVideoAd();
        await ad.result;
        return earned;
      } finally {
        reward.remove();
        ad.stop();
        load('rewarded');
      }
    },
  };
}

export const native = {
  isNative,
  ads: createAds(),

  onAppStateChange(cb) {
    if (isNative && appPlugin) appPlugin.addListener('appStateChange', ({ isActive }) => cb(isActive));
  },

  onBackButton(cb) {
    if (platform === 'android' && appPlugin) appPlugin.addListener('backButton', cb);
  },

  minimizeApp() {
    if (platform === 'android') appPlugin?.minimizeApp();
  },
};
