# TiuXai — điểm ảo cho bài thực hành PRM393

Ứng dụng Flutter Android/Firebase viết lại độc lập. **Không có tiền thật, nạp/rút/chuyển đổi, quà hay hiện vật.** Ba trò phiên và Ba Cây đã đối chiếu một phần luật từ source Go88; Poker vẫn khác nhiều chi tiết. **Không tương đương toàn bộ backend Go88**; xem `docs/RULE_PARITY.md` trước khi test thuật toán hoặc đổi luật. Hai tài khoản player và admin dùng Firebase Auth; ví điểm và mọi kết quả do Cloud Functions kiểm soát. Không nhập source, dependency, credential hay asset Go88. Giao diện vẽ bằng Flutter.

## Hiện trạng (04/11/2026)

- **Chơi được trên Emulator:** Tài/Xỉu, Bầu Cua, Xóc Xóc tự mở phiên 30 giây. Admin xem người trong phòng (heartbeat gần đúng, hết hạn sau 30 giây), người thực sự đã cược, tổng điểm và số người theo từng cửa, chênh Tài−Xỉu hoặc chênh cửa cao nhất−thấp nhất. Admin chọn kết quả hợp lệ **một lần trước `closesAt`**, có lý do; kết quả lưu trong `roundPlans` chỉ admin đọc, round công khai không đổi khi admin chọn, không chứa `mode`/`plannedAt`. Sau hạn cược, player gọi `advanceRandomRound` để khóa/chốt ngay theo lựa chọn hoặc server CSPRNG nếu chưa chọn; scheduler mỗi phút là dự phòng khi không ai mở app nên có thể chốt trễ, nhưng **không thêm cửa sổ sửa sau hạn**. Kết quả hiển thị ít nhất 6 giây trước phiên mới; không sửa/chốt lại. Thao tác/lý do/tác động ví ở `auditLogs` chỉ admin đọc. Bầu Cua cho hoàn cược trước hạn; tối đa 100 người/phiên, cược tối thiểu 1000 và bội số 100 (Xóc Xóc bội số 1000). Không xem danh sách người đặt cược từ tài khoản player.

- **Chọn kết quả trên màn admin:** Tài/Xỉu có 2 nút Tài hoặc Xỉu; Bầu Cua có 6 nút ba mặt cùng loại; Xóc Xóc có 5 kết quả theo số mặt đỏ (6 cửa cược nhưng Chẵn/Lẻ và cửa màu có thể cùng thắng). Mỗi cửa hiển thị số người cược và tổng điểm, tô cửa cược cao nhất; mỗi nút cho biết cửa thắng, điểm trả dự kiến và chênh cược−trả, đánh dấu lựa chọn trả ít điểm nhất nếu có duy nhất một lựa chọn như vậy. Chạm nút gửi kết quả hợp lệ tới server, không cần nhập xúc xắc/đồng xu bằng tay; lý do audit đã có giá trị mặc định và sửa được. Đây chỉ là **ước tính tại thời điểm xem**, không khóa cược hoặc đảm bảo mọi người thua: cược/hoàn mới có thể đổi số liệu cho tới `closesAt`, backend tính thanh toán cuối cùng và từ chối chọn sau hạn hoặc chọn lặp.
- **Poker/Ba Cây chơi được trên Emulator:** bàn 2–6 ghế, mua vào 10× ante (ante 10–100), tham gia bằng mã bàn, chủ bàn bắt đầu khi đủ tối thiểu 2 ghế. Admin cấu hình tối đa 0–5 bot theo sức chứa bàn, hủy/hoàn với lý do. Ba Cây dùng 36 lá và Chương so từng người ngay (lãi 0,98× làm tròn xuống, chưa có Gà/ván tiếp); Poker Texas Hold’em ante, 4 vòng, tố tăng tùy chọn tối thiểu bằng ante, kiểm all-in/side-pot (chưa trừ phí theo Go88). Mỗi lượt 45 giây; scheduler tự check/fold khi quá hạn, bot dùng cùng engine và ví/ledger. Bài riêng chỉ chủ bài đọc. Hệ thống tạo tối đa 5 ví bot dùng chung, cấp 10.000 điểm ảo đúng một lần mỗi ví; bot vào ghế đang chờ khi admin bật/điều chỉnh cấu hình; ghế công khai chỉ hiện biệt danh chung, không có nhãn bot. Cấu hình và danh tính bot chỉ admin/server xem được. Không mạo danh bạn học; nhóm giải thích cơ chế trong phần tổng kết. Một ván/bàn; muốn chơi tiếp tạo bàn mới.
- Email/password, hồ sơ khởi tạo 10.000 điểm một lần, lịch sử ledger, bảng xếp hạng 20 tài khoản bằng biệt danh ngắn (ẩn email/bot), admin điều chỉnh điểm có lý do/requestId, khóa tài khoản. Không còn callable nạp/rút.
- Backend giới hạn quyền bằng admin custom claim; Firestore client chỉ đọc dữ liệu cho phép, không được ghi. Firestore audit không phải hệ thống chứng cứ bất biến trước chủ Firebase project.

