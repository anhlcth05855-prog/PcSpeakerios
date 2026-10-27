import SwiftUI

/// Main Status Card displaying Connection Badge, Diagnostics, Live VU Meter, and Counters
public struct StatusHeaderCard: View {
    @ObservedObject var service: AudioReceiverService
    
    public init(service: AudioReceiverService) {
        self.service = service
    }
    
    private var stats: AudioStreamStats {
        service.stats
    }
    
    // Status Icon
    private var iconName: String {
        switch stats.state {
        case .connected:
            return "speaker.wave.3.fill"
        case .connecting, .searching:
            return "antenna.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle.fill"
        case .idle, .disconnected:
            return "speaker.slash.fill"
        }
    }
    
    private var iconColor: Color {
        switch stats.state {
        case .connected:
            return AppTheme.statusGreen
        case .connecting, .searching:
            return AppTheme.primary
        case .error:
            return AppTheme.statusRed
        case .idle, .disconnected:
            return AppTheme.statusGray
        }
    }
    
    private var iconBgColor: Color {
        switch stats.state {
        case .connected:
            return AppTheme.statusGreenBg
        case .connecting, .searching:
            return AppTheme.primaryLight
        case .error:
            return Color(red: 1.0, green: 0.93, blue: 0.93)
        case .idle, .disconnected:
            return Color(white: 0.94)
        }
    }
    
    // Status Title
    private var statusTitle: String {
        switch stats.state {
        case .connected:
            return "Connected (\(stats.pcName))"
        case .connecting:
            return "Connecting..."
        case .searching:
            return "Searching for PC..."
        case .error:
            return "Connection Failed"
        case .idle, .disconnected:
            return "Ready to Connect"
        }
    }
    
    // Status Description
    private var statusDesc: String {
        switch stats.state {
        case .connected:
            if stats.deviceVolumePercent == 0 {
                return "⚠️ Âm lượng iPhone đang là 0%! Hãy bấm phím tăng âm lượng."
            } else if stats.totalFrames > 150 && stats.currentRmsLevel < 0.001 {
                return "⚠️ Đang kết nối nhưng máy tính chưa phát âm thanh (hoặc PC đang Mute)."
            } else {
                return "Receiving 48kHz audio and playing it on this iPhone."
            }
        case .connecting:
            return "Connecting to \(stats.serverUrl)..."
        case .searching:
            return "Looking for PC Speaker running on local Wi-Fi..."
        case .error(let msg):
            return msg.isEmpty ? "Could not reach PC Sender. Make sure firewall allows port 8080." : msg
        case .idle, .disconnected:
            return "Tap Auto Connect or scan QR code from PC Sender to start playback."
        }
    }
    
    private var statusDescColor: Color {
        if stats.state == .connected && stats.deviceVolumePercent == 0 {
            return AppTheme.statusRed
        }
        if stats.state == .connected && stats.totalFrames > 150 && stats.currentRmsLevel < 0.001 {
            return AppTheme.statusAmber
        }
        return .secondary
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Info Row
            HStack(spacing: 14) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBgColor)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                // Texts
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(statusDesc)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(statusDescColor)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Input Level (VU Meter)
            VUMeterView(level: stats.currentRmsLevel)
            
            // Divider
            Divider()
                .padding(.vertical, 2)
            
            // Stats Row: Frames | Data | Output
            StatsRowView(
                frames: stats.formattedFrames,
                dataReceived: stats.formattedDataReceived,
                state: stats.state
            )
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }
}
