# Chơi chung qua VPS + Firebase Spark

## Trạng thái thực tế (05/11/2026)

VPS VN-2 (1 vCore, 2 GB RAM, 25 GB SSD) chạy Ubuntu 24.04; đã cập nhật hệ thống, SSH khóa công khai, firewall chỉ cho 22/80/443, swap 1 GB, Node 22, Caddy 2.11.8. Caddy đã lấy **chứng chỉ IP công khai hợp lệ** và hiện trả HTTP **503** vì backend chưa có credential/không được bật. Mã backend ở `/srv/prm393/functions` từ commit `e39d82f`; unit `/etc/systemd/system/prm393-backend.service` đã tạo nhưng **disabled**, không chạy. Không có kết quả test 35 người hoặc end-to-end production. Không nhầm `503` với backend đã triển khai.

## Kiến trúc

APK -> Firebase Auth/Firestore Spark (đăng nhập, nghe realtime); lệnh ghi/chơi -> `https://<IP-VPS>/api/<lệnh>` -> Caddy -> Node `127.0.0.1:8765` -> Firebase Admin SDK -> Firestore. Node chạy tick/cardTick mỗi phút; kết quả thực vẫn theo luật/transaction trong `functions/src`. Không cần Cloud Functions/Blaze hoặc Tailscale trên thiết bị lớp. **VPS 2 GB không loại bỏ quota Spark:** 50.000 reads, 20.000 writes/ngày của Firestore Standard; theo dõi Usage trong Console và load-test trước buổi học.

## Còn phải làm trước khi phát APK

1. Chủ Firebase project `ad2-8abfa540`: xác nhận Email/Password và Firestore rules; 3 composite indexes đã tạo ngày 05/11/2026 và được xác nhận **Enabled**. Tạo **service account riêng, quyền tối thiểu cho Firebase Auth và Firestore**, tải JSON một lần về máy tin cậy, không gửi qua chat/GitHub. Đặt ở `/etc/prm393/service-account.json` trên VPS bằng đường truyền SSH; owner `root`, group `prm393`, quyền `0440`, thư mục `/etc/prm393` `0750`. Không dùng key demo hoặc key của người khác. Chỉ bật backend sau khi kiểm credential trỏ đúng project.
2. Trên VPS: `sudo systemctl enable --now prm393-backend`; `sudo systemctl status prm393-backend`; kiểm từ VPS `curl -fsS http://127.0.0.1:8765/health`. **Chỉ sau khi backend chạy thật**, thay Caddyfile placeholder `respond ... 503` bằng `reverse_proxy 127.0.0.1:8765`, chạy `caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy`. Kiểm từ ngoài bằng `curl -fsS https://<IP-VPS>/health` **không dùng `-k`** và gọi API với tài khoản hợp lệ. Đừng mở 8765 công khai.
3. Cấp admin custom claim theo `docs/ONLINE_GROUP.md` (UID tài khoản thật), không dùng `admin@demo.test`. Test ít nhất hai người/thiết bị thật qua hai mạng: Tài/Xỉu, Bầu Cua, Xóc Xóc, Poker, Ba Cây; admin bị chặn khi dùng tài khoản player; các lệnh lặp không nhân điểm. Đo 35 client đồng thời và dashboard Firestore. Một doc round bị cập nhật bởi nhiều cược có thể gây contention; không cam kết mượt khi chưa đo.
4. Build APK **sau** khi kiểm backend: `flutter build apk --debug --dart-define=EMULATORS=false --dart-define=BACKEND_URL=https://<IP-VPS>`. `BACKEND_URL` là HTTPS origin, không port/path/query và không slash cuối. APK debug để thử, bản phát lớp nên ký release và kiểm trên Android Emulator/thiết bị. IP thay đổi thì build lại.

## Vận hành và bảo mật

- Caddy dùng Let's Encrypt **chứng chỉ IP ngắn hạn (~6 ngày)**, tự gia hạn khi dịch vụ chạy và cổng 80/443 thông; giám sát `journalctl -u caddy` và `curl -I https://<IP-VPS>/health` mỗi ngày demo. Không tắt Caddy để tránh hết hạn. Không dùng chứng chỉ tự ký hay bỏ kiểm TLS trong app.
- Backend chạy user `prm393` không phải root, systemd tự restart khi lỗi; đọc `journalctl -u prm393-backend -n 100 --no-pager`, RAM/CPU qua `free -h`, `uptime`, và Usage Firestore. Không log bearer token, mật khẩu, bài riêng. Trước khi dùng công khai cần giới hạn tốc độ gọi/abuse và kiểm kết nối mạng ngoài.
- Khóa SSH đã thêm cho máy chủ nhóm; SSH mật khẩu bị tắt, port 22 vẫn mở cho khóa. **Đổi mật khẩu root mặc định trong panel/VNC** khi có phương án khôi phục; tuyệt đối không đưa password/JSON key vào issue hoặc repo. Sau demo thu hồi service-account key, tắt dịch vụ nếu không dùng, rồi mới xóa dữ liệu theo quy trình nhóm.
- Nếu Firestore Spark vượt hạn mức, VPS dù còn CPU/RAM cũng không cứu được; giảm listener/read hoặc quyết định nâng Blaze với billing alert. Không tự chuyển sang database tự host giữa buổi demo.