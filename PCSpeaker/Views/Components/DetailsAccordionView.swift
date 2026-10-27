import SwiftUI

/// Collapsible Diagnostics & Audio Fine-Tuning Card
public struct DetailsAccordionView: View {
    @ObservedObject var service: AudioReceiverService
    
    public init(service: AudioReceiverService) {
        self.service = service
    }
    
    private var stats: AudioStreamStats {
        service.stats
    }
    
    // Output Route Icon
    private var routeIconName: String {
        let route = stats.outputRoute.lowercased()
        if route.contains("airpod") {
            return "airpodspro"
        } else if route.contains("headphone") || route.contains("headset") {
            return "headphones"
        } else if route.contains("bluetooth") {
            return "wave.3.right.circle.fill"
        } else if route.contains("airplay") {
            return "airplayaudio"
        } else {
            return "iphone"
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Accordion Toggle Header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    service.isDetailsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Details")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: service.isDetailsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if service.isDetailsExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.bottom, 4)
                    
                    // Row 1: Audio Engine
                    detailRow(
                        title: "Audio Engine",
                        value: "AVAudioEngine (Float32 PCM)",
                        isBold: true
                    )
                    
                    // Row 2: Player Status
                    detailRow(
                        title: "Player",
                        value: stats.isPlaying ? "Playing (Low-Latency)" : "Idle",
                        valueColor: stats.isPlaying ? AppTheme.statusGreen : .primary,
                        isBold: true
                    )
                    
                    // Row 3: Audio Format
                    detailRow(
                        title: "Format",
                        value: "48,000 Hz Stereo (Float32)",
                        isBold: true
                    )
                    
                    // Row 4: Output Route
                    HStack {
                        Text("Output Route")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: routeIconName)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.primary)
                            Text(stats.outputRoute)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Row 5: Phone Volume
                    HStack {
                        Text("Phone Volume")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: stats.deviceVolumePercent > 50 ? "speaker.wave.3.fill" : (stats.deviceVolumePercent > 0 ? "speaker.wave.1.fill" : "speaker.slash.fill"))
                                .font(.system(size: 12))
                                .foregroundColor(stats.deviceVolumePercent == 0 ? AppTheme.statusRed : .secondary)
                            Text("\(stats.deviceVolumePercent)%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(stats.deviceVolumePercent == 0 ? AppTheme.statusRed : .primary)
                        }
                    }
                    
                    // Row 6: Playback Gain Boost (- / +)
                    HStack {
                        Text("Playback Gain")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 10) {
                            Button {
                                service.decreaseGain()
                            } label: {
                                Text("−")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 28, height: 28)
                                    .background(Color(white: 0.92))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Text(String(format: "%.1fx", stats.playbackGain))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .frame(width: 44)
                            
                            Button {
                                service.increaseGain()
                            } label: {
                                Text("+")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 28, height: 28)
                                    .background(Color(white: 0.92))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Row 7: Output Level (RMS numeric)
                    detailRow(
                        title: "Output Level",
                        value: String(format: "%.3f", stats.currentRmsLevel),
                        isBold: true
                    )
                    
                    // Live Indicator Line
                    if stats.state == .connected {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppTheme.statusGreen)
                                .frame(width: 8, height: 8)
                            
                            Text("Receiving audio stream from PC")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.statusGreen)
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard(cornerRadius: 16)
    }
    
    private func detailRow(
        title: String,
        value: String,
        valueColor: Color = .primary,
        isBold: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: isBold ? .bold : .regular))
                .foregroundColor(valueColor)
        }
    }
}
