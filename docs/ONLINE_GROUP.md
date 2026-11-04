# Chơi chung online trên Firebase Spark (máy nhóm làm backend)

**Trạng thái:** mã đã có cổng HTTP riêng cho cùng luật/transaction/ledger và Firebase Auth + Firestore thật. Chưa có máy chủ live hoạt động hay test end-to-end với project thật: chủ nhóm phải cấu hình credential, Tailscale, indexes và 2 tài khoản. Không đưa Firebase Emulator ra mạng; không dùng tài khoản demo hay mật khẩu demo trên project thật. Không cần Cloud Functions/Blaze, nhưng máy host phải bật và có Internet suốt buổi chơi.

## Sơ đồ

- Android Flutter của từng bạn → Firebase Auth/Firestore **thật** (`ad2-8abfa540`) để đăng nhập và nghe realtime.
- Callable SDK → `BACKEND_URL/api/<lệnh>` qua HTTPS riêng của Tailscale Serve → Node HTTP ở **127.0.0.1:8765** trên máy host. Node kiểm token Firebase Auth, kiểm quyền admin/profile, gọi đúng game handlers/Firestore transactions cũ; lịch tick + cardTick chạy mỗi phút trên host.
- Dữ liệu dùng chung ở Firestore thật. Nếu host tắt/ngủ/mất mạng, app đọc được snapshot nhưng **không thể đặt cược/chốt/chơi bài** đến khi host chạy lại; scheduler bù trễ khi khởi động. Không cam kết uptime, tải lớn hay APK phân phối công khai. Không dùng Tailscale Funnel/public proxy.

## 1. Chuẩn bị trên máy host (chỉ trưởng nhóm)

1. Trong Firebase Console, xác nhận project ID `ad2-8abfa540`, Spark, Email/Password bật, Firestore Rules đúng `firestore.rules`. **Xuất bản 3 composite indexes trong `firestore.indexes.json`** (Firebase CLI: `firebase deploy --only firestore:indexes --project ad2-8abfa540`, sau khi `firebase login` bằng owner); đợi trạng thái Enabled. Rules đã publish ngày 03/11/2026; 3 indexes đã tạo ngày 05/11/2026, cần đợi **Enabled**. Không deploy Functions (Spark không hỗ trợ).
2. Dùng một **service account cho project thật có quyền Firebase Auth và Firestore** trên riêng máy host. Firebase Console → Project settings → Service accounts → tạo JSON private key khi thực sự dùng; lưu ngoài repo, bảo vệ file chỉ owner, không gửi vào chat/GitHub/nhóm, xóa/thu hồi sau buổi học. Cách khác là ADC từ gcloud + OAuth Desktop client riêng (gcloud ADC mặc định không được Firebase Auth chấp nhận); xem tài liệu Firebase Admin SDK. Không dùng key của thành viên khác. Đường dẫn JSON chỉ đặt trong biến môi trường cục bộ.
3. Cài Tailscale và đăng nhập một tailnet riêng cho nhóm; bật MagicDNS + HTTPS certificates, chỉ mời thành viên tin cậy. Tailscale Personal miễn phí tối đa 6 users **trong tailnet của chủ nhóm**. Nếu đông hơn, có thể chia sẻ riêng **máy host** cho từng người từ tailnet của họ bằng node sharing (không tính vào số user của tailnet chủ); mỗi người vẫn phải cài Tailscale, đăng nhập, nhận lời mời và kiểm ACL/MagicDNS. Chưa kiểm thử 35 người đồng thời. **Serve, không Funnel**; không port-forward và không bật firewall inbound tới 8765.
4. PowerShell trong gốc repo (mỗi terminal mới cần thiết lập biến):

   ```powershell
   npm.cmd --prefix functions ci
   $env:GCLOUD_PROJECT='ad2-8abfa540'
   $env:GOOGLE_CLOUD_PROJECT='ad2-8abfa540'
   $env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\outside-repo\private-key.json'
   Remove-Item Env:FIREBASE_AUTH_EMULATOR_HOST,Env:FIRESTORE_EMULATOR_HOST -ErrorAction SilentlyContinue
   npm.cmd --prefix functions run serve:online
   ```

   Server **từ chối chạy** khi trỏ nhầm project/demo hoặc còn biến Emulator; xác nhận Auth+Firestore thật trước khi mở cổng. Terminal này phải chạy. Kiểm cục bộ `Invoke-RestMethod http://127.0.0.1:8765/health` trả `ok: true`.
