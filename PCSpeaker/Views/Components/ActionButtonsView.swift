import SwiftUI
import UIKit

/// Action Buttons: Auto Connect, Scan QR, Manual IP, Bluetooth/Cable, History, and Cancel/Disconnect
public struct ActionButtonsView: View {
    @ObservedObject var service: AudioReceiverService
    
    @Binding var showQRScanner: Bool
    @Binding var showManualIP: Bool
    @Binding var showBluetooth: Bool
    @Binding var showHistory: Bool
    
    public init(
        service: AudioReceiverService,
        showQRScanner: Binding<Bool>,
        showManualIP: Binding<Bool>,
        showBluetooth: Binding<Bool>,
        showHistory: Binding<Bool>
    ) {
        self.service = service
        self._showQRScanner = showQRScanner
        self._showManualIP = showManualIP
        self._showBluetooth = showBluetooth
        self._showHistory = showHistory
    }
    
    private var isConnected: Bool {
        service.stats.state == .connected
    }
    
    private var isConnectingOrSearching: Bool {
        service.stats.state == .connecting || service.isSearching
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            if isConnected {
                // Connected State: Disconnect Button
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
                    .frame(height: 50)
                    .background(Color(red: 1.0, green: 0.94, blue: 0.94))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.statusRed.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else if isConnectingOrSearching {
                // Connecting / Searching State: Cancel Button
                Button {
                    service.stopAutoDiscovery()
                    service.disconnect()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Cancel Connection")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(AppTheme.statusRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 1.0, green: 0.94, blue: 0.94))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.statusRed.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Discovery Indicator & Status Text
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text(service.discoveryStatusText.isEmpty ? "Connecting to PC..." : service.discoveryStatusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            } else {
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
            }
            
            // 4 Grid Action Buttons: Scan QR | Manual IP | Bluetooth & Cable | History
            VStack(spacing: 8) {
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
                        .frame(height: 44)
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
                            Text("Manual IP")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 8) {
                    // Button 3: Bluetooth & Cable
                    Button {
                        showBluetooth = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wave.3.right.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Bluetooth / Cable")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Button 4: History
                    Button {
                        showHistory = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                            Text("History")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
