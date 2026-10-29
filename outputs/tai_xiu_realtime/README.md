# Tài Xỉu realtime — nhóm 5 người

MVP Flutter/Dart + Firebase Auth + Firestore + Cloud Functions, chỉ dùng xu giả lập. Không có thanh toán/đổi tiền. Android và Web được tạo sẵn; bản web đã build được. Mọi quyết định cược, ví, kết quả ở server.

## Đã có
- Email/password, Player và Admin bằng custom claim.
- Ví khởi tạo 10000 xu; nạp/rút xu giả lập; transaction và requestId chống xử lý lặp.
- Một phòng main realtime, phiên 30 giây, một cược/người, tối đa 100 người.
- RANDOM ngẫu nhiên server; ADMIN công khai trước nhận cược, lý do và xúc xắc lưu audit.
- Lịch sử phiên, cược cá nhân, số dư và audit qua Firestore snapshots.
- Admin khóa/mở khóa truy cập game, điều chỉnh ví có lý do, hủy phiên hoàn xu và xem cược toàn phòng.
- Lịch sử ví có cược/trả thưởng/hoàn cược/điều chỉnh; lưu yêu cầu ví chờ xác nhận để retry cùng requestId.
- Rules cấm mọi client write, test luật 216 tổ hợp, test Emulator quyền/race/retry.

## Cấu trúc
```
lib/main.dart                 Lobby + Firebase bootstrap
lib/core/pending_mutation.dart Lưu thao tác ví đang chờ
lib/features/admin/           Quản lý tài khoản/ví
lib/features/game/            Cược toàn phòng
functions/src/index.js        callable API, transaction, scheduler
functions/src/game.js         luật và payout thuần
functions/test/               unit test Node
functions/integration/        integration Emulator
functions/scripts/set-admin.js
firestore.rules               quyền đọc, cấm client write
firestore.indexes.json        index scheduler
firebase.json                 emulator và deploy
config/firebase.example.json  mẫu cấu hình Firebase thật
android/ web/                 platform Flutter
 test/                        kiểm tra mặc định emulator
 docs/PLAN.md                 phân công 5 người + lịch 15 ngày
 docs/ARCHITECTURE.md          schema, API, state machine, luật
 docs/ACCEPTANCE.md            checklist nghiệm thu nhiều người
 docs/VALIDATION.md            kết quả kiểm tra thực tế
```

## Chạy local không cần Firebase thật
Cần Flutter stable (Dart >=3.8), Node 22, Java 21, Chrome. Node trên máy tạo dự án là 24 nên npm có cảnh báo engine; runtime triển khai cấu hình Node 22. Mở terminal tại folder này:

```powershell
flutter pub get
npm.cmd --prefix functions ci
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:start --project demo-tai-xiu --only auth,firestore,functions
```
Giữ terminal emulator mở, terminal thứ hai:
```powershell
flutter run -d chrome
```
App mặc định EMULATORS=true, project demo-tai-xiu; Auth 9099, Firestore 8080, Functions 5001, UI Emulator 4000. Đăng ký email/password trong app (tài khoản emulator không phải tài khoản thật). Mở nhiều browser/incognito cho nhiều người. Dữ liệu emulator mặc định mất khi tắt; dùng --export-on-exit và --import nếu cần giữ dữ liệu.

Cấp admin cho UID hiện trong app (terminal khác):
```powershell
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:GCLOUD_PROJECT='demo-tai-xiu'
node functions/scripts/set-admin.js UID_CUA_BAN
```
Đăng xuất/đăng nhập để nhận claim mới. Thu hồi: thêm `revoke` sau UID. Không đưa key tài khoản dịch vụ vào repo. Chỉ chủ project tin cậy chạy script này.

