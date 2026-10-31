# Kiến trúc hiện tại

Flutter → Firebase Auth → Functions callable (`asia-southeast1`) → Firestore transaction. Firestore snapshot cung cấp room, round, cược của mình, balance/ledger; custom claim `admin` giới hạn API và audit. Client không thể ghi Firestore. Điểm không chuyển ra ngoài app.

## Ba trò phiên

`rooms/{game}` giữ `roundId` hiện tại cho `tai_xiu`, `bau_cua`, `xoc_xoc`. `rounds/{roundId}` gồm `game`, `mode`, `status`, `closesAt`, `betCount`, `result`, `outcome`. Trạng thái `open → locked → settled`, hoặc từ `open/locked → cancelled`; terminal không đổi. `rounds/{id}/bets/{uid}` dùng UID để idempotent một cược/người. Deadline được kiểm server, scheduler khóa `open` quá hạn và chốt `locked` random. Admin chốt `locked` với kết quả hợp lệ/lý do; random dùng `crypto.randomInt`. Thông tin actor, lý do, từng credit lưu audit chỉ admin; round công khai chỉ có kết quả và mode, không có lý do. Admin không thể đổi `mode` qua API sau mở phiên.

`users/{uid}` có balance nguyên; `operations/welcome`, `bet_<roundId>`, `result_<roundId>`, `admin_<requestId>` lưu delta/balance. Chốt/hủy đọc round, bets, users trước write trong transaction, ghi tất cả atomically. Retry settled/cancelled không trả thêm. Admin adjustment cũng idempotent theo requestId và payload. Không có endpoint nạp/rút. Audit chỉ admin đọc; chủ project có toàn quyền admin SDK nên không phải log WORM.

## Poker/Ba Cây còn thiếu

Module luật thuần dùng để kiểm thử xếp bài, chưa có server-authoritative table engine, dữ liệu lá bài riêng, phòng 2–6 ghế, timeout, bot, matchmaking hay ứng dụng player cho hai trò. Không tạo dữ liệu bài giả mạo. Thiết kế mốc tiếp: bàn `waiting → dealing → betting → showdown → settled`, state/private card theo UID, bot service identity nội bộ và audit config. Cần kiểm tra all-in/side-pot, thứ tự turn, fold, leave/disconnect, timer retry, fairness trước khi mở trò.

## Security/triển khai

Firestore rules chỉ cho player đọc ví/ledger và cược của mình, admin đọc dữ liệu quản trị; mọi client write bị từ chối. Auth custom claim do script server-side cài. App Check chưa enforce; cần bật và test trên thiết bị thật trước production. Không import package Go88; xác minh quyền asset nếu muốn dùng sau. Không có nguồn tiền/quà. Rules/admin claim không bảo vệ khi Firebase project owner mất quyền kiểm soát. Không dùng Emulator mở Internet.
