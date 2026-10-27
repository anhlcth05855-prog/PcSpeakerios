import Foundation

public enum ConnectionState: Equatable {
    case idle
    case searching
    case connecting
    case connected
    case disconnected
    case error(String)
    
    public var isConnected: Bool {
        self == .connected
    }
}

public struct AudioStreamStats: Equatable {
    public var state: ConnectionState = .idle
    public var serverUrl: String = ""
    public var pcName: String = "PC Sender"
    public var totalFrames: Int64 = 0
    public var totalBytesReceived: Int64 = 0
    public var currentRmsLevel: Float = 0.0
    public var outputRoute: String = "iPhone Speaker"
    public var deviceVolumePercent: Int = 80
    public var playbackGain: Float = 1.0
    public var isPlaying: Bool = false
    public var errorMessage: String? = nil
    
    public init() {}
    
    public var formattedFrames: String {
        if totalFrames >= 1_000_000 {
            return String(format: "%.1fM", Double(totalFrames) / 1_000_000.0)
        } else if totalFrames >= 1_000 {
            return String(format: "%.1fK", Double(totalFrames) / 1_000.0)
        } else {
            return "\(totalFrames)"
        }
    }
    
    public var formattedDataReceived: String {
        let bytes = Double(totalBytesReceived)
        if bytes >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
        } else if bytes >= 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else if bytes >= 1024 {
            return String(format: "%.0f KB", bytes / 1024)
        } else {
            return "\(totalBytesReceived) B"
        }
    }
}

public struct DiscoveredPc: Identifiable, Hashable {
    public var id: String { wsUrl }
    public let name: String
    public let ip: String
    public let port: Int
    public let wsUrl: String
    
    public init(name: String, ip: String, port: Int, wsUrl: String) {
        self.name = name
        self.ip = ip
        self.port = port
        self.wsUrl = wsUrl
    }
}

public struct ConnectionHistoryItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public let pcName: String
    public let ip: String
    public let wsUrl: String
    public let connectedAt: Date
    public let connectedAtStr: String
    
    public init(pcName: String, ip: String, wsUrl: String, connectedAt: Date = Date(), connectedAtStr: String = "") {
        self.pcName = pcName
        self.ip = ip
        self.wsUrl = wsUrl
        self.connectedAt = connectedAt
        if connectedAtStr.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            self.connectedAtStr = formatter.string(from: connectedAt)
        } else {
            self.connectedAtStr = connectedAtStr
        }
    }
}
