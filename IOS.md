# Chạy Hole Munch trên iOS

**Bản Godot 3D mới:** xem [godot/IOS.md](godot/IOS.md). Các lệnh bên dưới dành cho bản web Capacitor.

Project: `ios/App/App.xcworkspace`. Bundle ID: `io.github.phucpdbk.holemunch`.
Game chạy offline, màn hình dọc trên iPhone/iPad; quảng cáo cần mạng.

## Trên Mac

Cài Node.js 20+, Xcode 16+ và CocoaPods. Mở Xcode một lần để hoàn tất cài đặt,
chọn Xcode trong Settings → Locations → Command Line Tools.
Project hiện đặt deployment target iOS 14.0.

Chép repository sang Mac (bao gồm thư mục `ios`, không cần `node_modules`), rồi chạy tại thư mục gốc:

```sh
npm ci
npm run build:ios
npm run open:ios
```

`build:ios` đóng gói game vào `www`, chép vào app và chạy CocoaPods qua Capacitor.
Trong Xcode chọn scheme **App**, chọn iPhone simulator rồi bấm **Run**.
Với iPhone thật: kết nối thiết bị, mở target **App → Signing & Capabilities**,
bật **Automatically manage signing**, chọn **Team** của bạn và bật Developer Mode
trên iPhone nếu được yêu cầu. Đổi Bundle Identifier nếu Team không đăng ký được ID hiện tại;
đồng thời cập nhật `appId` trong `capacitor.config.json` cho nhất quán.

Sau mỗi lần sửa game, chạy lại `npm run build:ios` trước khi Run.
`npm run run:ios` cho phép chọn thiết bị từ terminal.
`npm run icons:ios` tạo lại icon từ cùng hình bìa đang dùng cho Android.

## Quảng cáo và phát hành

Đang dùng Google test app ID trong `ios/App/App/Info.plist` và test ad unit IDs
riêng cho iOS trong `src/ads-config.js`. Giữ nguyên khi phát triển.
Game giữ cấu hình quảng cáo dành cho trẻ em, nội dung G; không gọi yêu cầu quyền tracking.
SKAdNetwork hiện khai báo mạng Google; khi phát hành kiểm tra danh sách mạng cần dùng
theo SDK và các đối tác quảng cáo của bạn.

Trước TestFlight/App Store: thay ID iOS bằng ID của bạn, chọn Team, đặt version/build
trong Xcode, kiểm tra privacy manifest/App Privacy theo SDK thực tế và chính sách riêng tư,
sau đó **Product → Archive → Distribute App** bằng tài khoản Apple Developer phù hợp.
Podfile.lock nên được commit sau lần `pod install` thành công trên Mac để cố định SDK native.

## Phạm vi kiểm tra trên Windows

Có thể tạo project, build web assets và chạy kiểm tra JavaScript trên Windows.
CocoaPods, biên dịch Swift, simulator, ký app và xuất IPA cần thực hiện trên Mac;
`cap sync ios` trên Windows có thể báo bỏ qua CocoaPods/Xcode, không có nghĩa là đã build native.

Tài liệu: [Capacitor 7 iOS](https://capacitorjs.com/docs/v7/ios),
[AdMob iOS setup](https://developers.google.com/admob/ios/quick-start),
[AdMob test IDs](https://developers.google.com/admob/ios/test-ads).
