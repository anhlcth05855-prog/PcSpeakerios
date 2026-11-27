import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// High-Fidelity, Ultra-Low-Latency Audio Streaming Player for iOS
/// Receives 48,000 Hz Float32 stereo PCM audio and renders it via AVAudioEngine + AVAudioSourceNode.
public final class AudioStreamPlayer: ObservableObject {
    
    private let sampleRate: Double = 48000.0
    private let channels: AVAudioChannelCount = 2
    
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private let ringBuffer: LockFreeRingBuffer
    
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentRmsLevel: Float = 0.0
    @Published public private(set) var activeOutputRoute: String = "iPhone Speaker"
    @Published public private(set) var deviceVolumePercent: Int = 80
    @Published public var playbackGain: Float = 1.0
    
    private var smoothedRms: Float = 0.0
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.ringBuffer = LockFreeRingBuffer(capacityFrames: 48000)
        setupAudioSession()
        setupNotificationObservers()
        updateOutputRoute()
        updateDeviceVolume()
    }
    
    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
            )
            try session.setPreferredSampleRate(sampleRate)
            // Request 5ms hardware I/O buffer for ultra-low latency response (< 25ms total roundtrip)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true, options: [])
        } catch {
            print("[AudioStreamPlayer] Error configuring AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notifications (Route Changes & Interruptions)
    private func setupNotificationObservers() {
        // Route changes (e.g. AirPods connected, unplugged headphones, bluetooth car)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateOutputRoute()
        }
        
        // Audio interruptions (phone call, alarm, Siri)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            if type == .began {
                self?.stop()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.start()
                    }
                }
            }
        }
    }
    
    // MARK: - Audio Engine Initialization
    private func setupEngine() {
        let engine = AVAudioEngine()
        
        // Native non-interleaved Float32 format for AVAudioEngine rendering
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            print("[AudioStreamPlayer] Failed to create AVAudioFormat")
            return
        }
        
        let node = AVAudioSourceNode(format: format) { [weak self] isSilence, timestamp, frameCount, audioBufferList -> OSStatus in
            guard let self = self else {
                isSilence.pointee = true
                return noErr
            }
            
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightPtr = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
                isSilence.pointee = true
                return noErr
            }
            
            let framesNeeded = Int(frameCount)
            let framesRead = self.ringBuffer.read(leftOut: leftPtr, rightOut: rightPtr, count: framesNeeded)
            
            if framesRead < framesNeeded {
                // Pad underrun frames with silence to prevent pops or digital clicks
                for i in framesRead..<framesNeeded {
                    leftPtr[i] = 0.0
                    rightPtr[i] = 0.0
                }
            }
            
            isSilence.pointee = ObjCBool(framesRead == 0)
            return noErr
        }
        
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        
        self.audioEngine = engine
        self.sourceNode = node
    }
    
    // MARK: - Playback Control
    public func start() {
        guard !isPlaying else { return }
        
        setupAudioSession()
        
        if audioEngine == nil {
            setupEngine()
        }
        
        do {
            try audioEngine?.start()
            isPlaying = true
            updateOutputRoute()
            updateDeviceVolume()
            print("[AudioStreamPlayer] AVAudioEngine started successfully")
        } catch {
            print("[AudioStreamPlayer] Error starting engine: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        guard isPlaying else { return }
        
        audioEngine?.stop()
        audioEngine?.reset()
        audioEngine = nil
        sourceNode = nil
        
        ringBuffer.clear()
        isPlaying = false
        currentRmsLevel = 0.0
        smoothedRms = 0.0
        print("[AudioStreamPlayer] Playback stopped and buffer cleared")
    }
    
    // MARK: - Incoming PCM Data Processing
    /// Writes binary Float32 Little-Endian stereo PCM chunks from WebSocket
    public func writePcmData(_ data: Data) {
        if !isPlaying {
            start()
        }
        
        let count = data.count
        guard count >= 8 else { return }
        
        let totalFloats = count / MemoryLayout<Float>.size
        let frameCount = totalFloats / 2
        guard frameCount > 0 else { return }
        
        var sumSquares: Float = 0.0
        let gain = self.playbackGain
        
        data.withUnsafeBytes { rawBuffer in
            guard let floatPtr = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            self.ringBuffer.writeInterleaved(
                floatPtr,
                frameCount: frameCount,
                gain: gain,
                sumSquaresOut: &sumSquares
            )
        }
        
        // Calculate root-mean-square (RMS) for real-time VU meter
        let rawRms = sqrt(sumSquares / Float(totalFloats))
        if rawRms > smoothedRms {
            smoothedRms = rawRms
        } else {
            // Smooth decay for aesthetically pleasing VU meter physics
            smoothedRms = (smoothedRms * 0.85) + (rawRms * 0.15)
        }
        
        let level = min(1.0, max(0.0, smoothedRms))
        DispatchQueue.main.async { [weak self] in
            self?.currentRmsLevel = level
        }
    }
    
    // MARK: - Device Route & Volume Helpers
    public func updateOutputRoute() {
        let session = AVAudioSession.sharedInstance()
        var routeName = "iPhone Speaker"
        
        for output in session.currentRoute.outputs {
            switch output.portType {
            case .builtInSpeaker:
                routeName = "iPhone Speaker"
            case .builtInReceiver:
                routeName = "Ear Speaker"
            case .headphones:
                routeName = "Wired Headphones"
            case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
                routeName = output.portName.isEmpty ? "Bluetooth Device" : output.portName
            case .airPlay:
                routeName = "AirPlay (\(output.portName))"
            default:
                if !output.portName.isEmpty {
                    routeName = output.portName
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.activeOutputRoute = routeName
        }
    }
    
    public func updateDeviceVolume() {
        let volume = AVAudioSession.sharedInstance().outputVolume
        let percent = Int(round(volume * 100))
        DispatchQueue.main.async { [weak self] in
            self?.deviceVolumePercent = percent
        }
    }
}
