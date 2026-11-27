import SwiftUI
import AVKit
import CoreBluetooth

/// UIKit wrapper for Apple's native AVRoutePickerView (Bluetooth & AirPlay output picker)
public struct RoutePickerViewRepresentable: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.backgroundColor = .clear
        routePicker.tintColor = UIColor(AppTheme.primary)
        routePicker.activeTintColor = UIColor(AppTheme.statusGreen)
        routePicker.prioritizesVideoDevices = false
        return routePicker
    }
    
    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Bluetooth Connection & Audio Route Management Sheet
public struct BluetoothSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var btManager = BluetoothManager.shared
    
    // Dynamic saved PC or last connected address
    private var lastKnownPcName: String {
        let name = UserDefaults.standard.string(forKey: "saved_pc_name") ?? ""
        return name.isEmpty ? "Paired Computer" : name
    }
    
    private var lastKnownUrl: String {
        UserDefaults.standard.string(forKey: "saved_ws_url") ?? ""
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primaryLight)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(AppTheme.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bluetooth & Cable Connection")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Direct ultra-low latency connection without Wi-Fi")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                    
                    // Direct Connect to Saved PC Card
                    if !lastKnownUrl.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.primaryLight)
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "desktopcomputer")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(AppTheme.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Connect to \(lastKnownPcName)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text(lastKnownUrl.replacingOccurrences(of: "ws://", with: "").replacingOccurrences(of: "wss://", with: ""))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    dismiss()
                                    AudioReceiverService.shared.connect(url: lastKnownUrl, pcName: lastKnownPcName)
                                } label: {
                                    Text("Connect")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .glassCard(cornerRadius: 16)
                    }
                    
                    // Route Picker Card (Bluetooth / AirPlay output)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Audio Output Route")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Switch output to AirPods, Bluetooth speakers, or headphones")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            RoutePickerViewRepresentable()
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                    
                    // Bluetooth Scanner Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nearby Bluetooth Peripherals")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text(btManager.statusMessage)
                                    .font(.system(size: 12))
                                    .foregroundColor(btManager.isPoweredOn ? .secondary : AppTheme.statusRed)
                            }
                            
                            Spacer()
                            
                            if btManager.isScanning {
                                Button("Stop") {
                                    btManager.stopScanning()
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.statusRed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                Button("Scan") {
                                    btManager.startScanning()
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(AppTheme.primaryLight)
                                .cornerRadius(8)
                            }
                        }
                        
                        Text("Note: Windows PCs act as Bluetooth Central hosts and pair in iOS Settings → Bluetooth. Use the connection modes below to link audio with your laptop.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        if btManager.discoveredDevices.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "wave.3.right")
                                        .font(.system(size: 28))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text(btManager.isScanning ? "Scanning for peripherals..." : "Tap 'Scan' to discover nearby Bluetooth devices")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 16)
                                Spacer()
                            }
                        } else {
                            VStack(spacing: 8) {
                                ForEach(btManager.discoveredDevices) { device in
                                    HStack {
                                        Image(systemName: "wave.3.right.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppTheme.primary)
                                            .frame(width: 32, height: 32)
                                            .background(AppTheme.primaryLight)
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(device.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text("Signal: \(device.rssi) dBm")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            btManager.connect(to: device)
                                        } label: {
                                            Text("Pair")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(AppTheme.primary)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                    
                    // Direct 0-Wi-Fi Guide
                    VStack(alignment: .leading, spacing: 14) {
                        Text("How to Connect via Bluetooth / USB Cable")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Method 1: Bluetooth Tethering (PAN)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "personalhotspot")
                                    .foregroundColor(AppTheme.primary)
                                Text("Option 1: Bluetooth Personal Area Network (PAN)")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text("1. On iPhone: Settings → Personal Hotspot → Allow Others to Join (Bluetooth).\n2. On PC: Windows Settings → Bluetooth → Devices & Printers → Right-click iPhone → Connect using → Access Point.\n3. Run pc_sender.py and tap 'Connect Now' above for ~10ms latency!")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color(white: 0.96))
                        .cornerRadius(10)
                        
                        // Method 2: Lightning / USB-C Cable
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "cable.connector")
                                    .foregroundColor(AppTheme.statusGreen)
                                Text("Option 2: USB Cable Direct Tethering (< 5ms)")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text("1. Connect iPhone to PC via USB cable.\n2. Turn on Personal Hotspot (USB Only).\n3. Run pc_sender.py and tap 'Connect Now' above for ultra-fast, zero-lag sound.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color(white: 0.96))
                        .cornerRadius(10)
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                }
                .padding(20)
            }
            .navigationTitle("Bluetooth & Cable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        btManager.stopScanning()
                        dismiss()
                    }
                }
            }
        }
    }
}