## Chơi chung online nhóm nhỏ trên Spark (mới)

Đã có backend tự host dùng **Firebase Auth/Firestore thật + VPS**, không cần Cloud Functions/Blaze. Đọc [hướng dẫn VPS](docs/VPS_ONLINE.md); [Tailscale Serve](docs/ONLINE_GROUP.md) là phương án nhóm nhỏ khác. VPS hiện chỉ có OS, Node, Caddy/HTTPS và mã backend; **backend chưa chạy và chưa test online** vì chưa có service-account credential. App phát cho lớp phải build với `--dart-define=EMULATORS=false` và `--dart-define=BACKEND_URL=https://<IP-VPS>` sau khi `/health` thật sự hoạt động. Nếu để trống `BACKEND_URL`, app gọi Cloud Functions trực tiếp; chỉ dùng sau khi đã deploy Functions (cần Blaze). Spark vẫn có giới hạn Firestore, và VPS tắt thì không ghi/chốt được. Không đưa credential vào repo.

## Cho thành viên nhóm clone và chạy trong Android Studio

**Không cần đăng nhập Firebase Console/Edge, không cần Firebase project thật hoặc thẻ thanh toán để test local.** Mỗi máy chạy riêng Firebase Auth + Firestore + Functions Emulator, nên tài khoản/điểm/phòng trên máy A **không đồng bộ** với máy B. Muốn test nhiều người cùng phòng, mở **hai Android Emulator trên cùng một máy** (hoặc hai client dùng chung một bộ Emulator local); không mở Emulator ra Internet. Chỉ clone repo không tự có server online; muốn chơi chung từ máy khác cần cấu hình host riêng theo `docs/ONLINE_GROUP.md`.

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
4. Bật Android Emulator trong Device Manager; bấm Run cấu hình Flutter `lib/main.dart` ở Android Studio, hoặc terminal 2 chạy `flutter devices` rồi `flutter run -d <android-device-id>`. **Dùng Debug**; app debug mặc định trỏ Firebase Emulator ở `10.0.2.2`, không tự ghi vào project thật. Trên cùng máy có thể `flutter run -d chrome` với `127.0.0.1`.
5. Đăng ký hai tài khoản khác nhau bằng form để test player. Muốn mở menu admin, chạy script seed bên dưới **trong lúc Emulator đang bật**, sau đó đăng nhập `admin@demo.test` / `Demo123456!` và đổi tài khoản player khi cần. Đây là mật khẩu **công khai chỉ cho Emulator**, tuyệt đối không dùng với Firebase thật.

   ```powershell
   $env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
   $env:GCLOUD_PROJECT='demo-tai-xiu'
   node functions/scripts/seed-emulator.js
   ```

   Nếu đã có UID tài khoản riêng và muốn cấp admin cho UID đó, dùng `node functions/scripts/set-admin.js UID_CUA_BAN` với cùng hai biến môi trường trên, rồi **đăng xuất/đăng nhập** để refresh quyền. Không cấp admin cho tài khoản thử nghiệm không tin cậy.

**Nếu không chạy được:** kiểm tra terminal Emulator còn sống, `flutter doctor -v`, đúng Android Emulator (không phải điện thoại thật), đúng project `demo-tai-xiu` và đúng cổng. Lỗi `Không kết nối được Firebase` trên điện thoại thật là do `10.0.2.2` chỉ dành cho Android Emulator; xem mục dưới về `EMULATOR_HOST`. Dữ liệu local của từng máy là dữ liệu thử nghiệm, có thể mất khi Emulator dừng; đừng dùng nó làm dữ liệu chung của nhóm.

## Nhánh `firebase` và project Spark thật

