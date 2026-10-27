import SwiftUI

/// 3-Column Real-Time Diagnostics Statistics Row: Frames | Data | Output
public struct StatsRowView: View {
    let frames: String
    let dataReceived: String
    let state: ConnectionState
    
    public init(frames: String, dataReceived: String, state: ConnectionState) {
        self.frames = frames
        self.dataReceived = dataReceived
        self.state = state
    }
    
    private var outputStatusText: String {
        switch state {
        case .connected:
            return "Playing"
        case .connecting:
            return "Connecting"
        case .searching:
            return "Searching"
        case .error:
            return "Error"
        case .idle, .disconnected:
            return "Idle"
        }
    }
    
    private var outputStatusColor: Color {
        switch state {
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
    
    public var body: some View {
        HStack(alignment: .top) {
            // Col 1: Frames
            VStack(alignment: .leading, spacing: 3) {
                Text("Frames")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Text(frames)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Col 2: Data
            VStack(alignment: .leading, spacing: 3) {
                Text("Data")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Text(dataReceived)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Col 3: Output
            VStack(alignment: .leading, spacing: 3) {
                Text("Output")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    if state == .connected {
                        Circle()
                            .fill(AppTheme.statusGreen)
                            .frame(width: 6, height: 6)
                    }
                    Text(outputStatusText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(outputStatusColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
