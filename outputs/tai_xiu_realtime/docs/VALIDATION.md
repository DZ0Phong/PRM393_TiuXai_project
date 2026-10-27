# Kết quả kiểm tra — bản hoàn thiện 12/10/2026

## Đã đạt trên máy này
- Flutter analyze: No issues found.
- Flutter test: 2 test đạt — cấu hình emulator mặc định và giữ requestId/payload qua khởi tạo lại store, cách ly theo UID, xóa đúng user.
- Node unit: 2 test đạt, duyệt 216 tổ hợp xúc xắc, payout và validation. Backend syntax check đạt.
- Firebase Emulator integration: 2 nhóm test đạt, lượt cuối khoảng 34 giây. Có 5 Player và một Admin.
- Build Web mới: thành công tại build/web.
- Build Android debug mới: thành công tại build/app/outputs/flutter-apk/app-debug.apk, khoảng 198 MB; chưa ký release.

## Những tình huống đã kiểm chứng bằng integration
- Rules: không sửa ví/log trực tiếp; Player không đọc ví khác; Admin đọc được; audit chỉ cho user đăng nhập; người bị khóa không đọc phiên nhưng đọc được ví riêng.
- Multiplayer: 5 người cược cùng phiên; retry một cược không trừ lần hai; cược khác cùng phiên bị từ chối; deadline server chặn cược muộn; không chốt sớm; dice sai bị từ chối.
- Settlement: trả đúng xu, gọi hai lần không trả thêm; random tạo ba dice hợp lệ.
- Ví: nạp cùng requestId một lần; requestId khác payload bị từ chối; rút âm bị từ chối. Namespace wallet_ tách khỏi result_: người dùng gửi ID trùng tên ledger hoàn cược không thể làm kẹt phiên.
- Admin: Player không gọi được cancel/adjust/block; admin điều chỉnh cùng ID hai lần chỉ thay đổi một lần và một audit; không tự khóa; khóa có hiệu lực trên token Player cũ, mở khóa khôi phục.
- Hủy: refund đúng và không lặp; không chốt phiên hủy; hủy/chốt đồng thời chỉ một transition thành công, ledger và balance đúng với trạng thái cuối.

## Điều kiện và giới hạn
Build dùng Flutter SDK sẵn trên máy, Node 24.21, Java 21. Deploy runtime yêu cầu Node22; workflow CI cấu hình Node22/Java21 nhưng chưa chạy trên GitHub. Trên Windows, Emulator có thể còn tiến trình Java sau SIGINT; đã dọn đúng tiến trình test demo của workspace để tránh giữ cổng.

Lần kiểm npm runtime ở bản trước: npm audit --omit=dev = 0 cảnh báo; không đổi dependency Node ở bản này. Cây dev/CLI còn 16 cảnh báo (4 moderate,12 high), cần rà soát trước CI/triển khai chính thức. Chưa áp dụng ép downgrade hoặc override có nguy cơ phá CLI.

Build Android còn cảnh báo plugin dùng Kotlin Gradle Plugin/unchecked Java; Web cảnh báo font CupertinoIcons không đóng gói (UI không dùng CupertinoIcons). Cả hai build thành công.

Chưa kiểm thử tương tác browser/thiết bị Android bằng UI; test local storage là unit mock, test retry server là integration riêng, chưa tự động hóa toàn bộ mất mạng/reload end-to-end. Chưa deploy Firebase thật, kiểm scheduler/IAM/billing/App Check, benchmark 100 người hoặc ký release. Scheduler không chạy trong integration; random được chốt thủ công.

Script seed-emulator đã chạy thành công trên Auth Emulator: tạo 1 Admin + 5 Player. Không gửi dữ liệu đến Firebase thật.
