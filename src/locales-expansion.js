// New destinations use English fallback in other supported languages.
const en = {
  dino: ['Jurassic Gardens', 'Dino King', 'Millions of years, one very hungry hole.'],
  crab: ['Coral Coast', 'Captain Claws', 'All claws. No escape.'],
  dragon: ['Ember Valley', 'Ember Dragon', 'That was a spicy snack!'],
  robot: ['Neon District', 'Mega Bot', 'Error 404: city not found.'],
  yeti: ['Frostpeak', 'Fluffy Yeti', 'The biggest snowball on the menu.'],
  donut: ['Sugar Boulevard', 'Donut Queen', 'A hole swallowed another hole.'],
  sydney: ['Sydney Harbour', 'Sydney Opera House', 'The final encore went underground.'],
  petra: ['Rose Canyon', 'Petra Treasury', 'A rose-red wonder, gone in a gulp.'],
  pagoda: ['Hanoi Sunset', 'Tran Quoc Pagoda', 'Eleven floors. One delicious dive.'],
  burj: ['Dubai Skyline', 'Burj Khalifa', 'From the tallest tower to the deepest hole.'],
  sphinx: ['Golden Giza', 'Great Sphinx', 'The riddle was: how hungry are you?'],
  saintbasil: ['Winter Square', "Saint Basil’s Cathedral", 'The most colorful bite of the day.'],
};
const vi = {
  dino: ['Vườn khủng long', 'Vua Khủng Long', 'Triệu năm tiến hóa, một cú nuốt gọn.'],
  crab: ['Bờ biển san hô', 'Thuyền trưởng Cua', 'Càng to đến mấy cũng chào thua!'],
  dragon: ['Thung lũng lửa', 'Rồng Lửa', 'Món này hơi cay nha!'],
  robot: ['Thành phố neon', 'Siêu Robot', 'Lỗi 404: không tìm thấy thành phố.'],
  yeti: ['Đỉnh băng tuyết', 'Yeti Bông Xù', 'Viên tuyết khổng lồ đã vào bụng!'],
  donut: ['Đại lộ kẹo ngọt', 'Nữ hoàng Donut', 'Một cái hố vừa nuốt một cái lỗ.'],
  sydney: ['Cảng Sydney', 'Nhà hát Opera Sydney', 'Màn diễn cuối cùng ở dưới lòng đất.'],
  petra: ['Hẻm núi hoa hồng', 'Đền Al-Khazneh', 'Kỳ quan đá hồng, gọn trong một miếng.'],
  pagoda: ['Hoàng hôn Hà Nội', 'Chùa Trấn Quốc', 'Mười một tầng, một cú nuốt ngoạn mục.'],
  burj: ['Đường chân trời Dubai', 'Tháp Burj Khalifa', 'Từ tòa tháp cao nhất xuống chiếc hố sâu nhất.'],
  sphinx: ['Giza vàng rực', 'Tượng Nhân Sư', 'Câu đố hôm nay: bạn đói cỡ nào?'],
  saintbasil: ['Quảng trường mùa đông', 'Nhà thờ Thánh Basil', 'Miếng ăn rực rỡ nhất hôm nay!'],
};
function strings(table) {
  return Object.fromEntries(Object.entries(table).flatMap(([id, values]) =>
    ['Name', 'Boss', 'Twist'].map((suffix, i) => [id + suffix, values[i]])));
}
export const EXPANSION_STRINGS = {
  en: { ...strings(en), worldTour: 'WORLD TOUR', campaignInfo: '{levels} levels · {bosses} bosses · {places} landmarks', coverPitch: 'Start small. Swallow the world.', journey: 'Your next big bite awaits.' },
  vi: { ...strings(vi), worldTour: 'VÒNG QUANH THẾ GIỚI', campaignInfo: '{levels} màn · {bosses} boss · {places} địa danh', coverPitch: 'Khởi đầu bé xíu. Nuốt trọn thế giới.', journey: 'Cuộc phiêu lưu mới đang chờ bạn.' },
};
