# Nghiệm thu

- Điểm ảo không nạp/rút, không thưởng/quà, không đổi tiền.
- Ba trò phiên: cược sát hạn bị từ chối server, cược bổ sung trong hạn có requestId chống trùng (Tài/Xỉu cùng cửa, Bầu Cua/Xóc Xóc nhiều cửa), random hoặc kết quả admin hợp lệ sau `locked`; chốt/hủy retry không nhân đôi ledger; admin audit không lộ player.
- Tài khoản bị khóa không chơi; player không gọi admin API, không ghi trực tiếp Firestore.
- Poker/Ba Cây đã có unit/integration cho lượt/ví/bot/bài riêng; **chưa nghiệm thu parity đầy đủ với Go88**: Poker còn blind/phí/hòa, Ba Cây còn Gà/ván kế. Cầu chỉ trình bày lịch sử đã chốt, không dự đoán.
- Flutter analyze/test/debug APK, functions unit + Emulator, kiểm multi-device; App Check và ký release trước khi phát hành.