Admin mở phiên, Player cược. Sau 30 giây admin bấm Chốt kết quả. Emulator không tự chạy Cloud Scheduler. Phiên RANDOM bỏ qua dice/reason admin nhập; ADMIN yêu cầu dice hợp lệ và lý do 5–300 ký tự. Lịch sử/audit hiện phía dưới. Nạp/rút là tạo/hủy xu giả lập, không liên kết tài khoản thanh toán.

Android emulator truy cập máy host qua 10.0.2.2:
```powershell
flutter run --dart-define=EMULATOR_HOST=10.0.2.2
```
Debug manifest cho phép HTTP emulator; release chỉ dùng Firebase HTTPS. Nếu dùng điện thoại thật, cấu hình emulator bind mạng LAN và dùng IP máy host, chỉ trong mạng thử nghiệm tin cậy. Không dùng 127.0.0.1 của điện thoại.

## Kiểm tra
```powershell
flutter analyze
flutter test
flutter build web
npm.cmd --prefix functions test
npm.cmd --prefix functions run check
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --project demo-tai-xiu --only auth,firestore,functions "node --test functions/integration/emulator.test.js"
flutter build apk --debug
```
Test integration tự tạo tài khoản emulator, cấp role, chạy 5 Player, đặt cược trùng, chốt lặp, ví retry, thử chặn quyền; chỉ chạy với demo project. Đọc docs/VALIDATION.md để phân biệt đã chạy và chưa chạy. Test Flutter hiện kiểm tra config và lưu/khôi phục/chống ghi đè thao tác chờ, chưa phải kiểm thử UI đầy đủ. Nghiệm thu tương tác theo docs/ACCEPTANCE.md.

## Cấu hình Firebase thật (chưa thực hiện)
1. Tạo project Firebase riêng. Bật Auth Email/Password và tạo Firestore. Chọn region phù hợp, Functions code dùng asia-southeast1. Deploy Functions/scheduler cần project có billing phù hợp; kiểm tra console trước khi deploy.
2. Đăng ký Web/Android app. Copy Firebase SDK config từ Console vào `config/firebase.local.json` dựa theo example; dùng appId đúng platform. main.dart khởi tạo bằng FirebaseOptions từ dart-define, không phụ thuộc file firebase_options.dart. Có thể dùng FlutterFire CLI lấy config rồi chuyển sang các giá trị này; nếu chuyển sang DefaultFirebaseOptions.currentPlatform thì sửa bootstrap tương ứng.
3. Thêm domain hosting vào Auth authorized domains. Không commit service-account JSON. Firebase client apiKey không phải Admin credential; quyền được bảo vệ ở Auth/rules/functions.
4. Đăng nhập CLI, chọn đúng project, deploy rules/indexes/functions:
```powershell
node functions/node_modules/firebase-tools/lib/bin/firebase.js login
node functions/node_modules/firebase-tools/lib/bin/firebase.js deploy --project YOUR_PROJECT_ID --only firestore,functions
flutter run -d chrome --dart-define-from-file=config/firebase.local.json
flutter build web --dart-define-from-file=config/firebase.local.json
node functions/node_modules/firebase-tools/lib/bin/firebase.js deploy --project YOUR_PROJECT_ID --only hosting
```
5. Cấp admin bằng ADC/tài khoản dịch vụ tin cậy và script, bỏ biến FIREBASE_AUTH_EMULATOR_HOST trước khi thao tác thật. Project đích phải khớp ADC/GCLOUD_PROJECT. Đăng nhập lại.
6. Kiểm tra scheduler tick, composite index đã sẵn sàng và quyền tài khoản dịch vụ. RANDOM tự chốt mỗi phút (không chính xác ngay giây 30). ADMIN chờ chốt thủ công. Không tự mở phiên mới.

