# Luật backend đang chạy và mức độ đối chiếu Go88

Đối chiếu **tĩnh** ngày 01/11/2026 với bản Go88 đã giải nén tại máy phát triển (`contents/Go88/app/`); không chạy, nhập source/dependency/asset của bản tải ngoài. Những nhánh không kiểm kê không được coi là tương đương. **Năm trò hiện tại là luật mô phỏng riêng để test luồng, không phải bản port tương đương Go88.** Các đường dẫn Go88 dưới đây là tương đối với thư mục `app/` của bản tham khảo, không tồn tại trong repo nhóm.

| Trò | Backend repo này (testable) | Khác biệt có thể xác nhận trong bản tham khảo |
|---|---|---|
| Tài/Xỉu | Ba xúc xắc, tổng 11–17 Tài/4–10 Xỉu; bộ ba đồng mặt thua hai cửa; trúng nhận 2× cược gồm vốn. Một cược/người/phiên, 10–1000 điểm. | `Cron/taixiu.js` xét tổng >10, **không loại bộ ba** trong nhánh xét Tài/Xỉu đã đọc. Lãi thắng trừ phí 2% làm tròn lên; có cân cửa/hoàn cược và khả năng cộng cược. Đây **không** là cùng bảng thắng/thua/điểm với repo. |
| Bầu Cua | Sáu mặt `bau,cua,tom,ca,ga,nai`; trúng n mặt trả `(1+n)×cược`, tối đa một mặt cược/người/phiên. | `Cron/baucua.js` dùng chỉ số `hươu,bầu,gà,cá,cua,tôm`, lãi trúng mặt nhân 0,98; `Controllers/game/baucua/cuoc.js` hỗ trợ nhiều cửa/cộng cược. Biểu diễn mặt và tiền nhận khác. |
| Xóc Xóc | Bốn bit 0/1; chỉ có Chẵn/Lẻ theo tổng bit, trúng 2×. | `Controllers/game/XocXoc/init.js` có thêm 3/4 đỏ và 3/4 trắng (tổng sáu cửa), trả 1,98×/3,94×/14,7× theo cửa; `Controllers/game/XocXoc/cuoc.js` cho cược nhiều cửa. |
| Poker | Texas Hold’em chọn 5 lá mạnh nhất từ 7, ante chung, cược fixed-limit, một lần raise/vòng, có all-in **thông qua call khi thiếu stack** và side pot; không trừ phí. | `Controllers/game/poker/lib/room.js` và `player.js` có cách đặt/tố/tất tay và xử lý tiền thắng/phí khác. Không khẳng định cùng bàn cược hoặc cùng cơ chế so bài. Repo hiện **không có nút all-in chủ động**. |
| Ba Cây | Bộ 52 lá; ba lá/người, điểm 0 đổi thành 10; so điểm rồi thứ tự lá/chất, một người thắng toàn pot, không trừ phí. | `Controllers/game/BaCay/lib/room.js` dùng 36 lá đầu, có Chương/Gà và đối chiếu người chơi với Chương, chốt/phí khác. Đây là mô phỏng khác cấu trúc bàn. |

## Phần đã hoạt động trong repo

- Server chịu trách nhiệm toàn bộ điểm, cược, chia bài/chốt kết quả; Firestore client không được ghi. Ledger theo UID và `requestId`/mã phiên, transaction và test retry/race để tránh trừ/hoàn/chốt lặp. Hai trò bài giữ bài kín ở `cardSecrets`; player chỉ đọc bài riêng của mình ở `hands/{uid}`.
- Admin mở phiên ở chế độ `admin` hoặc `random`. Với **ba trò phiên**, admin chỉ được chọn **kết quả hợp lệ sau khi hết hạn và phiên đã `locked`**; không sửa kết quả terminal. Kết quả/lý do/tác động ghi audit chỉ admin đọc. Phiên `random` dùng CSPRNG, không nhận kết quả do admin truyền. Hủy trước chốt trả lại điểm đúng một lần.
- Poker/Ba Cây 2–6 ghế, tối thiểu hai ghế mới bắt đầu. Admin bật/tắt, giới hạn bot ở bàn chờ; bot dùng ví và engine chung, không tạo điểm mỗi bàn. Hành động bot là nội bộ cùng kiểm tra luật, **không phải bot gọi Firebase Auth/callable như thiết bị thật**. Không nhắm cá nhân để điều chỉnh thắng/thua.

## Chưa làm / cần quyết định trước khi đổi luật

1. Nhóm chốt **luật nào là bài tập cần kiểm**: luật mô phỏng hiện tại (dễ test, không phí) hay bảng luật tương thích một phần Go88. Nếu đổi, phải chốt bộ ba Tài/Xỉu, phí/làm tròn, sáu cửa Xóc Xóc, cược đa cửa và Chương/Gà; sửa **engine + callable + ledger + UI + tests đồng thời**, không thay một công thức đơn lẻ. Không sao chép source/asset bản tham khảo vào repo khi chưa rõ quyền sử dụng.
2. Emulator trên mỗi máy có dữ liệu riêng; chưa có Firebase production, backend online, App Check, release signing, thử tải đồng thời nhiều điện thoại. Scheduler không tự chạy trong bộ Emulator local hiện tại; admin dùng Khóa/Chốt thủ công và integration test gọi hàm timeout.
3. Poker/Ba Cây hiện **một ván/bàn**; chưa có mời bằng link, tự ghép bàn, multi-hand hoặc reconnect test trên thiết bị thật. Những phần này không được coi là đã hoàn thiện chỉ vì unit/integration test xanh.

Các test hiện tại kiểm **luật mô phỏng được ghi ở đây**, không chứng minh tương đương toàn bộ source tham khảo hay khả năng tải nhiều thiết bị trên Firebase thật.
