# Kiến trúc hiện tại

Flutter → Firebase Auth → Functions callable (`asia-southeast1`) → Firestore transaction. Firestore snapshot cung cấp room, round, cược của mình, balance/ledger; custom claim `admin` giới hạn API và audit. Client không thể ghi Firestore. Điểm không chuyển ra ngoài app.

## Ba trò phiên

`rooms/{game}` giữ `roundId` hiện tại cho `tai_xiu`, `bau_cua`, `xoc_xoc`. `rounds/{roundId}` gồm `game`, `mode`, `status`, `closesAt`, `betCount`, `result`, `outcome`. Trạng thái `open → locked → settled`, hoặc từ `open/locked → cancelled`; terminal không đổi. `rounds/{id}/bets/{uid}` dùng UID để idempotent một cược/người. Deadline được kiểm server, scheduler khóa `open` quá hạn và chốt `locked` random. Admin chốt `locked` với kết quả hợp lệ/lý do; random dùng `crypto.randomInt`. Thông tin actor, lý do, từng credit lưu audit chỉ admin; round công khai chỉ có kết quả và mode, không có lý do. Admin không thể đổi `mode` qua API sau mở phiên.

`users/{uid}` có balance nguyên; `operations/welcome`, `bet_<roundId>`, `result_<roundId>`, `admin_<requestId>` lưu delta/balance. Chốt/hủy đọc round, bets, users trước write trong transaction, ghi tất cả atomically. Retry settled/cancelled không trả thêm. Admin adjustment cũng idempotent theo requestId và payload. Không có endpoint nạp/rút. Audit chỉ admin đọc; chủ project có toàn quyền admin SDK nên không phải log WORM.

## Bàn Poker/Ba Cây

`cardTables/{uid_requestId}` là bản công khai chỉ chứa ghế, số điểm, vòng, bài chung và kết quả; `cardTables/{id}/hands/{uid}` chỉ UID đó đọc; `cardSecrets/{id}` chứa state, bộ bài và bài của mọi người, Firestore rules không cho client đọc/ghi. Functions tạo/tham gia giữ mua vào `10×ante` trong ví, tạo `operations/table_join_*`; mã bàn cũng là mã mời. Chủ bàn hoặc admin bắt đầu sau khi có 2–6 ghế. Admin được bật bot và giới hạn số bot trước khi bắt đầu. Bot nội bộ `bot_01`…`bot_05`, biệt danh chung không mạo danh người thật, có ví 10.000 điểm khởi tạo một lần và ledger như player; UI hiện nhãn bot. Admin hủy bàn chờ/đang chơi sẽ hoàn đúng một lần; không hủy bàn đã chốt. Một bàn chỉ có một ván.

Ba Cây chia ba lá, góp ante và so điểm ngay theo `card_games.js` (10 điểm cao nhất và tie break đã ghi trong unit test). Poker có ante, fixed-limit stake, một raise/vòng, check/bet/call/fold, 4 vòng, all-in/side-pot. `actionVersion` chống gọi lại lượt cũ, `turnDeadline` 45 giây được kiểm server; `cardTick` mỗi phút thực hiện check hoặc fold nếu hết hạn. Bot chọn ngẫu nhiên trong các hành động hợp lệ bằng CSPRNG, không nhắm người chơi. Engine chốt bảo toàn tổng buy-in, ví payout, ledger và public state trong một transaction; audit ghi action/start/config/cancel/timeout. Không có matchmaking tự động, multi-hand, friend link/push hay spectator riêng; cần thử trên nhiều thiết bị và kiểm tải trước buổi học.

## Security/triển khai

Firestore rules chỉ cho player đọc ví/ledger và cược của mình, admin đọc dữ liệu quản trị; mọi client write bị từ chối. Auth custom claim do script server-side cài. App Check chưa enforce; cần bật và test trên thiết bị thật trước production. Không import package Go88; xác minh quyền asset nếu muốn dùng sau. Không có nguồn tiền/quà. Rules/admin claim không bảo vệ khi Firebase project owner mất quyền kiểm soát. Không dùng Emulator mở Internet.
