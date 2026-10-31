# Trạng thái kiểm thử — 01/11/2026

- `npm --prefix functions test`: 14 unit tests cho luật 3 trò phiên và evaluator Poker/Ba Cây.
- `firebase emulators:exec ... node --test functions/integration/emulator.test.js`: 2 integration tests đạt, gồm rules cấm client write/ẩn audit, API admin quyền, 3 trò, đóng cược sau hạn, khóa/chốt/hủy idempotent, race chốt/hủy, ledger, khóa tài khoản.
- `flutter analyze --no-pub`: sạch; `flutter test --no-pub`: 5/5; `flutter build apk --debug` và `flutter build web`: thành công. Đã xây lại sau cập nhật UI/Android manifest.
- `npm audit --omit=dev` còn 6 cảnh báo moderate (glob/minimatch transitive của Firebase Admin). Không ép nâng major gây hỏng SDK; CI chặn mức high trở lên, cảnh báo moderate vẫn in. Full dev audit còn cảnh báo high ở bộ công cụ test/emulator; cần nâng tương thích và rà lại trước phát hành.

Chưa kiểm thử tải đồng thời nhiều điện thoại, App Check device thật, offline/reconnect đầy đủ, release signing, bot/Poker/Ba Cây. Emulator scheduler không tự gọi `tick`, test thao tác `lockRound` admin thủ công. Firebase production chưa deploy.
