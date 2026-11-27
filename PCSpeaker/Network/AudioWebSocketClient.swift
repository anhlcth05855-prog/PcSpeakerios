import Foundation

/// Low-Latency Native WebSocket Client for PC Speaker Audio Stream
public final class AudioWebSocketClient: NSObject, URLSessionWebSocketDelegate {
    
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    
    private(set) var isConnected: Bool = false
    private var isIntentionalDisconnect: Bool = false
    
    public var totalBytesReceived: Int64 = 0
    public var totalFramesReceived: Int64 = 0
    
    public var onConnected: (() -> Void)?
    public var onDisconnected: (() -> Void)?
    public var onError: ((String) -> Void)?
    public var onAudioChunkReceived: ((Data) -> Void)?
    
    public override init() {
        super.init()
    }
    
    public func connect(to rawUrl: String) {
        disconnect()
        
        isIntentionalDisconnect = false
        totalBytesReceived = 0
        totalFramesReceived = 0
        
        let normalized = Self.normalizeUrl(rawUrl)
        guard let url = URL(string: normalized) else {
            onError?("Invalid WebSocket address: \(rawUrl)")
            return
        }
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 0 // Keep stream open indefinitely
        
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
        
        session = URLSession(configuration: config, delegate: self, delegateQueue: operationQueue)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Listen for the first message or open event
        receiveNext()
        startPingTimer()
        print("[AudioWebSocketClient] Connecting to \(normalized)...")
    }
    
    public func disconnect() {
        isIntentionalDisconnect = true
        stopPingTimer()
        
        if isConnected {
            webSocketTask?.cancel(with: .normalClosure, reason: "User disconnected".data(using: .utf8))
        } else {
            webSocketTask?.cancel()
        }
        
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        
        if isConnected {
            isConnected = false
            DispatchQueue.main.async { [weak self] in
                self?.onDisconnected?()
            }
        }
    }
    
    // MARK: - Recursive Receive Loop
    private func receiveNext() {
        guard let task = webSocketTask else { return }
        
        task.receive { [weak self] result in
            guard let self = self, !self.isIntentionalDisconnect else { return }
            
            switch result {
            case .success(let message):
                if !self.isConnected {
                    self.isConnected = true
                    DispatchQueue.main.async {
                        self.onConnected?()
                    }
                }
                
                switch message {
                case .data(let data):
                    let count = data.count
                    self.totalBytesReceived += Int64(count)
                    // Float32 stereo is 8 bytes per sample frame (4 bytes left + 4 bytes right)
                    self.totalFramesReceived += Int64(count / 8)
                    self.onAudioChunkReceived?(data)
                    
                case .string(let text):
                    // In case server sends a text ping or metadata
                    if text.contains("ping") {
                        self.sendPong()
                    }
                @unknown default:
                    break
                }
                
                // Immediately queue the next receive for continuous uninterrupted audio
                self.receiveNext()
                
            case .failure(let error):
                if !self.isIntentionalDisconnect {
                    print("[AudioWebSocketClient] Receive error: \(error.localizedDescription)")
                    self.isConnected = false
                    DispatchQueue.main.async {
                        self.onError?(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // MARK: - Keepalive Ping Timer
    private func startPingTimer() {
        stopPingTimer()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { error in
            if let error = error {
                print("[AudioWebSocketClient] Ping failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendPong() {
        let message = URLSessionWebSocketTask.Message.string("pong")
        webSocketTask?.send(message) { _ in }
    }
    
    // MARK: - URL Normalization
    public static func normalizeUrl(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("http://") {
            str = "ws://" + str.dropFirst(7)
        } else if str.hasPrefix("https://") {
            str = "wss://" + str.dropFirst(8)
        } else if !str.hasPrefix("ws://") && !str.hasPrefix("wss://") {
            str = "ws://" + str
        }
        
        // If port is missing, append standard :8080
        if let url = URL(string: str), url.port == nil {
            let host = url.host ?? ""
            if !host.isEmpty && !host.contains(":") {
                str = "\(str):8080"
            }
        }
        return str
    }
    
    // MARK: - URLSessionWebSocketDelegate
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolName: String?) {
        print("[AudioWebSocketClient] Connected successfully")
        self.isConnected = true
        DispatchQueue.main.async { [weak self] in
            self?.onConnected?()
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[AudioWebSocketClient] Closed with code: \(closeCode.rawValue)")
        self.isConnected = false
        if !isIntentionalDisconnect {
            DispatchQueue.main.async { [weak self] in
                self?.onDisconnected?()
            }
        }
    }
}
