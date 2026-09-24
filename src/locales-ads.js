// Strings for rewarded-ad offers. Each language array must follow KEYS order.
// {n} is replaced with a number (seconds).
const KEYS = ['timeUp', 'continueAsk', 'watchAdTime', 'noThanks', 'adDouble', 'adUnavailable'];

const TABLE = {
  en: ["Time's up!", 'So close! Watch a short ad for +{n} seconds?', '▶ +{n}s', 'No thanks', '▶ x2 coins', 'No ad available right now'],
  vi: ['Hết giờ!', 'Suýt nữa thôi! Xem một quảng cáo ngắn để có thêm {n} giây?', '▶ +{n} giây', 'Không, cảm ơn', '▶ x2 xu', 'Hiện chưa có quảng cáo'],
  es: ['¡Se acabó el tiempo!', '¡Casi! ¿Ves un anuncio corto para +{n} segundos?', '▶ +{n} s', 'No, gracias', '▶ x2 monedas', 'No hay anuncios ahora'],
  pt: ['Acabou o tempo!', 'Quase! Assistir a um anúncio curto para +{n} segundos?', '▶ +{n} s', 'Não, obrigado', '▶ x2 moedas', 'Nenhum anúncio disponível agora'],
  fr: ['Temps écoulé !', 'Presque ! Regarder une courte pub pour +{n} secondes ?', '▶ +{n} s', 'Non merci', '▶ x2 pièces', 'Aucune pub disponible pour le moment'],
  de: ['Zeit um!', 'Fast! Kurze Werbung ansehen für +{n} Sekunden?', '▶ +{n} s', 'Nein danke', '▶ x2 Münzen', 'Gerade keine Werbung verfügbar'],
  it: ['Tempo scaduto!', 'Quasi! Guardi un breve annuncio per +{n} secondi?', '▶ +{n} s', 'No, grazie', '▶ x2 monete', 'Nessun annuncio disponibile ora'],
  tr: ['Süre doldu!', 'Az kaldı! +{n} saniye için kısa bir reklam izle?', '▶ +{n} sn', 'Hayır, teşekkürler', '▶ x2 altın', 'Şu anda reklam yok'],
  ru: ['Время вышло!', 'Почти! Посмотреть короткую рекламу за +{n} секунд?', '▶ +{n} с', 'Нет, спасибо', '▶ x2 монеты', 'Сейчас нет рекламы'],
  pl: ['Koniec czasu!', 'Prawie! Obejrzyj krótką reklamę, aby dostać +{n} sekund?', '▶ +{n} s', 'Nie, dziękuję', '▶ x2 monety', 'Brak dostępnej reklamy'],
  hi: ['समय खत्म!', 'बस थोड़ा सा! +{n} सेकंड के लिए एक छोटा विज्ञापन देखें?', '▶ +{n} सेकंड', 'नहीं, धन्यवाद', '▶ x2 सिक्के', 'अभी कोई विज्ञापन उपलब्ध नहीं'],
  id: ['Waktu habis!', 'Sedikit lagi! Tonton iklan singkat untuk +{n} detik?', '▶ +{n} dtk', 'Tidak, terima kasih', '▶ x2 koin', 'Iklan belum tersedia'],
  ms: ['Masa tamat!', 'Hampir! Tonton iklan pendek untuk +{n} saat?', '▶ +{n} saat', 'Tidak, terima kasih', '▶ x2 syiling', 'Tiada iklan buat masa ini'],
  th: ['หมดเวลา!', 'เกือบแล้ว! ดูโฆษณาสั้นๆ เพื่อรับเวลาเพิ่ม {n} วินาทีไหม?', '▶ +{n} วิ', 'ไม่ล่ะ ขอบคุณ', '▶ เหรียญ x2', 'ยังไม่มีโฆษณาในตอนนี้'],
  ja: ['時間切れ！', 'あと少し！短い広告を見て +{n}秒 もらう？', '▶ +{n}秒', 'いいえ', '▶ コイン2倍', '現在広告はありません'],
  ko: ['시간 종료!', '아깝다! 짧은 광고를 보고 {n}초를 더 받을까요?', '▶ +{n}초', '괜찮아요', '▶ 코인 2배', '지금은 광고가 없어요'],
  ar: ['انتهى الوقت!', 'اقتربت! شاهد إعلانًا قصيرًا لتحصل على {n} ثانية إضافية؟', '▶ +{n} ث', 'لا، شكرًا', '▶ عملات x2', 'لا يوجد إعلان متاح الآن'],
};

export const AD_STRINGS = Object.fromEntries(
  Object.entries(TABLE).map(([lang, values]) => [lang, Object.fromEntries(KEYS.map((k, i) => [k, values[i]]))])
);
