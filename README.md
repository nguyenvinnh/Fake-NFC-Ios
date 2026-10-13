# Fake-NFC-iOS

Dự án tinh chỉnh (Tweak/Dylib) hỗ trợ giả lập dữ liệu NFC (NDEF Payload, UID thẻ) trực tiếp vào các ứng dụng quét NFC trên iOS (hỗ trợ cả các ứng dụng đọc thẻ như NFC Tools).

## Các tính năng nổi bật

- **fake thẻ NFC**: Hiện tại chỉ có 2 dạng là text và link
- **lưu mẫu nfc fake** : có thể lưu nfc fake lại và sử dụng lại ở lần sau


## Cách thức giả lập NFC hoạt động

1. **Inject cùng tiến trình (In-Process Hook)**:
   - Dylib được tiêm vào ứng dụng mục tiêu thông qua Substrate / Substitute / ElleKit (hoặc đóng gói kèm file IPA).
   - Vì nằm chung tiến trình bộ nhớ với ứng dụng mục tiêu, dylib có thể trực tiếp can thiệp vào các phương thức `CoreNFC`.

2. **Đánh chặn phiên quét (Session Hooking)**:
   - Tweak hook vào các lớp `NFCNDEFReaderSession` và `NFCTagReaderSession` của Apple ngay khi ứng dụng gọi `beginSession`.
   - Lưu lại đối tượng `delegate` và `session` mà ứng dụng mục tiêu đang dùng để lắng nghe sự kiện thẻ.

3. **Mô phỏng thẻ ảo (FakeNDEFTag)**:
   - Tweak tạo một đối tượng thẻ giả lập tuân thủ các chuẩn `NFCTag`, `NFCNDEFTag`, `NFCMiFareTag` với UID giả (Mifare 7-byte) và bộ dữ liệu NDEF đã được cấu hình.
   - Khi ứng dụng gọi `connectToTag:`, tweak đánh chặn và phản hồi kết nối thành công ngay lập tức (`error = nil`) thay vì chuyển xuống chip NFC phần cứng của máy.

4. **Kích hoạt Callback trả dữ liệu**:
   - Dylib gọi thẳng vào delegate của ứng dụng mục tiêu qua các hàm `tagReaderSession:didDetectTags:` hoặc `readerSession:didDetectNDEFs:`.
   - Khi đó, ứng dụng mục tiêu đọc dữ liệu trực tiếp từ thẻ giả lập và hiển thị kết quả giống hệt như khi quét một thẻ NFC thật ở mặt lưng máy.
