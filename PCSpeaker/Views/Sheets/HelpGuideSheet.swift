import SwiftUI

/// Setup Guide & Troubleshooting Sheet
public struct HelpGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Header Banner
                    HStack(spacing: 16) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hướng Dẫn Sử Dụng")
                                .font(.system(size: 20, weight: .bold))
                            Text("Biến iPhone thành loa máy tính trong 3 bước")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                    
                    // Step 1
                    guideStep(
                        step: "1",
                        title: "Khởi động PC Sender trên máy tính",
                        desc: "Mở thư mục pc-sender trên máy tính (Windows/Mac) và chạy lệnh:",
                        code: "python pc_sender.py"
                    )
                    
                    // Step 2
                    guideStep(
                        step: "2",
                        title: "Chung mạng Wi-Fi",
                        desc: "Đảm bảo cả iPhone và máy tính của bạn đều đang kết nối vào cùng một mạng Wi-Fi (khuyến nghị băng tần 5GHz để độ trễ thấp nhất < 20ms)."
                    )
                    
                    // Step 3
                    guideStep(
                        step: "3",
                        title: "Bấm 'Auto Connect' hoặc Quét QR",
                        desc: "Ứng dụng sẽ tự động dò tìm máy tính trên Wi-Fi qua giao thức UDP Beacon. Hoặc bạn có thể bấm 'Scan QR' để quét mã QR hiển thị trên màn hình PC."
                    )
                    
                    // Tips & FAQ Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mẹo & Khắc Phục Lỗi (Troubleshooting)")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.top, 8)
                        
                        faqItem(
                            question: "iPhone đã kết nối nhưng không nghe thấy tiếng?",
                            answer: "Kiểm tra thanh âm lượng media của iPhone (gạt nút gạt chuông nếu cần) và kiểm tra mixer âm thanh trên PC xem có đang bị Mute không."
                        )
                        
                        faqItem(
                            question: "Máy tính không tìm thấy / Báo lỗi kết nối?",
                            answer: "Kiểm tra tường lửa Windows Defender Firewall: hãy cấp quyền 'Allow on Private Networks' cho Python."
                        )
                        
                        faqItem(
                            question: "Ứng dụng có chạy khi khóa màn hình không?",
                            answer: "Có! Ứng dụng tích hợp AVAudioSession background mode, âm thanh vẫn phát mượt mà khi bạn tắt màn hình hoặc chuyển qua ứng dụng khác."
                        )
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                }
                .padding(20)
            }
            .navigationTitle("Trợ Giúp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func guideStep(
        step: String,
        title: String,
        desc: String,
        code: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(step)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(AppTheme.primary)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                if let code = code {
                    Text(code)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.primaryDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primaryLight)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("• " + question)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            Text(answer)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.leading, 12)
        }
    }
}
