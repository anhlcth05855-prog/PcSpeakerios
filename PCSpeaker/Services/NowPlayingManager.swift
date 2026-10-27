import Foundation
import MediaPlayer
import UIKit

/// Manages Lock Screen, Dynamic Island & Control Center Now Playing information and remote media controls
public final class NowPlayingManager {
    
    public static let shared = NowPlayingManager()
    
    public var onTogglePlayPause: (() -> Void)?
    
    private init() {
        setupRemoteCommands()
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPause?()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPause?()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPause?()
            return .success
        }
    }
    
    public func updateNowPlaying(pcName: String, isPlaying: Bool) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = "PC Speaker"
        info[MPMediaItemPropertyArtist] = pcName.isEmpty ? "PC Audio Stream" : pcName
        info[MPMediaItemPropertyAlbumTitle] = "Wi-Fi High-Fidelity Audio (48kHz)"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Render simple speaker icon for lock screen
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let img = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: 300, height: 300)
            UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).setFill()
            ctx.cgContext.fillEllipse(in: rect)
            
            if let speakerIcon = UIImage(systemName: "speaker.wave.3.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let iconRect = CGRect(x: 60, y: 60, width: 180, height: 180)
                speakerIcon.draw(in: iconRect)
            }
        }
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    public func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
