# Nghiệm thu thủ công
1. Chạy emulators. Mở 5 cửa sổ browser, đăng ký 5 email khác nhau; mỗi người có 10000 xu, không tự thay đổi số dư/role từ Firestore.
2. Cấp claim cho một UID bằng script; đăng xuất/đăng nhập. Chỉ tài khoản đó thấy bảng admin và được gọi start/settle.
3. Mở RANDOM; cả 5 thấy cùng roundId/deadline. Đặt cược 100 từ 4 người, một người gửi 2 request đồng thời: chỉ bị trừ 100 và chỉ có một cược.
4. Chỉnh đồng hồ client hoặc gửi cược sau 30 giây: server từ chối. Chốt trước deadline bị từ chối. Admin chốt random không được chọn kết quả; production scheduler tự chốt.
5. Mở ADMIN; trước cược mọi người đều thấy nhãn CÓ CAN THIỆP. Sau khóa, nhập 2,3,6 và lý do. Tài nhận 200, Xỉu nhận 0. Chốt lại không cộng thêm. Không đổi mode/kết quả phiên đã chốt.
6. Phiên ADMIN 6,6,6: cả hai phía thua. Input 0,7,2; lý do ngắn; số xu âm/lẻ/quá giới hạn bị từ chối.
7. Nạp/rút xu giả lập, gửi lại cùng requestId không thay đổi ví lần hai. Không rút quá số dư. Không có bất kỳ phương thức thanh toán nào.
8. Mất mạng giữa cược rồi kết nối lại: đọc cược cá nhân và số dư server để biết trạng thái. Bấm cược lại cùng phiên không trừ thêm. Với retry ví phải dùng lại requestId; UI lưu thao tác chờ và không cho ghi đè trước khi xác nhận.
9. Audit có START/BET/SETTLE/deposit/withdraw/WELCOME, actor/time/details. Player/Admin qua app đều không thể sửa/xóa log. Kiểm tra luật và kết quả trên 2 browser.
10. Chạy analyze/test/build, emulator integration. Ghi thiết bị, phiên bản SDK, kết quả và lỗi; không coi build thành công là đã nghiệm thu toàn bộ UX.

## Nghiệm thu quản trị bổ sung
11. Admin chọn UID, trừ/cộng xu với lý do. Player không gọi được API này; không cho số dư âm; gửi lại cùng requestId chỉ điều chỉnh một lần. Audit và ledger phải cùng khớp số dư.
12. Khóa một Player đang đăng nhập. Player không cược/nạp/rút/đọc phiên được với token cũ, vẫn xem lý do và ví. Mở khóa khôi phục sử dụng. Admin không tự khóa mình.
13. Hủy phiên có 5 người cược: mỗi người được hoàn đúng số cược; retry hủy không hoàn lại. Không chốt phiên đã hủy, không hủy phiên đã settled. Hủy/chốt đồng thời chỉ một thao tác thành công.
14. Tắt mạng ngay sau bấm nạp; reload app, bật mạng, thử lại thao tác chờ. requestId phải giữ nguyên; ledger/số dư chỉ thay đổi một lần. Kiểm thử thủ công này chưa được tự động hóa hoàn chỉnh; unit test kiểm lưu/khôi phục payload, integration kiểm server dedupe.
