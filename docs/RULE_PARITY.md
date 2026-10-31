# Luật đang chạy — đối chiếu bản Go88 tham khảo (01/11/2026)

Đây là **bản viết lại độc lập** dựa trên việc đọc tĩnh các file trong `C:\Users\Hiep\Downloads\gameGO88_unpacked\contents\Go88\app`. Không chạy mã tải ngoài, không sao chép asset/credential của bản đó. Các file tham khảo không nằm trong repo này. **Chưa khẳng định tương đương toàn bộ Go88.**

| Trò | Đã làm và test | Khác biệt còn lại |
|---|---|---|
| Tài/Xỉu | `Cron/taixiu.js`: 3 xúc xắc, tổng >10 là Tài, **bộ ba vẫn thắng**; trả gốc + lãi sau phí 2% làm tròn lên. Cược tiếp cùng cửa trong phiên; phần dư của cửa đông tiền được hoàn trước thanh toán. 216 kết quả và ca hoàn/chốt lặp được test. | Thứ tự hoàn ở bản Mongo không xác định rõ; bản này sắp theo lúc cược đầu tiên + UID để có kết quả lặp lại. Đơn vị điểm ảo và giới hạn khác cấu hình Go88. |
| Bầu Cua | `Cron/baucua.js`, `Controllers/game/baucua/cuoc.js`: mặt Hươu, Bầu, Gà, Cá, Cua, Tôm; trúng n mặt nhận gốc + 0,98×n×cược; cược bổ sung nhiều cửa. Test 216 kết quả. | Chỉ dùng cược bội số 100 để ví/ledger giữ số nguyên; không nhập bot hay cấu hình kinh tế Go88. |
| Xóc Xóc | `Controllers/game/XocXoc/init.js`, `cuoc.js`: bốn bit, sáu cửa Chẵn/Lẻ/3 đỏ/4 đỏ/3 trắng/4 trắng; trả 1,98×/3,94×/14,7×; các cửa thắng có thể đồng thời; cược tiếp nhiều cửa. Test cả 16 mẫu. | Đơn vị điểm ảo và lịch phiên thay thế; không dùng bot/config Go88. |
| Poker | `Controllers/game/poker/lib/room.js`, `player.js`: Texas Hold’em 52 lá; engine hiện có 4 vòng, so best-5/7, all-in chủ động, side-pot và bot đi lượt hợp lệ. | **Chưa tương đương:** source có cược mở đầu không đều, tính phí thắng 2%, hòa hoàn cược. Bản này vẫn ante bằng nhau, tố tăng số tiền tùy chọn nhưng bet mở đầu bằng ante, chia pot hòa, không rake. Một ván/bàn. |
| Ba Cây | `Controllers/game/BaCay/lib/room.js`, `player.js`: 36 lá A–9, 0 điểm là 10, so điểm rồi chất/lá theo source; Chương so từng người khác, lãi 0,98× làm tròn xuống mỗi đối đầu, ghi Chương kế tiếp. Test 7.140 bộ ba và 2–6 ghế. | **Chưa tương đương:** source có vòng Gà và chơi nhiều ván liên tiếp; repo hiện một ván/bàn, chưa xử lý Gà/luân chuyển Chương sang ván mới. |

`placeBet` cần `requestId` riêng cho **mỗi lần thêm cược**; gọi lại cùng ID/payload không trừ điểm lần hai, dùng ID cũ với tiền/cửa khác bị từ chối. Tài/Xỉu chỉ thêm cùng cửa; Bầu Cua/Xóc Xóc cho thêm nhiều cửa. Cược tối thiểu 1000, tối đa 1000000/người/phiên và bội số 100; Xóc Xóc nhận mệnh giá 1000/10000/50000/100000/1000000 như handler tham khảo. Một phòng tối đa 100 **người**/phiên. Mọi trừ/trả điểm qua Functions transaction + ledger; chỉ admin chọn kết quả hợp lệ **sau khi khóa cược**, audit chỉ admin đọc; hủy/hoàn một lần. Không có nạp/rút/giải thưởng.

Với ante Ba Cây nhỏ như 10 xu, `floor(0,98×ante)` làm phí hiệu dụng lớn hơn 2%; demo giữ đúng phép làm tròn của source, không gọi đây là phí phẳng 2%.

## Cầu / biểu đồ

Đọc tĩnh client `public/web/src/project.js` và backend tương ứng:

- **Tài/Xỉu:** nguồn `Controllers/taixiu/index.js` trả 125 phiên gần nhất; client có cầu nhóm các kết quả cùng Tài/Xỉu (tối đa 5 ô/cột, 20 cột) và biểu đồ 19 phiên gần nhất gồm tổng và từng xúc xắc. App hiện có cầu + biểu đồ cùng cửa sổ lịch sử này.
- **Xóc Xóc:** nguồn `Controllers/game/XocXoc/ingame.js` gửi 48 phiên; client nhóm Chẵn/Lẻ (tối đa 4 ô/cột, 12 cột). App hiện có cầu và danh sách kết quả bốn mặt.
- **Bầu Cua:** `Controllers/game/baucua/regOpen.js` trả 10 phiên mới, client hiện ba mặt của từng phiên; `BauCua_temp.js` giữ tần suất tích lũy. App hiện có 15 phiên mới và đếm mặt **chỉ trong cửa sổ đó**; không gọi đó là tần suất toàn lịch sử.
- **Poker/Ba Cây nhiều người:** chưa tìm thấy cầu công khai tương ứng trong client/backend đã khảo sát; đừng biến bảng thắng thành “dự đoán cầu”. App có danh sách 10 bàn đã chốt gần nhất theo trò, không gọi đó là cầu dự đoán; không có biểu đồ cầu kiểu Tài/Xỉu cho Poker/Ba Cây.

Cầu chỉ mô tả kết quả đã chốt, **không dự đoán** hay thay đổi thuật toán chốt. Kết quả admin chọn và random lưu cùng định dạng; widget cầu không hiển thị `mode`, nhưng tài liệu phiên Firestore công khai **có** `mode`. Actor/lý do/credit chi tiết chỉ nằm trong audit admin. Query lịch sử cần index `game/status/settledAt` trong `firestore.indexes.json`.

## Chưa kiểm chứng

Chưa chạy source gốc để so sánh từng trace, chưa có bộ fixture chính thức cho vòng Poker/Gà Ba Cây, chưa test tải đông người hay release production. Firebase Emulator mỗi máy có dữ liệu riêng; thay đổi schema cược từ `side/amount` sang `stakes/amount` **không hỗ trợ phiên đang mở của bản cũ**—dừng/xóa dữ liệu emulator thử nghiệm trước khi đổi phiên bản. Không deploy lên Firebase thật, không có APK release cấu hình thật. Đây là phạm vi còn lại cho nhóm trước khi tuyên bố “logic đủ 5 trò theo Go88”.
