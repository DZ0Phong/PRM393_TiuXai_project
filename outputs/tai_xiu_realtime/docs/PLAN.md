# Kế hoạch nhóm 5 người

## Mục tiêu và phạm vi
MVP Android + Web, một phòng main, tối đa 100 người/phiên; email/password; ví xu giả lập; hai chế độ random/admin; lịch sử và audit công khai. Không có ngân hàng, cổng thanh toán, đổi thưởng, hoặc tiền thật. Không dùng client làm nguồn quyết định kết quả/số dư.

## Phân công và đầu ra
| Thành viên | Trách nhiệm chính | Mã phụ trách | Tiêu chí nghiệm thu |
|---|---|---|---|
| 1 — Lead/backend | Điều phối, thiết kế state machine, callable, review tích hợp | functions/src/index.js, docs | Cược đồng thời không âm ví; settlement không trả hai lần |
| 2 — Auth/security | Đăng ký, role claims, rules, script cấp/revoke admin | firestore.rules, scripts, phần Auth Flutter | Player không tự cấp quyền, không sửa ví/log; token mới nhận role |
| 3 — Flutter Player | Lobby, ví, form cược, trạng thái pending/error | lib/main.dart phần Player | Hai trình duyệt thấy cùng phiên, không cược sau deadline |
| 4 — Flutter Admin | Mở/chốt phiên, nhập dice/reason, lịch sử/audit | lib/main.dart phần Admin | Nhãn can thiệp trước cược; không đổi mode sau mở |
| 5 — QA/DevOps | Emulator, kiểm thử rules/race, build, tài liệu và CI | functions/test, test, firebase.json, README | Test âm/quyền/race/idempotency xanh, build web, smoke Android |

MVP hiện gom UI trong main.dart cho dễ chạy; khi làm nhóm, người 3/4 tách sang features/auth, wallet, game, admin và core/firebase, models, repositories. Người 1 chốt API trước, mỗi người làm branch feature/<ten>, PR nhỏ, một người khác review. Không cùng sửa main.dart trong một thời điểm.

## Lịch 3 tuần (15 ngày làm việc)
- Ngày 1–2: Người 1 chốt hợp đồng API/schema/luật; người 2 cấu hình emulator và role; người 3 dựng auth/lobby; người 4 wireframe admin; người 5 ma trận test. Đầu ra: cùng chạy một project demo.
- Ngày 3–5: Người 1 startRound/placeBet; người 2 rules và profile; người 3 ví/cược; người 4 chế độ công khai; người 5 negative/security test. Mốc: 2 browser đặt cược cùng phiên.
- Ngày 6–8: Người 1 settlement/scheduler; người 2 review quyền; người 3 kết quả/pending; người 4 audit/history; người 5 race/retry/late-bet. Mốc: luồng full random + admin.
- Ngày 9–10: Tích hợp, test mất mạng/reconnect, lỗi input, kiểm tra tính nhất quán xu; sửa lỗi nghiêm trọng.
- Ngày 11–12: CI, build Web/Android, README, demo account, seed; rà soát secrets và index.
- Ngày 13–15: Chạy nghiệm thu 5 người, sửa lỗi, đóng gói, báo cáo và video demo. Chỉ triển khai Firebase thật sau khi cấu hình và nghiệm thu.

## Backlog tiếp theo
Nhiều phòng; phân trang lịch sử; App Check và hạn mức nạp/ngày; outbox settlement chia batch khi >100 người; task queue chốt sát deadline; test tải; monitoring; retention audit. Điều chỉnh ví, hủy/hoàn phiên, cược toàn phòng và khóa truy cập game đã được triển khai. Disable/delete Firebase Auth là chức năng riêng chưa có. Admin trong game phải qua API có audit, không được sửa Firestore trực tiếp.

## Definition of Done
Analyze/build/test đạt; kiểm thử phân quyền, đồng thời, retry và reconnect; README cập nhật; không secrets; nhãn admin và lý do hiển thị đúng; reviewer khác đồng ý. Không coi unit test luật game là bằng chứng realtime/security đã đạt.

## Bản hoàn thiện — phần đã triển khai thêm
Hoàn thành backlog quản trị: setPlayerBlocked, adjustBalance, cancelRound, cược toàn phòng, ledger ví, lưu/retry request sau reload; tách AdminConsole/RoundBets/PendingMutationStore thành module riêng. Thêm workflow CI. Phần Auth/lobby vẫn ở main.dart và có thể tiếp tục chia theo feature khi nhóm mở rộng.

Backlog còn lại: nhiều phòng, phân trang lịch sử lớn, rate limit nạp theo ngày, App Check, task queue chốt sát deadline, commit/reveal, log WORM, tải >100 người, ký release Android, monitoring. Tính năng disable/delete Firebase Auth nếu cần phải thiết kế riêng; khóa hiện tại là khóa truy cập game bằng Firestore/API.

