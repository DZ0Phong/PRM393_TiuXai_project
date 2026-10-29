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

## Cập nhật kiểm tra 29/10/2026 — sau sửa CI, dependency và pending mutation

- Ở thời điểm kiểm tra ban đầu, checkout `main` tại commit gốc `815a92a` và thay đổi còn ở working tree; trạng thái này đã thay đổi sau khi tạo/push nhánh `Hiep`.
- Flutter 3.47.5 / Dart 3.13.4: `flutter analyze` không lỗi; `flutter test` **3/3 đạt** (thêm test từ chối ghi đè requestId/payload chờ); `flutter build web --no-pub` thành công.
- Node unit **2/2 đạt**; `npm run check` đạt. `npm audit --omit=dev` **0 vulnerabilities** sau khi cập nhật lockfile: body-parser runtime 2.4.0, qs 6.16.2. Cây đầy đủ gồm dev tooling còn 18 cảnh báo (5 moderate, 13 high), chưa xử lý trong lần này.
- Firebase Emulator integration **2/2 nhóm đạt** sau sửa, với `demo-tai-xiu`; scheduler `tick` không chạy vì chưa bật Pub/Sub emulator. Emulator trên máy dùng Node 24.13.0 dù `functions/package.json` yêu cầu Node 22; CI được cấu hình Node 22 nhưng chưa chạy remote.
- Android wrapper đã đưa vào Git từ ZIP v2, `gradlew` giữ executable bit. Hai build Android chạy đồng thời gây lỗi cache Kotlin/resource; sau khi dừng build song song, `flutter clean`, `flutter pub get` và build tuần tự, `flutter build apk --debug --no-pub` **thành công** tại `build/app/outputs/flutter-apk/app-debug.apk`. Đây là debug APK, không phải release đã ký.
- Chưa kiểm tra UI tương tác trên thiết bị/browser, mất mạng + reload end-to-end, Firebase production, scheduler thực, tải 100 người hoặc CI remote. Việc chặn race pending được kiểm bằng unit store và phân tích luồng UI, chưa có widget/e2e test cho chính thời điểm chuyển phiên đăng nhập.

## Cập nhật 29/10/2026 — nhánh Hiep

- Nhánh `Hiep` đã push commit `8a64c6f`, còn `main` tại `815a92a`. GitHub Actions run #1 trên commit này **thành công** (khoảng 11 phút 21 giây): Flutter analyze/test, build Web/Android debug, Node unit/check/audit runtime và Emulator integration đều đạt.
- Sửa cấu hình build: debug mặc định bật Firebase Emulator, release mặc định tắt; build release với cấu hình demo vẫn không phải bản để phát hành. Web build cục bộ thành công; chuỗi `Firebase Emulator` và `127.0.0.1` không có trong `build/web/main.dart.js` của lần build này. Android debug APK build lại thành công. Flutter analyze không lỗi; 3 Flutter test đạt.
- Nút cược/chốt không khóa theo đồng hồ máy người dùng nữa: trạng thái phiên quyết định nút, server vẫn kiểm deadline thực. Điều này tránh đồng hồ client chạy nhanh làm mất quyền thao tác hợp lệ; client chạy chậm có thể gửi thao tác muộn và nhận lỗi từ server.
- Smoke UI trên Edge + Flutter Web debug + Firebase Emulator: đăng ký Player tạo ví 10000 xu, nạp 100 → 10100, cấp Admin claim trên Emulator rồi đăng nhập lại, mở RANDOM, cược Tài 100, sau hạn chốt kết quả [5,2,1] Xỉu; ledger hiển thị trừ 100 và trả 0, phiên chuyển settled. Đây là kiểm thử một luồng tương tác thực, không phải UI E2E tự động/toàn bộ chức năng.
- Chưa xác minh UI trên Android, mất mạng/reload end-to-end, scheduler production, Firebase thật, tải 100 người và release ký. npm ci trên CI Node 22 có cảnh báo engine từ một số dev dependency; cần phân loại khi nâng dependency/tooling, không mặc nhiên coi cảnh báo là lỗi runtime.
