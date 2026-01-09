# DanaNet - Ứng dụng Phân loại & Thu gom Rác thải

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

**DanaNet** là ứng dụng di động kết nối cộng đồng nhằm thúc đẩy việc phân loại rác thải, bảo vệ môi
trường và xây dựng nền kinh tế tuần hoàn tại Đà Nẵng và Việt Nam. Ứng dụng tích hợp AI để nhận diện
rác, tạo sân chơi (Gamification) để khuyến khích người dùng, và cung cấp nền tảng giao dịch phế liệu
an toàn.

## Tính năng nổi bật
### 🤖 1. Công nghệ AI & Chatbot
* **Phân loại rác thông minh:** Sử dụng Google Gemini AI để phân tích hình ảnh từ camera và xác định
  loại rác (Tái chế, Hữu cơ, Vô cơ).
* **Trợ lý ảo BlueBot:** Chatbot tư vấn cách xử lý rác thải, giải đáp thắc mắc về môi trường và quy
  định phân loại.
### ♻️ 2. Diễn đàn Ve chai (Scrap Forum)
* **Đăng tin Mua/Bán:** Người dùng có thể đăng tin bán phế liệu hoặc tìm mua ve chai dễ dàng.
* **Bộ lọc khu vực:** Tìm kiếm tin đăng theo Tỉnh/Thành phố, Quận/Huyện, Phường/Xã.
* **Kết nối trực tiếp:** Gọi điện hoặc xem vị trí người bán ngay trên ứng dụng.
### 🛡️ 3. Giao dịch An toàn (Secure Transaction)
* **Xác thực QR Code:** Mỗi giao dịch tạo ra một mã QR động chứa thông tin định danh và tọa độ.
* **Chống gian lận bằng GPS:** Hệ thống chỉ cho phép xác nhận giao dịch khi thiết bị người mua và
  người bán cách nhau dưới **15 mét**.
* **Cộng điểm tự động:** Điểm thưởng (Green Points) được cộng ngay lập tức vào ví người bán sau khi
  quét mã thành công.
### 🎮 4. Gamification (Trò chơi hóa)
* **Vườn cây ảo:** Tích lũy "Giọt nước" từ các hoạt động xanh để tưới cây ảo. Cây sẽ lớn lên qua các
  cấp độ (Mầm -> Cây non -> Cây lớn...).
* **Đổi quà (Redeem):** Sử dụng điểm tích lũy để đổi lấy Voucher, thẻ cào hoặc quà tặng thân thiện
  môi trường.
### 👤 5. Tiện ích người dùng
* **eKYC:** Xác thực danh tính người dùng bằng cách chụp ảnh CCCD (Mặt trước/Sau).
* **Đa ngôn ngữ:** Hỗ trợ chuyển đổi tức thì giữa Tiếng Việt 🇻🇳 và Tiếng Anh 🇺🇸.
* **Giao diện:** Hỗ trợ chế độ Sáng (Light Mode) và Tối (Dark Mode).

## 🛠️ Công nghệ sử dụng
1/ ramework: [Flutter](https://flutter.dev/) (Dart)    
2/ Backend: Firebase (Authentication, Firestore Database, Cloud Storage)  
3/ AI Model: Google Generative AI (Gemini-2.5-flash)  
4/ Các thư viện chính:  
* `provider`: Quản lý trạng thái (State Management).  
* `google_generative_ai`: Tích hợp AI Google Gemini.  
* `mobile_scanner` & `qr_flutter`: Quét và tạo mã QR giao dịch.  
* `geolocator`: Định vị GPS và tính khoảng cách.  
* `camera` & `image_picker`: Xử lý hình ảnh và Camera Overlay.  
* `shared_preferences`: Lưu trữ dữ liệu cục bộ (Settings, Token).  
* `dropdown_search`: Tìm kiếm địa chỉ hành chính.  
* `flutter_markdown`: Hiển thị nội dung phản hồi từ AI.

## 🚀 Hướng dẫn cài đặt
Để chạy ứng dụng này trên máy cá nhân, bạn cần cài đặt Flutter SDK và thiết lập môi trường phát
triển.
### 1. Clone dự án
1/ git clone [https://github.com/Namprox/dananet.git](https://github.com/username/dananet.git)  
2/ cd dananet
### 2. Cài đặt các gói phụ thuộc
flutter pub get
### 3. Cấu hình Firebase & API Key
Truy cập Firebase Console, tạo dự án mới.  
1/ Tải file google-services.json (cho Android) và đặt vào thư mục android/app/  
2/ Tải file GoogleService-Info.plist (cho iOS) và đặt vào thư mục ios/Runner/  
3/ Lấy API Key từ Google AI Studio  
4/ Cập nhật biến _apiKeys trong file lib/screens/ai_chat_screen.dart và lib/screens/report_screen.dart
### 4. Chạy ứng dụng
Kết nối thiết bị thật hoặc máy ảo, sau đó chạy lệnh: flutter run

## 📂 Cấu trúc thư mục
lib/  
├── models/ # Các Model dữ liệu (Address, Feedback)  
├── providers/ # Quản lý trạng thái (ThemeProvider,   LanguageProvider)  
├── responsive/ # Các responsive layout  
├── screens/ # Các màn hình chính  
│ ├── admin/ # Màn hình dành cho Admin  
│ ├── components/ # Các Widget tái sử dụng (Drawer, Card, Button...)  
│ ├── forum/ # Màn hình Diễn đàn & Đăng tin của User  
│ ├── home_screen.dart # Màn hình chính  
│ ├── login_screen.dart # Đăng nhập/Đăng ký  
│ ├── ai_chat_screen.dart # Chatbot  
│ └── ...  
├── services/ # Xử lý Logic (AddressService)  
├── Firebase_options.dart # Xử lý lưu dữ liệu (Firebase)  
└── main.dart # Điểm khởi chạy ứng dụng

## 🤝 Đóng góp
Mọi đóng góp đều được hoan nghênh! Nếu bạn muốn cải thiện dự án, vui lòng:  
1/ Fork dự án  
2/ Tạo nhánh mới (git checkout -b feature/TinhNangMoi)  
3/ Commit thay đổi (git commit -m 'Thêm tính năng X')  
4/ Push lên nhánh (git push origin feature/TinhNangMoi)  
5/ Tạo Pull Request

## 📞 Liên hệ
Tác giả: Nguyễn Nam  
Email: namky1602@gmail.com  
Số điện thoại: 0907160203