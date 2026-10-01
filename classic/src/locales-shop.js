// Shop strings. Each language array must follow KEYS order exactly.
const KEYS = [
  'tabStats', 'tabSkins', 'tabFx', 'tabTrails', 'equip', 'equipped', 'upMagnet', 'upGreed',
  'skin_classic', 'skin_candy', 'skin_slime', 'skin_fire', 'skin_galaxy', 'skin_neon', 'skin_xmas', 'skin_gold',
  'fx_dust', 'fx_confetti', 'fx_hearts', 'fx_stars', 'fx_coins', 'fx_pixels', 'fx_snow',
  'trail_none', 'trail_bubbles', 'trail_sparkle', 'trail_snow', 'trail_fire', 'trail_rainbow',
];

const TABLE = {
  en: [
    'Power', 'Skins', 'Effects', 'Trails', 'Equip', 'Equipped', 'Magnet', 'Coin Bonus',
    'Classic', 'Candy Cane', 'Toxic Slime', 'Fire Ring', 'Galaxy', 'Neon Rainbow', 'Christmas Wreath', 'Golden VIP',
    'Dust', 'Confetti', 'Hearts', 'Stars', 'Coin Burst', 'Pixels', 'Snowflakes',
    'None', 'Bubbles', 'Sparkles', 'Snow', 'Fire', 'Rainbow',
  ],
  vi: [
    'Sức mạnh', 'Skin hố', 'Hiệu ứng', 'Vệt đi', 'Trang bị', 'Đang dùng', 'Nam châm', 'Thưởng xu',
    'Cổ điển', 'Kẹo gậy', 'Chất nhờn độc', 'Vòng lửa', 'Thiên hà', 'Cầu vồng neon', 'Vòng hoa Giáng sinh', 'VIP Vàng',
    'Bụi', 'Pháo giấy', 'Trái tim', 'Ngôi sao', 'Mưa xu', 'Pixel', 'Bông tuyết',
    'Không', 'Bong bóng', 'Lấp lánh', 'Tuyết', 'Lửa', 'Cầu vồng',
  ],
  es: [
    'Poder', 'Aspectos', 'Efectos', 'Estelas', 'Equipar', 'Equipado', 'Imán', 'Bonus de monedas',
    'Clásico', 'Bastón de caramelo', 'Baba tóxica', 'Anillo de fuego', 'Galaxia', 'Arcoíris neón', 'Corona navideña', 'VIP dorado',
    'Polvo', 'Confeti', 'Corazones', 'Estrellas', 'Lluvia de monedas', 'Píxeles', 'Copos de nieve',
    'Ninguna', 'Burbujas', 'Destellos', 'Nieve', 'Fuego', 'Arcoíris',
  ],
  pt: [
    'Poder', 'Visuais', 'Efeitos', 'Rastros', 'Equipar', 'Equipado', 'Ímã', 'Bônus de moedas',
    'Clássico', 'Bengala doce', 'Gosma tóxica', 'Anel de fogo', 'Galáxia', 'Arco-íris neon', 'Guirlanda de Natal', 'VIP dourado',
    'Poeira', 'Confete', 'Corações', 'Estrelas', 'Chuva de moedas', 'Pixels', 'Flocos de neve',
    'Nenhum', 'Bolhas', 'Brilhos', 'Neve', 'Fogo', 'Arco-íris',
  ],
  fr: [
    'Pouvoir', 'Skins', 'Effets', 'Traînées', 'Équiper', 'Équipé', 'Aimant', 'Bonus de pièces',
    'Classique', 'Sucre d’orge', 'Slime toxique', 'Anneau de feu', 'Galaxie', 'Arc-en-ciel néon', 'Couronne de Noël', 'VIP doré',
    'Poussière', 'Confettis', 'Cœurs', 'Étoiles', 'Pluie de pièces', 'Pixels', 'Flocons',
    'Aucune', 'Bulles', 'Paillettes', 'Neige', 'Feu', 'Arc-en-ciel',
  ],
  de: [
    'Power', 'Skins', 'Effekte', 'Spuren', 'Anlegen', 'Ausgerüstet', 'Magnet', 'Münzbonus',
    'Klassisch', 'Zuckerstange', 'Giftschleim', 'Feuerring', 'Galaxie', 'Neon-Regenbogen', 'Weihnachtskranz', 'Gold-VIP',
    'Staub', 'Konfetti', 'Herzen', 'Sterne', 'Münzregen', 'Pixel', 'Schneeflocken',
    'Keine', 'Blasen', 'Funkeln', 'Schnee', 'Feuer', 'Regenbogen',
  ],
  it: [
    'Potenza', 'Skin', 'Effetti', 'Scie', 'Equipaggia', 'Equipaggiato', 'Calamita', 'Bonus monete',
    'Classico', 'Bastoncino di zucchero', 'Melma tossica', 'Anello di fuoco', 'Galassia', 'Arcobaleno neon', 'Ghirlanda di Natale', 'VIP dorato',
    'Polvere', 'Coriandoli', 'Cuori', 'Stelle', 'Pioggia di monete', 'Pixel', 'Fiocchi di neve',
    'Nessuna', 'Bolle', 'Scintille', 'Neve', 'Fuoco', 'Arcobaleno',
  ],
  tr: [
    'Güç', 'Görünümler', 'Efektler', 'İzler', 'Kuşan', 'Kuşanıldı', 'Mıknatıs', 'Altın Bonusu',
    'Klasik', 'Şeker Baston', 'Zehirli Balçık', 'Ateş Halkası', 'Galaksi', 'Neon Gökkuşağı', 'Noel Çelengi', 'Altın VIP',
    'Toz', 'Konfeti', 'Kalpler', 'Yıldızlar', 'Altın Yağmuru', 'Pikseller', 'Kar Taneleri',
    'Yok', 'Baloncuklar', 'Işıltı', 'Kar', 'Ateş', 'Gökkuşağı',
  ],
  ru: [
    'Сила', 'Скины', 'Эффекты', 'Следы', 'Надеть', 'Надето', 'Магнит', 'Бонус монет',
    'Классика', 'Леденец-трость', 'Токсичная слизь', 'Огненное кольцо', 'Галактика', 'Неоновая радуга', 'Рождественский венок', 'Золотой VIP',
    'Пыль', 'Конфетти', 'Сердечки', 'Звёзды', 'Дождь монет', 'Пиксели', 'Снежинки',
    'Нет', 'Пузыри', 'Искры', 'Снег', 'Огонь', 'Радуга',
  ],
  pl: [
    'Moc', 'Skórki', 'Efekty', 'Smugi', 'Załóż', 'Założone', 'Magnes', 'Bonus monet',
    'Klasyczna', 'Laska cukrowa', 'Toksyczny szlam', 'Pierścień ognia', 'Galaktyka', 'Neonowa tęcza', 'Wieniec świąteczny', 'Złoty VIP',
    'Kurz', 'Konfetti', 'Serduszka', 'Gwiazdki', 'Deszcz monet', 'Piksele', 'Płatki śniegu',
    'Brak', 'Bańki', 'Iskierki', 'Śnieg', 'Ogień', 'Tęcza',
  ],
  hi: [
    'पावर', 'स्किन', 'इफ़ेक्ट', 'ट्रेल', 'लगाएँ', 'लगा हुआ', 'चुंबक', 'सिक्का बोनस',
    'क्लासिक', 'कैंडी केन', 'ज़हरीला स्लाइम', 'आग का घेरा', 'गैलेक्सी', 'नियॉन इंद्रधनुष', 'क्रिसमस माला', 'गोल्डन VIP',
    'धूल', 'कंफ़ेटी', 'दिल', 'सितारे', 'सिक्कों की बारिश', 'पिक्सेल', 'बर्फ़ के फाहे',
    'कोई नहीं', 'बुलबुले', 'चमक', 'बर्फ़', 'आग', 'इंद्रधनुष',
  ],
  id: [
    'Kekuatan', 'Skin', 'Efek', 'Jejak', 'Pakai', 'Dipakai', 'Magnet', 'Bonus Koin',
    'Klasik', 'Permen Tongkat', 'Lendir Beracun', 'Cincin Api', 'Galaksi', 'Pelangi Neon', 'Karangan Natal', 'VIP Emas',
    'Debu', 'Konfeti', 'Hati', 'Bintang', 'Hujan Koin', 'Piksel', 'Kepingan Salju',
    'Tidak ada', 'Gelembung', 'Kilau', 'Salju', 'Api', 'Pelangi',
  ],
  ms: [
    'Kuasa', 'Kulit', 'Kesan', 'Jejak', 'Guna', 'Sedang Guna', 'Magnet', 'Bonus Syiling',
    'Klasik', 'Gula-gula Tongkat', 'Lendir Toksik', 'Cincin Api', 'Galaksi', 'Pelangi Neon', 'Kalungan Krismas', 'VIP Emas',
    'Debu', 'Konfeti', 'Hati', 'Bintang', 'Hujan Syiling', 'Piksel', 'Emping Salji',
    'Tiada', 'Buih', 'Kilauan', 'Salji', 'Api', 'Pelangi',
  ],
  th: [
    'พลัง', 'สกิน', 'เอฟเฟกต์', 'รอยทาง', 'ใช้', 'กำลังใช้', 'แม่เหล็ก', 'โบนัสเหรียญ',
    'คลาสสิก', 'ลูกอมไม้เท้า', 'เมือกพิษ', 'วงแหวนไฟ', 'กาแล็กซี', 'นีออนสายรุ้ง', 'พวงหรีดคริสต์มาส', 'VIP ทองคำ',
    'ฝุ่น', 'กระดาษสี', 'หัวใจ', 'ดวงดาว', 'ฝนเหรียญ', 'พิกเซล', 'เกล็ดหิมะ',
    'ไม่มี', 'ฟองสบู่', 'ประกาย', 'หิมะ', 'ไฟ', 'สายรุ้ง',
  ],
  ja: [
    'パワー', 'スキン', 'エフェクト', '軌跡', '装備', '装備中', 'マグネット', 'コインボーナス',
    'クラシック', 'キャンディケーン', '毒スライム', '炎のリング', 'ギャラクシー', 'ネオンレインボー', 'クリスマスリース', 'ゴールドVIP',
    'ほこり', '紙吹雪', 'ハート', 'スター', 'コインシャワー', 'ピクセル', '雪の結晶',
    'なし', 'バブル', 'キラキラ', '雪', '炎', '虹',
  ],
  ko: [
    '파워', '스킨', '이펙트', '궤적', '장착', '장착 중', '자석', '코인 보너스',
    '클래식', '지팡이 사탕', '독성 슬라임', '불의 고리', '은하수', '네온 무지개', '크리스마스 리스', '골드 VIP',
    '먼지', '색종이', '하트', '별', '코인 폭발', '픽셀', '눈송이',
    '없음', '거품', '반짝이', '눈', '불꽃', '무지개',
  ],
  ar: [
    'القوة', 'المظاهر', 'المؤثرات', 'الآثار', 'تجهيز', 'مُجهّز', 'مغناطيس', 'مكافأة العملات',
    'كلاسيكي', 'عصا الحلوى', 'الوحل السام', 'حلقة النار', 'المجرة', 'قوس قزح نيون', 'إكليل الميلاد', 'VIP ذهبي',
    'غبار', 'قصاصات ملونة', 'قلوب', 'نجوم', 'مطر العملات', 'بكسلات', 'ندف الثلج',
    'بلا', 'فقاعات', 'بريق', 'ثلج', 'نار', 'قوس قزح',
  ],
};

export const SHOP_STRINGS = Object.fromEntries(
  Object.entries(TABLE).map(([lang, values]) => [lang, Object.fromEntries(KEYS.map((k, i) => [k, values[i]]))])
);