5. Terminal khác chạy `tailscale serve --bg 8765` (hoặc `& 'C:\Program Files\Tailscale\tailscale.exe' serve --bg 8765`). `tailscale serve status` lấy URL HTTPS dạng `https://ten-may.ten-tailnet.ts.net`. Nếu CLI yêu cầu đăng nhập/cho phép HTTPS, owner thao tác trong trình duyệt. Chỉ chia URL cho thành viên đã vào tailnet; khi xong `tailscale serve 8765 off` và dừng Node. Nếu đổi host/URL, **rebuild app** với URL mới.
6. Tạo **một email thật riêng** để admin đăng ký trong app. Lấy UID từ Firebase Console → Authentication → Users, không cấp quyền admin cho UID người khác. Trong terminal host với cùng credential và project:

   ```powershell
   node functions/scripts/set-admin.js UID_TIN_CAY
   ```

   Đăng xuất/đăng nhập admin để làm mới custom claim. Firebase Console Owner **không tự là admin game**. Không dùng `admin@demo.test` trên project thật. Muốn thu hồi: `node functions/scripts/set-admin.js UID_TIN_CAY revoke`.

## 2. Mỗi thành viên chạy Android Studio

1. Clone `main`, `flutter pub get`, khởi động Android Emulator/thiết bị Android, cài Tailscale trên **máy/thiết bị chạy app** và vào cùng tailnet (Android Emulator thường dùng mạng host; nếu không tới URL HTTPS, thử trực tiếp browser trên Emulator trước). Tài khoản Firebase là mỗi người tự đăng ký bằng **email thật**, không phải account demo local. Không chia sẻ mật khẩu admin.
2. Chạy tại gốc repo, thay URL bằng URL `tailscale serve status` của host, **phải thuộc tên miền `.ts.net`, không có dấu `/` cuối**:

   ```powershell
   flutter run -d <device-id> --dart-define=EMULATORS=false --dart-define=BACKEND_URL=https://ten-may.ten-tailnet.ts.net
   ```

   Android Studio Run configuration: Additional run args tương tự. Muốn build APK debug riêng cho nhóm: `flutter build apk --debug --dart-define=EMULATORS=false --dart-define=BACKEND_URL=https://ten-may.ten-tailnet.ts.net`; APK trong `build/app/outputs/flutter-apk/app-debug.apk`. Đây là **debug APK**, không phải release ký. Link backend được nhúng trong APK, nhưng không chứa private key; mọi lệnh cần Firebase ID token và server kiểm quyền.
3. Kiểm hai user trên **hai máy**: đăng ký → lobby/ví 10.000 → cùng Tài/Xỉu thấy một `roundId` → cả hai cược → admin chọn (hoặc random) → hết 30 giây cùng thấy kết quả/ledger; kiểm Bầu Cua/Xóc Xóc/Poker/Ba Cây tương tự. Kiểm player gọi lệnh admin bị từ chối. Tắt host vài phút rồi bật lại để kiểm reconnect; không cược khi host offline.

## Giới hạn/an toàn

- Spark vẫn có hạn mức Auth/Firestore; nhiều người và listener realtime có thể vượt mức miễn phí. Đọc dashboard usage trong buổi test. Tailscale Personal giới hạn 6 users trong tailnet của chủ nhóm; node sharing cho người ngoài tailnet không làm tăng số user này, nhưng onboarding 35 người và tải host vẫn cần kiểm thử. Chưa có load test thực tế, App Check, giám sát 24/7, backup tự động, hay production service manager.
- Token Firebase thật được xác minh trên host (kể cả revoked), endpoint chỉ bind loopback và chia qua Tailscale HTTPS; Firestore Rules chặn client ghi, Admin SDK/key chỉ nằm trên host. Dù vậy ai cầm service-account key/chiếm host có toàn quyền; cần khóa máy và thu hồi key sau demo.
- **Không chạy** `emulators:start` với project thật và chỉ một phần service; API chưa emulated có thể trỏ production. Đừng mở port 9099/8080/5001/8765 công khai. Không dùng Funnel cho backend.
- Nếu cần uptime độc lập máy host, không muốn từng người cài Tailscale/nhận node share, hoặc iPhone không có Android Studio, cần lựa chọn triển khai khác và quyết định rõ hạn mức/chi phí; **không tự nâng Blaze**. Bản này phục vụ nhóm nhỏ vài ngày, không phải hosting công cộng.
