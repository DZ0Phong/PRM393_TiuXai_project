# Trạng thái kiểm thử — 01/11/2026

- `npm --prefix functions test`: 36 unit tests cho 3 trò phiên, evaluator và engine Poker/Ba Cây (2–6 ghế, all-in, side-pot, bot, dữ liệu công khai/riêng; thêm 500 ván Poker seed cố định kiểm lượt hợp lệ và bảo toàn điểm).
- `firebase emulators:exec ... node --test functions/integration/emulator.test.js`: 4 integration tests đạt, gồm rules cấm client write/ẩn audit/bài riêng, API quyền admin, 5 trò, bot 1–5 ghế với 5 ví dùng chung (welcome một lần, mua vào/hoàn lặp, hai bàn đồng thời, thiếu điểm rollback), bảng xếp hạng không lộ bot/email, đóng cược sau hạn, cược hai cửa đối nhau, khóa/chốt/hủy idempotent, race chốt/hủy, hoàn bàn chờ/đang chơi và từ chối/rollback khi hoàn vượt số nguyên an toàn, timeout bàn Poker, ledger bảo toàn, khóa tài khoản.
- `flutter analyze --no-pub`: sạch; `flutter test --no-pub`: 6/6; `flutter build apk --debug` và `flutter build web`: thành công. Đã xây lại sau cập nhật UI/Android manifest. Trên Android Emulator đã cài APK, tạo tài khoản, vào lobby và tạo bàn Poker; đã sửa lỗi API key giả không hợp lệ do Android SDK phát hiện.
- `npm audit --omit=dev` còn 6 cảnh báo moderate (glob/minimatch transitive của Firebase Admin). Không ép nâng major gây hỏng SDK; CI chặn mức high trở lên, cảnh báo moderate vẫn in. Full dev audit còn cảnh báo high ở bộ công cụ test/emulator; cần nâng tương thích và rà lại trước phát hành.

Chưa kiểm thử tải đồng thời nhiều điện thoại, App Check device thật, offline/reconnect đầy đủ, release signing. Emulator scheduler không tự chạy tự động; client gọi `advanceRandomRound` cho phiên random đã hết hạn, còn integration tests có thể gọi `tick` trực tiếp. Firebase production chưa deploy.

## Đối chiếu luật tham khảo

Đã rà mã Go88 đã giải nén ở mức mã tĩnh. **Không có bằng chứng năm trò tương đương Go88**: Tài/Xỉu, Bầu Cua, Xóc Xóc và phần Chương của Ba Cây đã có kiểm tra riêng; Poker còn blind/phí/hòa và Ba Cây còn Gà/ván kế. Biểu đồ/cầu từ lịch sử đã có cho ba trò phiên. Xem `docs/RULE_PARITY.md`; test xanh chỉ chứng minh các luật/luồng được test, không chứng minh parity toàn bộ source tham khảo. Không chạy mã tham khảo.
