import SwiftUI

/// Real-Time Animated VU Meter displaying Audio Input Level
public struct VUMeterView: View {
    let level: Float // 0.0 to 1.0
    
    private var levelPercent: Int {
        Int(min(1.0, max(0.0, level)) * 100)
    }
    
    public init(level: Float) {
        self.level = level
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Label Row
            HStack {
                Text("Input Level (VU Meter)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(levelPercent)%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(levelPercent > 85 ? AppTheme.statusRed : (levelPercent > 0 ? AppTheme.primary : .secondary))
            }
            
            // Progress Track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(white: 0.92).opacity(0.8))
                        .frame(height: 12)
                    
                    // Dynamic fill bar
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.vuGradient)
                        .frame(
                            width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(level))),
                            height: 12
                        )
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.75, blendDuration: 0.1), value: level)
                    
                    // Tick indicators
                    HStack(spacing: 0) {
                        ForEach(0..<10) { index in
                            Rectangle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 1, height: 12)
                            if index < 9 {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 12)
                }
            }
            .frame(height: 12)
        }
    }
}
