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
                        
                        Text("No Connection History")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Computers you have connected to will be saved here for quick one-tap reconnection.")
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
                                    Text("Connect")
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
            .navigationTitle("Connection History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if !history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            showClearConfirm = true
                        }
                        .foregroundColor(AppTheme.statusRed)
                    }
                }
            }
            .alert("Clear Connection History?", isPresented: $showClearConfirm) {
                Button("Clear All", role: .destructive) {
                    ConnectionHistoryManager.clearAll()
                    history.removeAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all saved computers from your connection history.")
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
