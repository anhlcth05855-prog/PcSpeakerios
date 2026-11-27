import SwiftUI

/// Setup Guide & Troubleshooting Sheet
public struct HelpGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Header Banner
                    HStack(spacing: 16) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User Guide")
                                .font(.system(size: 20, weight: .bold))
                            Text("Turn your iPhone into a PC speaker in 3 steps")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                    
                    // Step 1
                    guideStep(
                        step: "1",
                        title: "Start PC Sender on Computer",
                        desc: "Open the pc-sender folder on your PC and run:",
                        code: "python pc_sender.py"
                    )
                    
                    // Step 2
                    guideStep(
                        step: "2",
                        title: "Same Wi-Fi Network",
                        desc: "Make sure both your iPhone and PC are connected to the same Wi-Fi network (5GHz recommended for lowest latency < 20ms)."
                    )
                    
                    // Step 3
                    guideStep(
                        step: "3",
                        title: "Tap 'Auto Connect' or Scan QR",
                        desc: "The app will discover your PC automatically via UDP beacon. Or tap 'Scan QR' to scan the QR code displayed in the PC terminal."
                    )
                    
                    // Tips & FAQ Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Tips & Troubleshooting")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.top, 8)
                        
                        faqItem(
                            question: "Connected but no sound coming out?",
                            answer: "Check your iPhone media volume (ensure silent switch is not muting audio) and check Windows Sound Mixer to ensure PC audio is not muted."
                        )
                        
                        faqItem(
                            question: "Cannot connect / Connection timed out?",
                            answer: "Ensure Windows Defender Firewall allows Python on Private Networks (or run run_sender.bat as Administrator to automatically open ports 8080 & 8888)."
                        )
                        
                        faqItem(
                            question: "Does it work in the background?",
                            answer: "Yes! The app supports iOS audio background mode. Audio continues streaming smoothly even when the screen is locked or you switch apps."
                        )
                        
                        faqItem(
                            question: "No Wi-Fi available?",
                            answer: "Tap 'Bluetooth / Cable' on the home screen: connect via USB Cable Tethering (< 5ms latency) or Bluetooth Personal Area Network (PAN)."
                        )
                    }
                    .padding()
                    .glassCard(cornerRadius: 16)
                }
                .padding(20)
            }
            .navigationTitle("Help & Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func guideStep(
        step: String,
        title: String,
        desc: String,
        code: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(step)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(AppTheme.primary)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let code = code {
                    Text(code)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primaryLight)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Q: \(question)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
            
            Text(answer)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
