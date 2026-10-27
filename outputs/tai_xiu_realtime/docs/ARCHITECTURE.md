# Kiến trúc và luật

Flutter → Firebase Auth (email/password) → Callable Functions (asia-southeast1) → Firestore transactions. Flutter nhận snapshot Firestore cho phòng, phiên, cược cá nhân, ví và audit. Mọi write từ client bị rules chặn. Admin xác định bằng custom claim admin=true do script chạy trong môi trường tin cậy; không có trường role do user sửa.

## Schema
- users/{uid}: balance nguyên, createdAt. Khởi tạo một lần 10000 xu.
- users/{uid}/operations/{operationId}: nạp/rút wallet_<requestId>, cược, trả thưởng/hoàn cược, điều chỉnh; delta và balance sau xử lý. RequestId trùng payload trả kết quả cũ.
- rooms/main: roundId hiện hành.
- rounds/{id}: mode random/admin cố định, status open/settled/cancelled, closesAt, betCount, dice, outcome, reason, settledBy.
- rounds/{id}/bets/{uid}: side, amount, credit, at, settledAt. UID là khóa chống cược lặp.
- auditLogs/{id}: actor UID, action, details, timestamp server. App không thể sửa/xóa. Người có quyền quản trị Firebase vẫn có thể sửa dữ liệu: đây chưa phải log chống giả mạo mật mã/WORM.

## Máy trạng thái
Admin tạo OPEN (30 giây) → deadline server khóa nhận cược → SETTLED. UI hiển thị đếm ngược để tham khảo; chỉ server xác định cược có hợp lệ. Sau deadline status có thể còn open trong lúc đợi chốt nhưng không nhận cược. Scheduler mỗi phút chốt random (có thể trễ hơn deadline); emulator không tự chạy Cloud Scheduler nên admin chốt thủ công. Admin mode bắt buộc chốt thủ công. Phiên tiếp theo mở sau khi phiên trước settled hoặc cancelled.

Giao dịch mở phiên đọc rooms/main và phiên cũ để ngăn mở hai phiên đồng thời. Giao dịch cược đọc ví/phiên/cược trước mọi write, kiểm deadline/số dư/số người, trừ xu + tạo cược + log cùng transaction. Settlement đọc toàn bộ cược và ví trước write, trả xu và đánh dấu settled nguyên tử; nếu gọi lại trả ok không trả xu thêm. Transaction tự retry khi tranh chấp; tối đa 100 người để giữ số write nhỏ trong MVP. Chưa benchmark tải.

## Luật công khai
Ba xúc xắc độc lập 1–6. Bộ ba (111,…,666) khiến cả Tài lẫn Xỉu thua. Các kết quả khác: tổng 4–10 Xỉu, 11–17 Tài. Mỗi phía có 105/216 kết quả thắng; bộ ba 6/216. Trừ toàn bộ cược ngay khi đặt. Thắng ghi có 2× cược gồm vốn (lãi ròng 1×); thua ghi có 0. Không phí. 10–1000 xu nguyên, một cược mỗi phiên, Player không sửa/hủy cược. Admin có thể hủy cả phiên chưa chốt với lý do công khai và hoàn toàn bộ cược.

Random dùng crypto.randomInt phía server. Không có commit/reveal nên người chơi chưa tự chứng minh được tính công bằng mật mã; backend Firebase là nguồn tin cậy. Admin mode phải công bố trước cược và không được đổi mode; admin nhập 3 dice hợp lệ sau deadline, lý do 5–300 ký tự, danh tính/time/dice lưu ở phiên và audit công khai. Không hỗ trợ âm thầm đổi kết quả phiên random hoặc sửa phiên đã chốt.

## Quyền và dữ liệu công khai
Player đọc ví/cược của mình, phiên và audit. Admin đọc mọi ví/cược, mở/chốt phiên. Audit công khai UID và amount để demo minh bạch, không chứa email; cần thiết kế lại quyền riêng tư nếu mở rộng ngoài nhóm. Nạp/rút chỉ mint/burn xu, 10–1000/lần, số dư sau thao tác ví từ 0 đến 100000. Xu trả thưởng có thể vượt trần nạp. Nạp lặp nhiều lần được phép trong demo. Không gửi hoặc nhận tiền.

## API callable
ensureProfile({}); wallet({requestId,kind:deposit|withdraw,amount}); startRound({mode:random|admin}); placeBet({roundId,side:tai|xiu,amount}); settleRound({roundId,dice:[a,b,c],reason}). Tất cả cần đăng nhập; start/settle cần admin claim. UI tạo requestId mới cho mỗi ý định ví; khi tích hợp retry ngoài SDK phải giữ nguyên requestId, không tạo id mới.

## Bổ sung quản trị và ledger
API mới:
- adjustBalance({uid,delta,reason,requestId}): chỉ Admin, delta khác 0 và ±100000, balance sau 0–1000000. Một transaction cập nhật ví + operation admin_<requestId> + audit ADJUST_BALANCE. ID trùng payload khác bị từ chối.
- setPlayerBlocked({uid,blocked,reason}): chỉ Admin, cấm tự khóa, ghi BLOCK_PLAYER/UNBLOCK_PLAYER. users.blocked là nguồn quyết định khóa. Callable kiểm trước xử lý; wallet/placeBet kiểm cả trong transaction. Rules chặn đọc phòng/phiên/cược, admin bị khóa cũng không được đọc ví người khác. Người bị khóa vẫn đọc ví/lịch sử riêng và audit. Auth identity được giữ để mở khóa và tra cứu; không disable Firebase Auth.
- cancelRound({roundId,reason}): chỉ Admin. OPEN → CANCELLED, hoàn cược + ledger + audit nguyên tử. SETTLED và CANCELLED là terminal; không sửa kết quả đã chốt. Retry cancel cùng phiên không hoàn thêm. Giao dịch cancel/settle cùng đọc round nên chỉ một transition thắng.

Mỗi ví có operation welcome, bet_<roundId>, result_<roundId> (payout/refund), admin_<requestId>, nạp/rút theo requestId. Ghi delta, số dư sau, thời gian server. Giữ tối đa 100 người vì settlement/refund giờ có thêm ledger write (khoảng 302 writes với 100 người). Cược đã đặt của người bị khóa vẫn được trả/hoàn bình thường. Dữ liệu cũ không tự tạo lại ledger; không reset ví.

UI lưu requestId/payload trước khi gửi thao tác wallet/adjustBalance bằng SharedPreferences. Chỉ xóa khi server xác nhận hoặc lỗi dứt khoát; lỗi mạng/internal giữ lại để retry. Giới hạn: local storage có thể bị xóa hoặc khác thiết bị; nhiều tab vẫn có thể tạo các ý định riêng. Server idempotency chỉ bảo vệ các request có cùng ID, không suy đoán hai ý định khác ID là một.