## Giới hạn rõ ràng
Admin có mở/chốt/hủy-hoàn phiên, điều chỉnh ví, khóa/mở khóa truy cập game và đọc cược toàn phòng. Không cấp quyền sửa Firestore trực tiếp. Khóa game không xóa tài khoản Firebase Auth, không ngăn đăng nhập; API và rules chặn sử dụng game, user vẫn đọc ví/lịch sử và audit. Một phòng, 100 người, chưa benchmark. Chưa App Check/rate limit ngày; nạp xu được lặp để demo. Audit bất biến với client nhưng chủ Firebase vẫn có quyền sửa, chưa WORM. RANDOM chưa commit/reveal. Đồng hồ UI chỉ tham khảo, deadline server quyết định. Retry ví bên ngoài SDK phải giữ nguyên requestId; UI lưu requestId/payload trước khi gửi; sau reload dùng nút Thử lại thao tác chờ. Không xóa dữ liệu trình duyệt khi còn thao tác chờ; các cửa sổ khác nhau có thể tạo ý định riêng. Không dùng MVP này như hệ thống tiền thật.

Tài liệu tham khảo: https://firebase.google.com/docs/flutter/setup ; https://firebase.google.com/docs/functions/callable ; https://firebase.google.com/docs/firestore/manage-data/transactions


## Quản trị bổ sung (bản hoàn thiện)
- Mở “Quản lý tài khoản & ví xu”: chọn UID, nhập số xu điều chỉnh dương/âm và lý do 5–300 ký tự. Mỗi lần tối đa ±100000, số dư sau điều chỉnh 0–1000000. Có requestId chống cộng/trừ lặp.
- Khóa/mở khóa truy cập game: có hiệu lực với token đăng nhập hiện tại; không cần người chơi đăng xuất. Ví vẫn nhận trả thưởng/hoàn cược của cược đã đặt trước khóa. Admin không thể tự khóa mình. Không phải disable tài khoản Firebase Auth.
- Hủy phiên: nhập lý do vào ô lý do phiên, bấm Hủy phiên & hoàn xu. Chỉ hủy phiên còn open (kể cả đã hết giờ nhưng chưa chốt); hoàn nguyên toàn bộ cược, lưu CANCEL audit. Phiên settled không được hủy; phiên cancelled không được chốt.
- Xem “Cược toàn phòng”: UID, phía cược, số xu, ghi có; tổng Tài/Xỉu. Player chỉ đọc cược riêng.
- Lịch sử ví hiện 30 dòng gần nhất; lịch sử cũ trước nâng cấp không tự backfill ledger, số dư không bị reset. users thiếu blocked mặc định coi là hoạt động; không cần migration reset dữ liệu.
- Nếu thao tác ví mất kết nối: app giữ requestId và payload trong local storage. Tải lại/đăng nhập lại rồi bấm Thử lại thao tác chờ. Request đã xử lý sẽ trả kết quả cũ. Thao tác mới bị chặn cho đến khi thao tác chờ được xác nhận hoặc bị server từ chối dứt khoát. Đây là hỗ trợ retry trên cùng bộ nhớ app/browser; không thay thế đồng bộ nhiều tab hay kiểm toán server.
- Workflow ở gốc repository `.github/workflows/ci.yml` chạy các lệnh trong `outputs/tai_xiu_realtime`: Flutter analyze/test/build Web/Android debug, Node unit/check/audit runtime và Emulator integration trên Node 22/Java 21. Cần push để GitHub Actions thực sự chạy; kiểm tra local không thay thế CI remote.

## Tạo sẵn tài khoản demo cho 5 người
Khi Emulator đang chạy, mở terminal tại project:
```powershell
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:GCLOUD_PROJECT='demo-tai-xiu'
node functions/scripts/seed-emulator.js
```
Admin: admin@demo.test; 5 Player: player1@demo.test đến player5@demo.test. Mật khẩu demo chung: Demo123456!. Script có chốt kiểm project/emulator, không dùng để tạo tài khoản thật. Không reset số dư khi chạy lại. Đăng nhập app để tự tạo ví; nếu tài khoản đã tồn tại từ trước thì script không đổi mật khẩu hiện có.
