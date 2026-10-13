# Fake-NFC-iOS

Dự án tinh chỉnh (Tweak/Dylib) hỗ trợ giả lập dữ liệu NFC (NDEF Payload, UID thẻ) trực tiếp vào các ứng dụng quét NFC trên iOS (dự án này được thử nghiệm trên ứng dụng NFC Tool).

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

##  Mục Đích Nghiên Cứu & Học Tập

* Dự án này được tạo ra **chỉ nhằm mục đích nghiên cứu bảo mật, học tập cách hoạt động của Objective-C Runtime, cơ chế Hooking trong iOS (Theos/Logos)** và tìm hiểu cách các ứng dụng xử lý dữ liệu như thế nào
* Không khuyến khích hoặc cổ xuý việc sử dụng tweak này để gian lận, lừa đảo, hoặc vi phạm điều khoản sử dụng của bất kỳ bên thứ ba nào.

## Điều Khoản Sử Dụng Mã Nguồn (License & Usage)
* Chia sẻ miễn phí: Mã nguồn của dự án này được chia sẻ hoàn toàn miễn phí phục vụ mục đích học tập và nghiên cứu cá nhân.

* Yêu cầu xin phép: Nếu bạn có ý định sử dụng, tích hợp hoặc tham khảo một phần hay toàn bộ mã nguồn này vào bất kỳ dự án nào khác (bao gồm cả dự án thương mại/có lợi nhuận lẫn phi lợi nhuận), bạn bắt buộc phải có sự đồng ý/cho phép bằng văn bản từ tác giả trước khi thực hiện.

##  Tuyên Bố Trách Nhiệm 

* **Tự chịu trách nhiệm:** Người sử dụng tự chịu hoàn toàn mọi rủi ro, trách nhiệm pháp lý hoặc các hình thức xử phạt (như khóa tài khoản tạm thời/vĩnh viễn) từ nhà phát hành ứng dụng mục tiêu khi quyết định sử dụng dự án này.
* **Không bảo đảm:** Tác giả không chịu bất kỳ trách nhiệm nào đối với bất kỳ thiệt hại trực tiếp hoặc gián tiếp nào phát sinh từ việc sử dụng, triển khai hoặc lạm dụng mã nguồn từ dự án này.
