# TiuXai — điểm ảo cho bài thực hành PRM393

Ứng dụng Flutter Android/Firebase viết lại độc lập. **Không có tiền thật, nạp/rút/chuyển đổi, quà hay hiện vật.** Luật năm trò hiện là **mô phỏng riêng, không tương đương toàn bộ backend Go88**; xem `docs/RULE_PARITY.md` trước khi test thuật toán hoặc đổi luật. Hai tài khoản player và admin dùng Firebase Auth; ví điểm và mọi kết quả do Cloud Functions kiểm soát. Không nhập source, dependency, credential hay asset Go88. Giao diện vẽ bằng Flutter.

## Hiện trạng (01/11/2026)

- **Chơi được trên Emulator:** Tài/Xỉu, Bầu Cua, Xóc Xóc (ba phòng phiên độc lập). Mỗi phiên 30 giây, một cược/người, 10–1000 điểm, tối đa 100 cược. Admin mở phiên random hoặc chọn kết quả hợp lệ **sau khi khóa cược**; kết quả không sửa lại được. Mọi chọn kết quả, lý do và tác động ví được ghi `auditLogs` **chỉ admin đọc**. `tick` khóa phiên quá hạn và tự chốt random trên Firebase thật; Emulator không tự chạy Scheduler, admin nhấn Khóa/Chốt thủ công.
- **Poker/Ba Cây chơi được trên Emulator:** bàn 2–6 ghế, mua vào 10× ante (ante 10–100), tham gia bằng mã bàn, chủ bàn bắt đầu khi đủ tối thiểu 2 ghế. Admin cấu hình tối đa 0–5 bot theo sức chứa bàn, hủy/hoàn với lý do. Ba Cây chia ba lá và so 10 điểm ngay; Poker Texas Hold’em ante, cược giới hạn cố định, 4 vòng, một lần raise mỗi vòng, kiểm all-in/side-pot. Mỗi lượt 45 giây; scheduler tự check/fold khi quá hạn, bot dùng cùng engine và ví/ledger. Bài riêng chỉ chủ bài đọc. Hệ thống tạo tối đa 5 ví bot dùng chung, cấp 10.000 điểm ảo đúng một lần mỗi ví; bot vào ghế đang chờ khi admin bật/điều chỉnh cấu hình; ghế công khai chỉ hiện biệt danh chung, không có nhãn bot. Cấu hình và danh tính bot chỉ admin/server xem được. Không mạo danh bạn học; nhóm giải thích cơ chế trong phần tổng kết. Một ván/bàn; muốn chơi tiếp tạo bàn mới.
- Email/password, hồ sơ khởi tạo 10.000 điểm một lần, lịch sử ledger, bảng xếp hạng 20 tài khoản bằng biệt danh ngắn (ẩn email/bot), admin điều chỉnh điểm có lý do/requestId, khóa tài khoản. Không còn callable nạp/rút.
- Backend giới hạn quyền bằng admin custom claim; Firestore client chỉ đọc dữ liệu cho phép, không được ghi. Firestore audit không phải hệ thống chứng cứ bất biến trước chủ Firebase project.

## Cho thành viên nhóm clone và chạy trong Android Studio

**Không cần đăng nhập Firebase Console/Edge, không cần Firebase project thật hoặc thẻ thanh toán để test local.** Mỗi máy chạy riêng Firebase Auth + Firestore + Functions Emulator, nên tài khoản/điểm/phòng trên máy A **không đồng bộ** với máy B. Muốn test nhiều người cùng phòng, mở **hai Android Emulator trên cùng một máy** (hoặc hai client dùng chung một bộ Emulator local); không mở Emulator ra Internet. Chỉ clone repo chưa có server online để cả nhóm ở những máy khác nhau chơi chung.

