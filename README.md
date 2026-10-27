# 🔊 PC Speaker - Biến iPhone / iPad Thành Loa Máy Tính Không Dây (iOS Swift)

Phiên bản iOS hoàn chỉnh được phát triển bằng **Swift & SwiftUI** dựa trên ứng dụng **PC Speaker (id6779549252)** trên App Store, tích hợp trực tiếp với **PC Sender (Python WASAPI Loopback 48kHz)**.

---

## 🌟 Tính Năng Nổi Bật (Key Features)

1. **Truyền Âm Thanh Không Dây Độ Trễ Thấp (< 30ms)**:
   - Thu trực tiếp mixer âm thanh đầu ra từ máy tính Windows (WASAPI Loopback) ở chuẩn chất lượng phòng thu **Float32 PCM @ 48,000 Hz Stereo**.
   - Stream qua mạng nội bộ Wi-Fi bằng giao thức **WebSocket** băng thông cao.
   - Trình phát iOS sử dụng **AVAudioEngine** kết hợp **AVAudioSourceNode** và **Lock-Free Ring Buffer** loại bỏ hiện tượng giật/lag tiếng, xem phim không lệch khẩu hình (lip-sync), chơi game mượt mà.

2. **Dò Tìm & Kết Nối Tự Động (Auto-Discovery)**:
   - **Tự động kết nối (Auto Connect)**: Ứng dụng tự động tìm thấy PC trong cùng mạng Wi-Fi thông qua gói tin **UDP Beacon (Cổng 8888)** mà không cần người dùng phải làm gì.
   - **Quét mã QR (QR Code Scanner)**: Quét trực tiếp mã QR được in ra trên màn hình terminal của máy tính để kết nối ngay lập tức.
   - **Nhập IP thủ công**: Cho phép nhập trực tiếp địa chỉ IP mạng LAN và cổng (mặc định `:8080`).
   - **Lịch sử kết nối (History)**: Tự động lưu danh sách máy tính đã ghép nối, hỗ trợ kết nối lại nhanh chỉ bằng 1 chạm.

3. **Giao Diện Trực Quan Hiện Đại (App Store Standard)**:
   - **Thanh VU Meter (Input Level)**: Cột đo mức âm lượng thời gian thực nhảy theo điệu nhạc với dải màu Gradient (Cyan ➔ Green ➔ Amber ➔ Red).
   - **Bảng thống kê 3 cột**: Theo dõi tức thì số lượng **Frames**, tổng dung lượng nhận **Data (MB)**, và trạng thái **Output**.
   - **Chi tiết kỹ thuật & Tùy chỉnh (Details)**:
     - Nhận diện thiết bị âm thanh đang phát: Loa ngoài iPhone, Tai nghe có dây, AirPods Pro, Loa Bluetooth.
     - Hiển thị mức % âm lượng media của điện thoại.
     - Bộ tăng cường âm lượng **Playback Gain** (`0.1x` ➔ `3.0x`).
     - Đo đạc chỉ số mức năng lượng âm thanh RMS thời gian thực.

4. **Hỗ Trợ Phát Nền & Điều Khiển Màn Hình Khóa (Background Audio & Lock Screen)**:
   - Cấu hình chuẩn `AVAudioSession` danh mục `.playback` và Background Mode `audio`.
   - Âm thanh tiếp tục phát trơn tru ngay cả khi **khóa màn hình** hoặc **chuyển sang ứng dụng khác**.
   - Tích hợp **Now Playing & Remote Command Center**: Hiển thị tên máy tính, biểu tượng âm thanh trên Màn hình khóa và Trung tâm điều khiển (Control Center).

---

## 📁 Cấu Trúc Thư Mục Dự Án

