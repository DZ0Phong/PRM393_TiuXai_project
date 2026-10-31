# Việc còn lại sau mốc luật và cầu (01/11/2026)

1. **Poker parity:** đối chiếu thêm fixture với source `Controllers/game/poker/lib/room.js`: blind/cược mở đầu không đều, phí thắng, hòa trả cược, side-pot và các chuỗi tố nhiều người. Bản hiện tại đã có tố theo số tiền tùy chọn/all-in nhưng chưa tương đương chi tiết này. Không sửa bừa luật poker mà không có fixture và test ví/ledger.
2. **Ba Cây parity:** nguồn có Gà và nhiều ván liên tiếp, chuyển Chương sau ván; backend hiện có so Chương/người chơi, bộ 36 lá, tính phí theo source, nhưng mỗi bàn mới một ván. Cần chốt quy tắc Gà chi tiết từ mã nguồn, test 2–6 người và bot khi thêm state machine nhiều ván.
3. **Vận hành:** thử nhiều thiết bị người thật, offline/reconnect, bảo mật App Check và tải thực tế; cấu hình Firebase thật, CI trên GitHub, ký APK release. Chỉ dùng asset/source Go88 khi nhóm xác minh quyền phát hành. Không mở Emulator ra Internet hay coi lịch sử cầu là dự đoán.

Xem `docs/RULE_PARITY.md` để phân biệt rõ cái đã test và chưa làm.
