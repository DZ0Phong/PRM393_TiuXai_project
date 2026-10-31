# TiuXai — điểm ảo cho bài thực hành PRM393

Ứng dụng Flutter Android/Firebase viết lại độc lập. **Không có tiền thật, nạp/rút/chuyển đổi, quà hay hiện vật.** Hai tài khoản player và admin dùng Firebase Auth; ví điểm và mọi kết quả do Cloud Functions kiểm soát. Không nhập source, dependency, credential hay asset Go88. Giao diện vẽ bằng Flutter.

## Hiện trạng (01/11/2026)

- **Chơi được trên Emulator:** Tài/Xỉu, Bầu Cua, Xóc Xóc (ba phòng phiên độc lập). Mỗi phiên 30 giây, một cược/người, 10–1000 điểm, tối đa 100 cược. Admin mở phiên random hoặc chọn kết quả hợp lệ **sau khi khóa cược**; kết quả không sửa lại được. Mọi chọn kết quả, lý do và tác động ví được ghi `auditLogs` **chỉ admin đọc**. `tick` khóa phiên quá hạn và tự chốt random trên Firebase thật; Emulator không tự chạy Scheduler, admin nhấn Khóa/Chốt thủ công.
- **Poker/Ba Cây chơi được trên Emulator:** bàn 2–6 ghế, mua vào 10× ante (ante 10–100), tham gia bằng mã bàn, chủ bàn bắt đầu khi đủ tối thiểu 2 ghế. Admin cấu hình tối đa 0–5 bot theo sức chứa bàn, hủy/hoàn với lý do. Ba Cây chia ba lá và so 10 điểm ngay; Poker Texas Hold’em ante, cược giới hạn cố định, 4 vòng, một lần raise mỗi vòng, kiểm all-in/side-pot. Mỗi lượt 45 giây; scheduler tự check/fold khi quá hạn, bot dùng cùng engine và ví/ledger. Bài riêng chỉ chủ bài đọc. Bot vào ghế đang chờ khi admin bật/điều chỉnh cấu hình; ghế công khai chỉ hiện biệt danh chung, không có nhãn bot. Cấu hình và danh tính bot chỉ admin/server xem được. Không mạo danh bạn học; nhóm giải thích cơ chế trong phần tổng kết. Một ván/bàn; muốn chơi tiếp tạo bàn mới.
- Email/password, hồ sơ khởi tạo 10.000 điểm một lần, lịch sử ledger, bảng xếp hạng 20 tài khoản bằng biệt danh ngắn (ẩn email/bot), admin điều chỉnh điểm có lý do/requestId, khóa tài khoản. Không còn callable nạp/rút.
- Backend giới hạn quyền bằng admin custom claim; Firestore client chỉ đọc dữ liệu cho phép, không được ghi. Firestore audit không phải hệ thống chứng cứ bất biến trước chủ Firebase project.

## Chạy local

Yêu cầu Flutter SDK/Dart >=3.8, Node 24 cho CLI/test (Functions deploy dùng runtime Node 22), Java 21 (Java 25 trên máy phát triển đã chạy Emulator), Android SDK. Từ **gốc repo**:

```powershell
flutter pub get
npm.cmd --prefix functions ci
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:start --project demo-tai-xiu --only auth,firestore,functions
```

Mở terminal khác:

```powershell
flutter run -d <android-device-id>
```

Android Emulator mặc định truy cập host qua `10.0.2.2`; thiết bị thật cần `--dart-define=EMULATOR_HOST=<IP-LAN>` và kết nối cùng mạng. Không mở public Emulator. Có thể dùng `flutter run -d chrome` trên cùng máy với host mặc định `127.0.0.1`. Debug mặc định dùng Emulator với API key giả có định dạng hợp lệ cho Android (không có quyền truy cập project thật); release mặc định **không** dùng Emulator và từ chối chạy nếu vẫn là project demo. Cấu hình Firebase thật qua các `--dart-define` tên `FIREBASE_*` trong `lib/main.dart`; không commit secret/service account. Dự án Firebase thật cần bật Email/Password, Firestore, Functions, thiết lập claim admin, kiểm App Check và billing trước demo.

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
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --project demo-tai-xiu --only auth,firestore,functions "node --test --test-concurrency=1 functions/integration/emulator.test.js functions/integration/card_tables.test.js"
```

CI dùng Node 24, chạy test Flutter, Android debug build, Functions và Emulator (gồm hai trò bài và Firestore rules). Clone repo chạy được với Firebase Emulator theo các lệnh trên; chưa phải bản APK cho các máy trong lớp. Chưa có APK release có chữ ký phân phối hay deploy production. Không đưa `google-services.json`, key ký APK hoặc mật khẩu vào Git.

## Quy tắc và hạn chế

- Tài/Xỉu: ba xúc xắc 1–6, bộ ba thua cả Tài/Xỉu, còn lại tổng <=10 Xỉu, >=11 Tài, trúng 2× cược gồm vốn.
- Bầu Cua: ba mặt trong `bau,cua,tom,ca,ga,nai`; trúng nhận `(1+số mặt khớp)×cược`.
- Xóc Xóc: **quy tắc mô phỏng tự chọn** bốn bit 0/1; tổng chẵn/lẻ, trúng 2× cược. Cần nhóm xác nhận luật mong muốn trước buổi demo.
- Player nhìn thấy chế độ `random/admin` của phiên trước cược nhưng **không** được đọc audit/lý do, thông tin cá nhân người khác. Cần nêu rõ với lớp rằng admin có thể chọn kết quả; không trình bày như trò ngẫu nhiên công bằng nếu là phiên admin.
- Scheduler kiểm mỗi phút, có thể trễ vì dịch vụ; server từ chối cược/hành động sau hạn dù UI vẫn hiển thị trạng thái cũ. Transaction và requestId/version chống ghi trùng; bot không tự thao túng thắng/thua. Mời bạn bằng mã bàn, chưa có link mời/push notification hoặc matchmaking tự động. Chưa benchmark tải, chưa kiểm thử offline/reconnect trên thiết bị thật, chưa enforce App Check hoặc có APK ký release.

Xem `docs/ARCHITECTURE.md`, `docs/VALIDATION.md` và `docs/RELEASE_CHECKLIST.md`. Lịch sử Git vẫn giữ bản cũ; tag `backup/pre-rebuild-main-2026-11-01`, `backup/pre-rebuild-hiep-2026-11-01` và bundle ngoại repo là điểm rollback. Không force-push.
