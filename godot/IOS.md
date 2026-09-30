# Chạy bản Godot 3D trên iPhone

Đã cấu hình preset **iOS Godot**, ARM64, iPhone, màn hình ngang (cả hai chiều) và Compatibility
renderer. Bundle ID mặc định: `org.holemunch.pocketcity.prototype`.
Deployment target iOS 15.0 theo preset của Godot 4.7.1 đang dùng.
Đây là bản Godot có 36 màn; thư mục `ios/App` ở gốc repo thuộc bản web Capacitor.

## Chuẩn bị Mac

1. Cài Xcode, mở một lần để cài các thành phần cần thiết và chấp nhận license.
   Trong Xcode → Settings → Locations, chọn Command Line Tools của Xcode.
2. Cài **Godot 4.7.1 stable** vào Applications. Trong Godot chọn
   **Editor → Manage Export Templates → Download and Install** bản 4.7.1.
3. Chép thư mục `godot` sang Mac. Không cần chép `.godot`, `builds`, `test-output`;
   không cần Node, CocoaPods hay Android SDK cho bản này.
4. Trong Xcode → Settings → Accounts, đăng nhập Apple ID. Lấy Apple Team ID
   gồm 10 ký tự từ tài khoản developer của bạn; không dùng tên hiển thị của Team.

## Xuất và chạy

Mở Terminal trong thư mục `godot` trên Mac:

```bash
export HOLE_IOS_TEAM_ID="THAY_BANG_TEAM_ID_CUA_BAN"
bash tools/build-ios.sh
```

Script kiểm tra Godot/Xcode/template, xuất sang thư mục mới dưới `builds/ios/`,
rồi mở `HoleMunch.xcodeproj`. Team ID chỉ truyền vào lúc xuất, không ghi vào repo.
Tên đuôi `.ipa` là đường dẫn exporter yêu cầu; preset chỉ xuất project Xcode,
**chưa tạo IPA đã ký**.

Trong Xcode:

1. Chọn target **HoleMunch → Signing & Capabilities**.
2. Bật **Automatically manage signing**, chọn Team của bạn.
3. Nếu Bundle Identifier bị trùng, dùng ID riêng. Để những lần xuất sau giữ ID đó:
   `export HOLE_IOS_BUNDLE_ID="com.tenban.holemunch"`.
4. Kết nối iPhone, Trust máy Mac, bật Developer Mode khi thiết bị yêu cầu.
5. Chọn iPhone ở thanh thiết bị, bấm **Run**. Có thể chọn iPhone Simulator đã cài
   để kiểm tra trước; renderer hiện tại là Compatibility.

Sau khi sửa game, chạy lại script và dùng project mới được mở. Script giữ các
project cũ, vì vậy thay đổi signing thủ công trong Xcode cũ không tự chuyển sang bản mới.
`GODOT_BIN` cho phép chỉ định đường dẫn Godot khác; `HOLE_IOS_OPEN_XCODE=0` tắt tự mở Xcode.

Nếu Xcode không tìm thấy iPhone SDK, chọn lại Command Line Tools trong Settings.
Nếu ký lỗi, kiểm tra Apple account, Team và Bundle ID ngay trong Xcode.
TestFlight/App Store cần cấu hình phát hành và ký riêng; script này phục vụ chạy thử.

## Kiểm tra đã thực hiện

Trên Windows có thể kiểm tra từng option bằng API exporter thật:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --script res://tools/export_ios.gd -- --check
```

Chưa biên dịch Xcode, ký IPA hay chạy trên iPhone trong môi trường Windows này.
Sau khi Run trên thiết bị, kiểm tra vùng tai thỏ/home indicator, thao tác kéo,
pause khi chuyển app, lưu tiến trình sau khi đóng/mở và FPS màn giông/tuyết.

Tài liệu chính thức: [Godot iOS export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).