Đã merge cấu hình Android của thành viên cho project `ad2-8abfa540`: package `vn.teamfive.tai_xiu_realtime` và `google-services.json`. Flutter khởi tạo bằng `FirebaseOptions` tương ứng trong `lib/main.dart`; không cần thêm Gradle plugin Google Services (máy offline không resolve được plugin đó). `.firebaserc` giữ `default=demo-tai-xiu` để lệnh CLI không vô tình tác động project thật; alias `live` chỉ dùng khi cố ý chỉ định `--project ad2-8abfa540`. File JSON/API key Firebase là định danh client công khai, **không** chứng minh Auth, Firestore, rules hay Functions đã triển khai.

**Kiểm tra project thật ngày 03/11/2026:** `hiep20004@gmail.com` đã là Owner; project `ad2-8abfa540` vẫn ở Spark. Email/Password đã bật; Firestore `(default)` tại `asia-southeast1` đã tạo nhưng chưa có collection. Trên Console, Functions chỉ hiện yêu cầu nâng gói, chưa có callable được deploy. Rules trong `firestore.rules` đã được Owner xuất bản lúc 10:46 ngày 03/11/2026, thay mẫu test cho phép mọi client đọc/ghi. Yêu cầu đọc không xác thực tới collection `rooms` đã trả HTTP 403. Mọi ghi Firestore từ client bị chặn; chỉ backend tin cậy mới thay đổi dữ liệu game. Bản debug build với `--dart-define=EMULATORS=false` cài và mở được màn đăng nhập trên Android Emulator; điều đó chỉ xác minh app khởi tạo Firebase, **chưa** xác minh đăng nhập hay chơi chung end-to-end. Firebase CLI trên máy chưa đăng nhập.

### Tài khoản thật khác tài khoản Emulator

- Debug mặc định dùng **Auth Emulator** riêng. Chỉ sau khi chạy `functions/scripts/seed-emulator.js` mới có `admin@demo.test` và `player1@demo.test`…`player5@demo.test`, cùng mật khẩu mẫu `Demo123456!`; không dùng bộ này trên project thật. Nút “Demo Admin” chỉ hiện trong chế độ Emulator; đăng ký mới không còn mật khẩu điền sẵn. Form đăng ký không còn trường điện thoại/OTP, giftcode, nút social giả hoặc thông báo thắng giả; đây không phải các tính năng Auth đang hỗ trợ.
- `--dart-define=EMULATORS=false` dùng **Firebase Auth thật** của `ad2-8abfa540`. Tại lúc kiểm tra có một user `dang12fa2@demo.test`; không biết và không thể đọc mật khẩu gốc. Người dùng tự đặt mật khẩu khi đăng ký hoặc chủ project đặt lại mật khẩu. Auth giữ danh tính/UID; Firestore `users/{uid}` giữ ví/hồ sơ sau khi callable `ensureProfile` chạy. Khi Functions chưa deploy trên Spark, đăng nhập Auth được nhưng hồ sơ/ví/game chưa khởi tạo online.
- Quyền **Owner trên Firebase Console không tự biến thành admin trong game**. Admin game là Auth user riêng có custom claim `admin: true`, do Firebase Admin SDK trên môi trường tin cậy cấp cho UID; UI hoặc Firestore không được tự gán. Sau khi cấp, user đăng xuất/đăng nhập để làm mới token. Script `functions/scripts/set-admin.js UID` dùng được trên Auth Emulator với hai biến môi trường ở trên; muốn cấp trên project thật phải cấu hình riêng Admin SDK/ADC cho **đúng project** `ad2-8abfa540`, không để biến `FIREBASE_AUTH_EMULATOR_HOST` còn tồn tại, không đưa service-account key vào repo. Phiên làm việc này không cấp claim admin cho bất kỳ user thật nào; chưa xác minh các claim hiện có.
- Form đăng ký Emulator nhận nickname 4–20 ký tự và tạo `nickname@demo.test` (không phải hộp thư nhận email). Bản kết nối Firebase thật yêu cầu email thật để có thể khôi phục tài khoản; chủ project có thể tạo user bằng email thật trên Auth Console rồi cấp claim bằng script tin cậy. Luồng quên mật khẩu qua SMS chưa được cấu hình nên không hiển thị trên màn đăng nhập.

