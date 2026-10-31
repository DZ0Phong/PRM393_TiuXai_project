# Nghiệm thu

- Điểm ảo không nạp/rút, không thưởng/quà, không đổi tiền.
- Ba trò phiên: cược sát hạn bị từ chối server, một cược/người, random hoặc kết quả admin hợp lệ sau `locked`; chốt/hủy retry không nhân đôi ledger; admin audit không lộ player.
- Tài khoản bị khóa không chơi; player không gọi admin API, không ghi trực tiếp Firestore.
- Poker/Ba Cây chỉ nghiệm thu khi server turn/table và bot đã có integration tests; hiện **chưa đạt**.
- Flutter analyze/test/debug APK, functions unit + Emulator, kiểm multi-device; App Check và ký release trước khi phát hành.