1. Có quyền đọc repo GitHub private; cài Android Studio + Android SDK/Android Emulator, Flutter SDK (Dart >=3.8) và Flutter/Dart plugin, Node.js 24, Java 21. Kiểm tra `flutter doctor -v`, `node --version`, `java -version`. Mỗi máy tự cài dependency, không commit `node_modules`, `build` hay credential.
2. Clone/mở **thư mục gốc chứa `pubspec.yaml` và `firebase.json`** trong Android Studio. Tại terminal PowerShell ở thư mục này, chạy **một lần sau khi clone/cập nhật lockfile**:

   ```powershell
   flutter pub get
   npm.cmd --prefix functions ci
   ```

3. Khởi động Firebase Emulator trong terminal 1 và **để terminal này chạy**:

   ```powershell
   node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:start --project demo-tai-xiu --only auth,firestore,functions
   ```

   Đợi thấy Auth `9099`, Firestore `8080`, Functions `5001`; nếu cổng bận, dừng tiến trình chiếm cổng thay vì đổi cổng một phía. Không cần `firebase login` cho project demo local.
4. Bật Android Emulator trong Device Manager; bấm Run cấu hình Flutter `lib/main.dart` ở Android Studio, hoặc terminal 2 chạy `flutter devices` rồi `flutter run -d <android-device-id>`. **Dùng Debug**, không cài APK release chưa cấu hình Firebase thật. App debug tự dùng `demo-tai-xiu` và host `10.0.2.2` cho Android Emulator. Trên cùng máy có thể `flutter run -d chrome` với `127.0.0.1`.
5. Đăng ký hai tài khoản khác nhau bằng form để test player. Muốn mở menu admin, chạy script seed bên dưới **trong lúc Emulator đang bật**, sau đó đăng nhập `admin@demo.test` / `Demo123456!` và đổi tài khoản player khi cần. Đây là mật khẩu **công khai chỉ cho Emulator**, tuyệt đối không dùng với Firebase thật.

   ```powershell
   $env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
   $env:GCLOUD_PROJECT='demo-tai-xiu'
   node functions/scripts/seed-emulator.js
   ```

   Nếu đã có UID tài khoản riêng và muốn cấp admin cho UID đó, dùng `node functions/scripts/set-admin.js UID_CUA_BAN` với cùng hai biến môi trường trên, rồi **đăng xuất/đăng nhập** để refresh quyền. Không cấp admin cho tài khoản thử nghiệm không tin cậy.
6. Smoke test: admin tạo phiên `admin`, player đặt 10–1000 điểm trước hạn 30 giây; sau hạn admin **Khóa** rồi nhập ba xúc xắc/mặt hoặc bốn bit hợp lệ và **Chốt**; kiểm tra ví và ledger của player. Với Poker/Ba Cây, tạo bàn 2–6 ghế rồi thêm player hoặc bật bot bằng admin; Poker đi lượt, Ba Cây tự chốt khi bắt đầu. Emulator không tự chạy scheduler: các ca timeout tự động/`tick` kiểm qua integration test, phiên cược dùng nút Khóa/Chốt thủ công.

**Nếu không chạy được:** kiểm tra terminal Emulator còn sống, `flutter doctor -v`, đúng Android Emulator (không phải điện thoại thật), đúng project `demo-tai-xiu` và đúng cổng. Lỗi `Không kết nối được Firebase` trên điện thoại thật là do `10.0.2.2` chỉ dành cho Android Emulator; xem mục dưới về `EMULATOR_HOST`. Dữ liệu local của từng máy là dữ liệu thử nghiệm, có thể mất khi Emulator dừng; đừng dùng nó làm dữ liệu chung của nhóm.

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

Xem `docs/ARCHITECTURE.md`, `docs/RULE_PARITY.md`, `docs/VALIDATION.md` và `docs/RELEASE_CHECKLIST.md`. Lịch sử Git vẫn giữ bản cũ; tag `backup/pre-rebuild-main-2026-11-01`, `backup/pre-rebuild-hiep-2026-11-01` và bundle ngoại repo là điểm rollback. Không force-push.
