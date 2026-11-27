import Foundation
import Combine
import UIKit

/// Central Orchestrator & View Model for PC Speaker iOS
@MainActor
public final class AudioReceiverService: ObservableObject {
    
    public static let shared = AudioReceiverService()
    
    // MARK: - Published State
    @Published public var stats = AudioStreamStats()
    @Published public var isSearching: Bool = false
    @Published public var discoveryStatusText: String = ""
    @Published public var discoveredPcs: [DiscoveredPc] = []
    @Published public var isDetailsExpanded: Bool = false
    
    // MARK: - Components
    public let audioPlayer: AudioStreamPlayer
    private var webSocketClient: AudioWebSocketClient?
    private let discoveryManager: NetworkDiscoveryManager
    private let nowPlayingManager = NowPlayingManager.shared
    
    private var statsTicker: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let prefSavedUrl = "saved_ws_url"
    private let prefSavedName = "saved_pc_name"
    
    public init() {
        self.audioPlayer = AudioStreamPlayer()
        self.discoveryManager = NetworkDiscoveryManager()
        
        setupDiscoveryCallbacks()
        setupNowPlayingCallbacks()
        bindAudioPlayer()
        startStatsTicker()
        
        // Auto-reconnect or discover on launch
        autoConnectOnLaunch()
    }
    
    deinit {
        statsTicker?.invalidate()
    }
    
    // MARK: - Setup
    private func setupDiscoveryCallbacks() {
        discoveryManager.onDeviceFound = { [weak self] pc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if !self.discoveredPcs.contains(where: { $0.wsUrl == pc.wsUrl }) {
                    self.discoveredPcs.append(pc)
                }
                
                self.discoveryStatusText = "Found: \(pc.name) (\(pc.ip)) • Connecting..."
                
                // If not already connected, connect to the discovered PC automatically
                if self.stats.state != .connected && self.stats.state != .connecting {
                    self.savePcInfo(url: pc.wsUrl, name: pc.name)
                    self.connect(url: pc.wsUrl, pcName: pc.name)
                }
            }
        }
    }
    
    private func setupNowPlayingCallbacks() {
        nowPlayingManager.onTogglePlayPause = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.stats.state.isConnected {
                    if self.audioPlayer.isPlaying {
                        self.audioPlayer.stop()
                    } else {
                        self.audioPlayer.start()
                    }
                    self.nowPlayingManager.updateNowPlaying(
                        pcName: self.stats.pcName,
                        isPlaying: self.audioPlayer.isPlaying
                    )
                }
            }
        }
    }
    
    private func bindAudioPlayer() {
        audioPlayer.$currentRmsLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                Task { @MainActor [weak self] in
                    self?.stats.currentRmsLevel = level
                }
            }
            .store(in: &cancellables)
            
        audioPlayer.$activeOutputRoute
            .receive(on: DispatchQueue.main)
            .sink { [weak self] route in
                Task { @MainActor [weak self] in
                    self?.stats.outputRoute = route
                }
            }
            .store(in: &cancellables)
            
        audioPlayer.$deviceVolumePercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vol in
                Task { @MainActor [weak self] in
                    self?.stats.deviceVolumePercent = vol
                }
            }
            .store(in: &cancellables)
    }
    
    private func autoConnectOnLaunch() {
        let savedUrl = UserDefaults.standard.string(forKey: prefSavedUrl) ?? ""
        let savedName = UserDefaults.standard.string(forKey: prefSavedName) ?? "PC Sender"
        
        if !savedUrl.isEmpty {
            discoveryStatusText = "Reconnecting to: \(savedName)..."
            connect(url: savedUrl, pcName: savedName)
        } else {
            startAutoDiscovery()
        }
    }
    
    // MARK: - Connections
    public func connect(url: String, pcName: String = "PC Sender") {
        let normalized = AudioWebSocketClient.normalizeUrl(url)
        stopAutoDiscovery()
        
        stats.state = .connecting
        stats.serverUrl = normalized
        stats.pcName = pcName
        stats.errorMessage = nil
        stats.totalFrames = 0
        stats.totalBytesReceived = 0
        
        savePcInfo(url: normalized, name: pcName)
        
        let client = AudioWebSocketClient()
        
        client.onConnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.audioPlayer.start()
                self.stats.state = .connected
                self.stats.isPlaying = true
                self.discoveryStatusText = ""
                
                // Record in history
                let ip = normalized.replacingOccurrences(of: "ws://", with: "").replacingOccurrences(of: "wss://", with: "")
                ConnectionHistoryManager.record(pcName: pcName, ip: ip, wsUrl: normalized)
                
                // Update Lock Screen player
                self.nowPlayingManager.updateNowPlaying(pcName: pcName, isPlaying: true)
                
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        }
        
        client.onDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.audioPlayer.stop()
                self.stats.state = .disconnected
                self.stats.isPlaying = false
                self.stats.currentRmsLevel = 0.0
                self.nowPlayingManager.clearNowPlaying()
            }
        }
        
        client.onError = { [weak self] errMsg in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.audioPlayer.stop()
                self.stats.state = .error(errMsg)
                self.stats.errorMessage = errMsg
                self.stats.isPlaying = false
                self.stats.currentRmsLevel = 0.0
                self.nowPlayingManager.clearNowPlaying()
                
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }
        }
        
        let player = self.audioPlayer
        client.onAudioChunkReceived = { [weak player] data in
            player?.writePcmData(data)
        }
        
        self.webSocketClient = client
        client.connect(to: normalized)
    }
    
    public func disconnect() {
        webSocketClient?.disconnect()
        webSocketClient = nil
        audioPlayer.stop()
        
        stats.state = .idle
        stats.isPlaying = false
        stats.currentRmsLevel = 0.0
        nowPlayingManager.clearNowPlaying()
        
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }
    
    // MARK: - Auto-Discovery
    public func startAutoDiscovery() {
        guard stats.state != .connected && stats.state != .connecting else { return }
        isSearching = true
        stats.state = .searching
        discoveryStatusText = "Searching for PC on local Wi-Fi..."
        discoveredPcs.removeAll()
        discoveryManager.startDiscovery()
    }
    
    public func stopAutoDiscovery() {
        isSearching = false
        discoveryManager.stopDiscovery()
    }
    
    // MARK: - Playback Gain Control
    public func increaseGain() {
        let current = audioPlayer.playbackGain
        let updated = min(3.0, current + 0.1)
        audioPlayer.playbackGain = updated
        stats.playbackGain = updated
        
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    public func decreaseGain() {
        let current = audioPlayer.playbackGain
        let updated = max(0.1, current - 0.1)
        audioPlayer.playbackGain = updated
        stats.playbackGain = updated
        
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    // MARK: - Persistence & Stats Ticker
    private func savePcInfo(url: String, name: String) {
        UserDefaults.standard.set(url, forKey: prefSavedUrl)
        UserDefaults.standard.set(name, forKey: prefSavedName)
    }
    
    private func startStatsTicker() {
        statsTicker?.invalidate()
        // 20 updates per second for smooth meters and real-time statistics
        statsTicker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let client = self.webSocketClient {
                    self.stats.totalBytesReceived = client.totalBytesReceived
                    self.stats.totalFrames = client.totalFramesReceived
                }
                self.stats.isPlaying = self.audioPlayer.isPlaying
                self.audioPlayer.updateDeviceVolume()
            }
        }
    }
}
