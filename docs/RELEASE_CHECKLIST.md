# Checklist trước khi cho cả lớp cài

Bản debug hiện tại dùng Firebase Emulator (`127.0.0.1` nếu không truyền `EMULATOR_HOST`), **không phải APK phát cho lớp**. Không đưa file cấu hình/khóa ký vào Git.

1. Chọn rõ phương án: nhóm nhỏ Spark + backend tự host qua Tailscale theo `docs/ONLINE_GROUP.md`, hoặc Functions production cần Blaze/billing. Xác nhận project `ad2-8abfa540`, Email/Password, Firestore, indexes/rules và hạn mức. Không tự nâng gói.
2. Cài rules/indexes; Spark thì chạy backend host có credential, Blaze thì mới deploy Functions từ commit đã kiểm thử. Cấp custom claim admin bằng công cụ server-side chỉ cho UID nhóm được phép. Không dùng script seed demo hoặc tài khoản/mật khẩu demo trong production. Kiểm tra lại project/region trên điện thoại.
3. Với Spark, đặt `BACKEND_URL=https://...` tới Tailscale Serve trong bản build; không phát APK khi thiếu URL. Kiểm tra `google-services.json` và FirebaseOptions Android đã merge cho project `ad2-8abfa540`; đặt `EMULATORS=false` chỉ sau khi backend thật đã triển khai. Các `FIREBASE_*` dart-defines có thể ghi đè cấu hình. App ID trong `android/app/build.gradle.kts` phải trùng cấu hình đã đăng ký. Không dùng `demo-key` hoặc `demo-tai-xiu` làm production. Mọi cấu hình release phải được nhóm kiểm tra trên thiết bị thật.
4. Bật App Check và kiểm tra API thực tế trước khi enforce; giới hạn đăng ký và theo dõi chi phí. Firestore rules hiện cấm ghi client, nhưng chủ Firebase project/Admin SDK vẫn có toàn quyền; giữ credential riêng, phân quyền tối thiểu, bật cảnh báo chi phí.
5. Chuẩn bị keystore ký release ngoài repo; ký APK/AAB, thử cài bản release lên ít nhất hai thiết bị Android khác nhau. Sau khi build, xác nhận bản release không gọi Emulator, kiểm đăng nhập, 5 trò, hai vai trò, lượt timeout, mất/reconnect và điểm/ledger.
6. Kiểm thử nhiều người đồng thời và toàn bộ nhánh chốt/hủy/race trên Firebase thử nghiệm. Chỉ công bố cho lớp khi không còn lỗi quyền, rò bài riêng, phát điểm trùng hoặc chi phí vượt dự kiến. Không quảng bá kết quả admin/bot là trò ngẫu nhiên công bằng; giải thích cơ chế trong buổi demo. Không có tiền thật, nạp/rút, quà hay quy đổi.
7. Nếu muốn sử dụng lại hình/âm thanh/logo từ bản tải ngoài, xác minh quyền sử dụng trước. Repo hiện không kèm các asset đó.

## Lệnh kiểm tra local

```powershell
flutter analyze
flutter test
npm.cmd --prefix functions test
npm.cmd --prefix functions run check
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --project demo-tai-xiu --only auth,firestore,functions "node --test --test-concurrency=1 functions/integration/emulator.test.js functions/integration/card_tables.test.js"
flutter build apk --debug
```

Bản release ký và backend live **chưa triển khai/kiểm thử thực tế**. Firebase CLI máy phát triển phải đăng nhập bằng tài khoản chủ nhóm; chọn đúng Firebase project, xác nhận Blaze/billing trước khi deploy Functions. Không đưa credential, keystore hay service account vào Git. Clone repo chạy được trên Emulator local nhưng chưa tự kết nối production.
