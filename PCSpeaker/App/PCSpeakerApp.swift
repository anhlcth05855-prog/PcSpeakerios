import SwiftUI
import AVFoundation

@main
struct PCSpeakerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var service = AudioReceiverService.shared
    
    init() {
        // Prepare audio session on application launch
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[PCSpeakerApp] AVAudioSession init notice: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(service)
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        // Refresh device volume and route when coming to foreground
                        service.audioPlayer.updateOutputRoute()
                        service.audioPlayer.updateDeviceVolume()
                    case .background:
                        // Background audio continues running uninterrupted via AVAudioSession .playback category
                        break
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
