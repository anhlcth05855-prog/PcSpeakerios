import SwiftUI

/// Action Buttons: Auto Connect, Scan QR, Manual IP, History, and Disconnect
public struct ActionButtonsView: View {
    @ObservedObject var service: AudioReceiverService
    
    @Binding var showQRScanner: Bool
    @Binding var showManualIP: Bool
    @Binding var showHistory: Bool
    
    public init(
        service: AudioReceiverService,
        showQRScanner: Binding<Bool>,
        showManualIP: Binding<Bool>,
        showHistory: Binding<Bool>
    ) {
        self.service = service
        self._showQRScanner = showQRScanner
        self._showManualIP = showManualIP
        self._showHistory = showHistory
    }
    
    private var isConnected: Bool {
        service.stats.state == .connected
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            if !isConnected {
                // Primary Action Button: Auto Connect
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    service.startAutoDiscovery()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Auto Connect to PC (Wi-Fi)")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppTheme.primaryButtonGradient)
                    .cornerRadius(14)
                    .shadow(color: AppTheme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
                // Discovery Indicator & Status Text
                if service.isSearching || !service.discoveryStatusText.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text(service.discoveryStatusText.isEmpty ? "Searching for PC on local Wi-Fi..." : service.discoveryStatusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }
                
                // Secondary 3-Button Action Row: Scan QR | Nhập IP | Lịch sử
                HStack(spacing: 8) {
                    // Button 1: Scan QR
                    Button {
                        showQRScanner = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Scan QR")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Button 2: Manual IP
                    Button {
                        showManualIP = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "network")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Nhập IP")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Button 3: History
                    Button {
                        showHistory = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Lịch sử")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Connected State: Prominent Disconnect Action
                Button {
                    service.disconnect()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Disconnect")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(AppTheme.statusRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(red: 1.0, green: 0.94, blue: 0.94))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.statusRed.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
