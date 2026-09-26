import { STRINGS, ALIASES, RTL, LANG_NAMES } from './locales.js';
import { SHOP_STRINGS } from './locales-shop.js';
import { WEATHER_STRINGS } from './locales-weather.js';
import { AD_STRINGS } from './locales-ads.js';
import { LANDMARK_STRINGS } from './locales-landmarks.js';
import { EXPANSION_STRINGS } from './locales-expansion.js';
import { GAMEPLAY_STRINGS } from './locales-gameplay.js';

for (const extra of [SHOP_STRINGS, WEATHER_STRINGS, AD_STRINGS, LANDMARK_STRINGS, EXPANSION_STRINGS, GAMEPLAY_STRINGS]) {
  for (const [code, strings] of Object.entries(extra)) Object.assign(STRINGS[code], strings);
}

let lang = 'en';

export function setLanguage(code) {
  const base = (code || 'en').toLowerCase().split(/[-_]/)[0];
  const mapped = ALIASES[base] || base;
  lang = STRINGS[mapped] ? mapped : 'en';
  document.documentElement.lang = lang;
  document.documentElement.dir = RTL.has(lang) ? 'rtl' : 'ltr';
}

export function getLang() {
  return lang;
}

export function isSupported(code) {
  return typeof code === 'string' && code in STRINGS;
}

export const LANGUAGES = Object.entries(LANG_NAMES).map(([code, name]) => ({ code, name }));

export function t(key, vars = {}) {
  let s = STRINGS[lang][key] ?? STRINGS.en[key] ?? key;
  for (const k in vars) s = s.replace(`{${k}}`, vars[k]);
  return s;
}

export function applyStaticText(root = document) {
  root.querySelectorAll('[data-i18n]').forEach((el) => {
    el.textContent = t(el.dataset.i18n);
  });
}
