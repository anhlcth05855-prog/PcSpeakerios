import SwiftUI

/// Manual IP & Port Entry Sheet
public struct ManualIPSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConnect: (String, String) -> Void
    
    @State private var ipText: String = ""
    @State private var pcName: String = "My PC"
    
    public init(initialIp: String = "", onConnect: @escaping (String, String) -> Void) {
        self.onConnect = onConnect
        let saved = UserDefaults.standard.string(forKey: "saved_ws_url")?
            .replacingOccurrences(of: "ws://", with: "")
            .replacingOccurrences(of: "wss://", with: "") ?? ""
        _ipText = State(initialValue: initialIp.isEmpty ? (saved.isEmpty ? "192.168.1." : saved) : initialIp)
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryLight)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "network")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                }
                .padding(.top, 16)
                
                VStack(spacing: 6) {
                    Text("Nhập Địa Chỉ IP Máy Tính")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Nhập địa chỉ IPv4 hiển thị trên cửa sổ lệnh pc_sender.py của máy tính.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Form Card
                VStack(spacing: 16) {
                    // IP Address Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Địa chỉ IP & Cổng")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .foregroundColor(.secondary)
                            
                            TextField("Ví dụ: 192.168.1.15:8080", text: $ipText)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .keyboardType(.numbersAndPunctuation)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if !ipText.contains(":8080") && !ipText.contains(":") {
                                Button("+ :8080") {
                                    ipText += ":8080"
                                }
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.primaryLight)
                                .foregroundColor(AppTheme.primary)
                                .cornerRadius(6)
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.96))
                        .cornerRadius(12)
                    }
                    
                    // PC Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tên gợi nhớ máy tính")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.secondary)
                            
                            TextField("Ví dụ: Laptop Gaming, PC Bàn", text: $pcName)
                                .font(.system(size: 15))
                        }
                        .padding(12)
                        .background(Color(white: 0.96))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Connect Action Button
                Button {
                    let trimmed = ipText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    dismiss()
                    onConnect(trimmed, pcName.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    Text("Kết nối ngay")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(ipText.isEmpty ? Color.gray : AppTheme.primary)
                        .cornerRadius(14)
                }
                .disabled(ipText.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
        }
    }
}
