import SwiftUI

/// Connection History Sheet displaying past connected computers
public struct HistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String, String) -> Void
    
    @State private var history: [ConnectionHistoryItem] = []
    @State private var showClearConfirm: Bool = false
    
    public init(onSelect: @escaping (String, String) -> Void) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationView {
            Group {
                if history.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("Chưa Có Lịch Sử Kết Nối")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Các máy tính bạn đã kết nối sẽ tự động lưu lại tại đây để kết nối nhanh trong những lần sau.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(history) { item in
                            HStack(spacing: 14) {
                                // PC Icon
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.primaryLight)
                                        .frame(width: 42, height: 42)
                                    
                                    Image(systemName: "desktopcomputer")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(AppTheme.primary)
                                }
                                
                                // Texts
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.pcName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text(item.ip)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    
                                    Text(item.connectedAtStr)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.6))
                                }
                                
                                Spacer()
                                
                                // Connect Button
                                Button {
                                    dismiss()
                                    onSelect(item.wsUrl, item.pcName)
                                } label: {
                                    Text("Kết nối")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteItem)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Lịch Sử Kết Nối")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
                
                if !history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Xóa tất cả") {
                            showClearConfirm = true
                        }
                        .foregroundColor(AppTheme.statusRed)
                    }
                }
            }
            .alert("Xóa toàn bộ lịch sử?", isPresented: $showClearConfirm) {
                Button("Xóa tất cả", role: .destructive) {
                    ConnectionHistoryManager.clearAll()
                    history.removeAll()
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Hành động này sẽ xóa toàn bộ danh sách máy tính đã lưu.")
            }
            .onAppear {
                self.history = ConnectionHistoryManager.loadAll()
            }
        }
    }
    
    private func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            let item = history[index]
            ConnectionHistoryManager.delete(wsUrl: item.wsUrl)
        }
        history.remove(atOffsets: offsets)
    }
}