**Spark không deploy được Cloud Functions**, trong khi đăng ký hồ sơ/ví, đặt cược, chốt phiên và bàn bài đều cần backend tin cậy. Vì thế APK debug local mặc định chỉ chạy đầy đủ khi có Emulator. Phương án online nhóm nhỏ dùng Firebase thật + backend tự host qua Tailscale theo `docs/ONLINE_GROUP.md`; chưa cấu hình host/credential thực tế. Không đổi sang Blaze hay triển khai bất kỳ dịch vụ có thể tính phí nếu nhóm chưa quyết định. Chia sẻ quyền Owner hoặc chỉ bật Auth/Firestore không thay thế được backend tự host.

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

Android Emulator mặc định truy cập host qua `10.0.2.2`; thiết bị thật cần `--dart-define=EMULATOR_HOST=<IP-LAN>` và kết nối cùng mạng. Không mở public Emulator. Có thể dùng `flutter run -d chrome` trên cùng máy với host mặc định `127.0.0.1`. Debug mặc định dùng `demo-tai-xiu`/Firebase Emulator với cấu hình giả, kể cả khi `google-services.json` chứa project thật; release mặc định dùng cấu hình Android thật và **không** dùng Emulator. Cấu hình Firebase Android thật nằm trong `android/app/google-services.json`, `.firebaserc` alias `live` và các giá trị mặc định `FIREBASE_*` trong `lib/main.dart`; có thể ghi đè bằng `--dart-define`. Đây là định danh client, **không** phải quyền truy cập admin. Không commit service account, token CLI hoặc keystore. Xem mục Firebase Spark bên dưới trước khi thử kết nối project thật.

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

CI dùng Node 24, chạy test Flutter, Android debug build, Functions và Emulator (gồm hai trò bài và Firestore rules). Clone repo chạy được với Firebase Emulator theo các lệnh trên; xem `docs/ONLINE_GROUP.md` để nhóm nhỏ tự host online, chưa phải APK công khai cho cả lớp. Chưa có APK release có chữ ký phân phối hay deploy production. `google-services.json` chỉ chứa cấu hình client đã được merge; không đưa key ký APK, mật khẩu, token CLI hoặc service account vào Git.

## Quy tắc và hạn chế

- Tài/Xỉu: ba xúc xắc 1–6; bộ ba thua cả hai cửa; nếu không phải bộ ba, tổng <=10 là Xỉu và >=11 là Tài. Cửa thắng trả gốc + lãi 98% (1,98×). Chỉ hoàn phần cược dư ở cửa có tổng cược lớn hơn khi cả hai cửa đều có cược; nếu cửa đối diện trống thì cược chịu kết quả bình thường.
- Bầu Cua: ba mặt trong `bau,cua,tom,ca,ga,nai`; trúng n mặt nhận gốc + 98% × n × cược (1,98×/2,96×/3,94×).
- Xóc Xóc: bốn bit 0/1; sáu cửa Chẵn/Lẻ, ba đỏ/trắng và bốn đỏ/trắng, mức trả 1,98×/3,94×/14,7×.
- Player không đọc được plan/audit/lý do hoặc nhãn `mode`/`plannedAt` trong phiên mới; app chỉ hiển thị trạng thái, cược và kết quả sau chốt. Đây **không phải** bảo đảm bí mật tuyệt đối hay tính ngẫu nhiên công bằng: mã APK, phân tích thống kê và dữ liệu phiên cũ có thể để lộ cơ chế. Cần giải thích cơ chế admin cho lớp trong phần tổng kết; không quảng bá mọi phiên là random độc lập.
- Scheduler kiểm mỗi phút, có thể trễ vì dịch vụ; server từ chối cược/hành động sau hạn dù UI vẫn hiển thị trạng thái cũ. Transaction và requestId/version chống ghi trùng; bot không tự thao túng thắng/thua. Mời bạn bằng mã bàn, chưa có link mời/push notification hoặc matchmaking tự động. Chưa benchmark tải, chưa kiểm thử offline/reconnect trên thiết bị thật, chưa enforce App Check hoặc có APK ký release.

Xem `docs/ARCHITECTURE.md`, `docs/RULE_PARITY.md`, `docs/VALIDATION.md` và `docs/RELEASE_CHECKLIST.md`. Lịch sử Git vẫn giữ bản cũ; tag `backup/pre-rebuild-main-2026-11-01`, `backup/pre-rebuild-hiep-2026-11-01` và bundle ngoại repo là điểm rollback. Không force-push.