```
Pc Speaker-Ios/
├── PCSpeaker.xcodeproj/            # File dự án Xcode chuẩn
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/PCSpeaker.xcscheme
│
├── PCSpeaker/                      # Mã nguồn Swift ứng dụng iOS
│   ├── App/
│   │   ├── PCSpeakerApp.swift      # SwiftUI App lifecycle & khởi tạo AVAudioSession
│   │   └── Info.plist              # Quyền Camera, Local Network & Background Audio Mode
│   │
│   ├── Audio/
│   │   ├── AudioStreamPlayer.swift # Engine AVAudioEngine + AVAudioSourceNode (48kHz Float32)
│   │   ├── LockFreeRingBuffer.swift# Bộ đệm vòng luồng thực thi âm thanh độ trễ thấp
│   │   └── AudioStreamStats.swift  # Model trạng thái & thống kê kết nối
│   │
│   ├── Network/
│   │   ├── AudioWebSocketClient.swift # Client URLSessionWebSocketTask nhận chunk PCM
│   │   └── NetworkDiscoveryManager.swift # UDP Socket (Cổng 8888) dò tìm PC tự động
│   │
│   ├── Services/
│   │   ├── AudioReceiverService.swift # ViewModel trung tâm điều phối toàn bộ luồng
│   │   ├── ConnectionHistoryManager.swift # Quản lý lịch sử các máy tính đã lưu
│   │   └── NowPlayingManager.swift # Lock Screen / Control Center Now Playing
│   │
│   ├── Theme/
│   │   └── AppTheme.swift          # Bảng màu, Gradient, Card Styling & Haptics
│   │
│   ├── Views/
│   │   ├── MainView.swift          # Giao diện Dashboard chính
│   │   ├── Components/
│   │   │   ├── VUMeterView.swift   # Thanh VU Meter nhảy sóng âm thời gian thực
│   │   │   ├── StatusHeaderCard.swift # Card trạng thái kết nối & cảnh báo thông minh
│   │   │   ├── StatsRowView.swift  # Hàng thống kê 3 cột (Frames | Data | Output)
│   │   │   ├── DetailsAccordionView.swift # Accordion mở rộng chi tiết và chỉnh Gain
│   │   │   └── ActionButtonsView.swift # Cụm nút bấm Auto Connect, QR, IP, Lịch sử
│   │   └── Sheets/
│   │       ├── QRScannerView.swift # Trình quét mã QR Camera với tâm ngắm & Đèn Flash
│   │       ├── ManualIPSheet.swift # Hộp thoại nhập địa chỉ IP thủ công
│   │       ├── HistorySheet.swift  # Danh sách lịch sử kết nối & nút xóa
│   │       └── HelpGuideSheet.swift# Màn hình hướng dẫn cài đặt & khắc phục sự cố
│   │
│   └── Assets.xcassets/            # AppIcon & AccentColor
│
└── pc-sender/                      # Bộ truyền âm thanh chạy trên Windows / Mac
    ├── pc_sender.py                # Bắt âm WASAPI Loopback 48kHz, WebSocket Server & UDP Beacon
    ├── requirements.txt            # Thư viện: websockets, soundcard, numpy, qrcode
    └── run_sender.bat              # Script 1-click tự động chạy trên Windows
```

---

## 🚀 Hướng Dẫn Chạy & Kết Nối

### Bước 1: Khởi Chạy PC Sender Trên Máy Tính (Windows)
1. Mở thư mục `pc-sender` trong dự án.
2. Bạn có thể:
   - **Cách 1 (Nhanh nhất)**: Nhấp đúp vào file `run_sender.bat` (tự động cài thư viện và chạy).
   - **Cách 2 (Bằng Terminal)**:
     ```powershell
     cd pc-sender
     pip install -r requirements.txt
     python pc_sender.py
     ```
3. Sau khi chạy, terminal sẽ in ra:
   - Địa chỉ IP mạng nội bộ của bạn (ví dụ: `192.168.1.15`).
   - Cổng WebSocket `8080` và cổng Auto-Discovery `8888`.
   - Mã QR để quét trên điện thoại.

---

### Bước 2: Mở Dự Án iOS Trên Xcode
1. Mở phần mềm **Xcode** trên máy Mac.
2. Chọn **Open a project or file** và mở thư mục:
   `PCSpeaker.xcodeproj`
3. Tại thanh Toolbar phía trên, chọn thiết bị iPhone của bạn (hoặc máy ảo iPhone Simulator).
4. Nhấn phím `Cmd + R` hoặc bấm nút **Play (Run)** để biên dịch và cài đặt lên máy.

*(Lưu ý: Nếu cài trực tiếp lên iPhone thật, hãy vào mục **Signing & Capabilities** trong Xcode và chọn Team Apple ID của bạn để kích hoạt Signing).*

---

### Bước 3: Thưởng Thức Âm Thanh
1. Mở app **PC Speaker** trên iPhone:
   - **Cách 1**: Bấm nút **"Auto Connect to PC (Wi-Fi)"** ➔ Ứng dụng sẽ tự động bắt sóng máy tính và kết nối trong vòng 1 giây.
   - **Cách 2**: Bấm **"Scan QR"** ➔ Hướng camera vào mã QR trên cửa sổ máy tính.
   - **Cách 3**: Bấm **"Nhập IP"** nếu muốn kết nối thủ công.
2. Khi kết nối thành công:
   - Thẻ trạng thái chuyển sang màu xanh lá **"Connected"**.
   - Thanh **Input Level** sẽ chuyển động sống động theo bài hát/video đang phát trên máy tính.
   - Đeo tai nghe hoặc bật loa ngoài để cảm nhận âm thanh trung thực không độ trễ.
   - Bạn có thể **khóa màn hình** hoặc **rời khỏi app**, âm thanh vẫn tiếp tục phát hoàn toàn bình thường.

---

## 🛠️ Khắc Phục Sự Cố (Troubleshooting)

| Tình huống | Nguyên nhân | Cách xử lý |
| :--- | :--- | :--- |
| **Đã kết nối nhưng không có tiếng** | Âm lượng iPhone đang ở mức 0% hoặc PC đang Mute | Bấm phím tăng âm lượng trên iPhone (app sẽ hiện cảnh báo màu đỏ nếu âm lượng = 0%) và kiểm tra loa trên máy tính. |
| **Không tìm thấy máy tính (Connection Failed)** | Tường lửa Windows chặn cổng 8080/8888 | Vào *Windows Defender Firewall* ➔ Cho phép ứng dụng Python chạy trên mạng *Private Network*. |
| **Âm thanh bị ngắt quãng hoặc giật** | Băng thông Wi-Fi yếu hoặc 2.4GHz bị nhiễu sóng | Kết nối cả iPhone và máy tính vào mạng Wi-Fi **5GHz** để đạt độ trễ ổn định nhất (< 20ms). |
