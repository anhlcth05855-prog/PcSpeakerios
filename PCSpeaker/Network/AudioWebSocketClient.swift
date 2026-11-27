import Foundation

/// Low-Latency Native WebSocket Client for PC Speaker Audio Stream
public final class AudioWebSocketClient: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate {
    
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var timeoutTimer: Timer?
    
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
        config.waitsForConnectivity = false
        config.networkServiceType = .voice // Prioritizes real-time low-latency packet delivery
        config.timeoutIntervalForRequest = 7.0
        config.timeoutIntervalForResource = 0 // Keep stream open indefinitely
        
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
        
        session = URLSession(configuration: config, delegate: self, delegateQueue: operationQueue)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start 7-second handshake timeout
        startTimeoutTimer(for: normalized)
        
        // Listen for the first message or open event
        receiveNext()
        startPingTimer()
        print("[AudioWebSocketClient] Connecting to \(normalized)...")
    }
    
    public func disconnect() {
        isIntentionalDisconnect = true
        stopTimeoutTimer()
        stopPingTimer()
        
        // Sever callback references immediately to prevent any late audio packets
        onAudioChunkReceived = nil
        
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
            let disconnectCb = onDisconnected
            onDisconnected = nil
            onError = nil
            onConnected = nil
            DispatchQueue.main.async {
                disconnectCb?()
            }
        } else {
            onDisconnected = nil
            onError = nil
            onConnected = nil
        }
    }
    
    // MARK: - Connection Timeout
    private func startTimeoutTimer(for urlString: String) {
        stopTimeoutTimer()
        DispatchQueue.main.async { [weak self] in
            self?.timeoutTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self] _ in
                guard let self = self, !self.isConnected, !self.isIntentionalDisconnect else { return }
                print("[AudioWebSocketClient] Connection timed out after 7s to \(urlString)")
                let errorCb = self.onError
                self.disconnect()
                DispatchQueue.main.async {
                    errorCb?("Connection timed out. Could not reach \(urlString). Please ensure PC Sender is running, Windows Firewall allows port 8080, and both devices are on the same Wi-Fi.")
                }
            }
        }
    }
    
    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    // MARK: - Recursive Receive Loop
    private func receiveNext() {
        guard let task = webSocketTask, !isIntentionalDisconnect else { return }
        
        task.receive { [weak self] result in
            guard let self = self, !self.isIntentionalDisconnect else { return }
            
            switch result {
            case .success(let message):
                self.stopTimeoutTimer()
                if !self.isConnected {
                    self.isConnected = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, !self.isIntentionalDisconnect else { return }
                        self.onConnected?()
                    }
                }
                
                switch message {
                case .data(let data):
                    guard !self.isIntentionalDisconnect else { return }
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
                if !self.isIntentionalDisconnect {
                    self.receiveNext()
                }
                
            case .failure(let error):
                if !self.isIntentionalDisconnect {
                    print("[AudioWebSocketClient] Receive error: \(error.localizedDescription)")
                    self.isConnected = false
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, !self.isIntentionalDisconnect else { return }
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
        guard !isIntentionalDisconnect else { return }
        webSocketTask?.sendPing { error in
            if let error = error {
                print("[AudioWebSocketClient] Ping failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendPong() {
        guard !isIntentionalDisconnect else { return }
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
    
    // MARK: - URLSessionWebSocketDelegate & TaskDelegate
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolName: String?) {
        guard !isIntentionalDisconnect else { return }
        print("[AudioWebSocketClient] Connected successfully")
        stopTimeoutTimer()
        self.isConnected = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isIntentionalDisconnect else { return }
            self.onConnected?()
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        stopTimeoutTimer()
        self.isConnected = false
        if !isIntentionalDisconnect {
            DispatchQueue.main.async { [weak self] in
                self?.onDisconnected?()
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        stopTimeoutTimer()
        if !isIntentionalDisconnect, let error = error {
            print("[AudioWebSocketClient] Task completed with error: \(error.localizedDescription)")
            self.isConnected = false
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isIntentionalDisconnect else { return }
                self.onError?("Connection failed: \(error.localizedDescription). Please verify PC Sender is running.")
            }
        }
    }
}
