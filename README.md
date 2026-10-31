# TiuXai — điểm ảo cho bài thực hành PRM393

Ứng dụng Flutter Android/Firebase viết lại độc lập. **Không có tiền thật, nạp/rút/chuyển đổi, quà hay hiện vật.** Hai tài khoản player và admin dùng Firebase Auth; ví điểm và mọi kết quả do Cloud Functions kiểm soát. Không nhập source, dependency, credential hay asset Go88. Giao diện vẽ bằng Flutter.

## Hiện trạng (01/11/2026)

- **Chơi được trên Emulator:** Tài/Xỉu, Bầu Cua, Xóc Xóc (ba phòng phiên độc lập). Mỗi phiên 30 giây, một cược/người, 10–1000 điểm, tối đa 100 cược. Admin mở phiên random hoặc chọn kết quả hợp lệ **sau khi khóa cược**; kết quả không sửa lại được. Mọi chọn kết quả, lý do và tác động ví được ghi `auditLogs` **chỉ admin đọc**. `tick` khóa phiên quá hạn và tự chốt random trên Firebase thật; Emulator không tự chạy Scheduler, admin nhấn Khóa/Chốt thủ công.
- **Nền tảng luật/test:** module đánh giá Poker Texas Hold’em và Ba Cây (`functions/src/card_games.js`). **Poker/Ba Cây chưa có phòng đa người, bot hay UI chơi; không công bố là đã chơi được.** Đây là mốc tiếp theo.
- Email/password, hồ sơ khởi tạo 10.000 điểm một lần, lịch sử ledger, admin điều chỉnh điểm có lý do/requestId, khóa tài khoản. Không còn callable nạp/rút.
- Backend giới hạn quyền bằng admin custom claim; Firestore client chỉ đọc dữ liệu cho phép, không được ghi. Firestore audit không phải hệ thống chứng cứ bất biến trước chủ Firebase project.

## Chạy local

Yêu cầu Flutter SDK/Dart >=3.8, Node 22, Java 21 (Java 25 trên máy phát triển đã chạy Emulator), Android SDK. Từ **gốc repo**:

```powershell
flutter pub get
npm.cmd --prefix functions ci
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:start --project demo-tai-xiu --only auth,firestore,functions
```

Mở terminal khác:

```powershell
flutter run -d <android-device-id> --dart-define=EMULATOR_HOST=10.0.2.2
```

Android Emulator truy cập host qua `10.0.2.2`; thiết bị thật cần IP LAN máy chạy Emulator và kết nối cùng mạng. Không mở public Emulator. Có thể dùng `flutter run -d chrome` trên cùng máy với host mặc định `127.0.0.1`. Debug mặc định dùng Emulator; release mặc định **không** dùng Emulator. Cấu hình Firebase thật qua các `--dart-define` tên `FIREBASE_*` trong `lib/main.dart`; không commit secret/service account. Dự án Firebase thật cần bật Email/Password, Firestore, Functions, thiết lập claim admin, kiểm App Check và billing trước demo.

Tạo user bằng form đăng ký. Cấp quyền admin **chỉ cho UID tin cậy** (Emulator):

```powershell
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:GCLOUD_PROJECT='demo-tai-xiu'
node functions/scripts/set-admin.js UID_CUA_BAN
```

Đăng xuất/đăng nhập để refresh claim. Script `functions/scripts/seed-emulator.js` có tài khoản demo mật khẩu công khai, **chỉ dùng trên Emulator**, không dùng production.

## Kiểm thử

```powershell
flutter analyze
flutter test
flutter build apk --debug
npm.cmd --prefix functions test
npm.cmd --prefix functions run check
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --project demo-tai-xiu --only auth,firestore,functions "node --test functions/integration/emulator.test.js"
```

CI chạy test Flutter, Android debug build, Functions và Emulator. Không có APK release có chữ ký phân phối hay deploy production trong repo. Không đưa `google-services.json`, key ký APK hoặc mật khẩu vào Git.

## Quy tắc và hạn chế

- Tài/Xỉu: ba xúc xắc 1–6, bộ ba thua cả Tài/Xỉu, còn lại tổng <=10 Xỉu, >=11 Tài, trúng 2× cược gồm vốn.
- Bầu Cua: ba mặt trong `bau,cua,tom,ca,ga,nai`; trúng nhận `(1+số mặt khớp)×cược`.
- Xóc Xóc: **quy tắc mô phỏng tự chọn** bốn bit 0/1; tổng chẵn/lẻ, trúng 2× cược. Cần nhóm xác nhận luật mong muốn trước buổi demo.
- Player nhìn thấy chế độ `random/admin` của phiên trước cược nhưng **không** được đọc audit/lý do, thông tin cá nhân người khác. Cần nêu rõ với lớp rằng admin có thể chọn kết quả; không trình bày như trò ngẫu nhiên công bằng nếu là phiên admin.
- Scheduler có thể chậm tối đa một chu kỳ; sau hạn cược server từ chối cược dù UI còn `open`. Transaction chống chốt/hủy lặp. Chưa benchmark tải, chưa xử lý đầy đủ offline/reconnect, chưa có bot, mời bạn, App Check enforcement hoặc sản phẩm APK ký release.

Xem `docs/ARCHITECTURE.md` và `docs/VALIDATION.md`. Lịch sử Git vẫn giữ bản cũ; tag `backup/pre-rebuild-main-2026-11-01`, `backup/pre-rebuild-hiep-2026-11-01` và bundle ngoại repo là điểm rollback. Không force-push.
