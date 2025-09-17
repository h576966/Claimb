import SwiftUI

public struct GlowCSpinner: View {
    // Tunables
    public var size: CGFloat = 120
    public var speed: Double = 1.5            // seconds per full rotation
    public var outerLineWidth: CGFloat = 0.18  // Now proportional to size
    public var gap: CGFloat = 0.18            // how big the "C" gap is (0...1 trim span)
    public var outerColor: Color = .white
    public var ringColor: Color = Color(red: 1.0, green: 0.30, blue: 0.25) // warm red
    public var coreColor: Color = Color(red: 1.0, green: 0.74, blue: 0.20) // orange
    
    @State private var rotate = false
    @State private var innerRotate = false
    
    public init(size: CGFloat = 120,
                speed: Double = 1.5,
                outerLineWidth: CGFloat = 0.18,
                gap: CGFloat = 0.18,
                outerColor: Color = .white,
                ringColor: Color = Color(red: 1.0, green: 0.30, blue: 0.25),
                coreColor: Color = Color(red: 1.0, green: 0.74, blue: 0.20)) {
        self.size = size
        self.speed = speed
        self.outerLineWidth = outerLineWidth
        self.gap = gap
        self.outerColor = outerColor
        self.ringColor = ringColor
        self.coreColor = coreColor
    }
    
    public var body: some View {
        ZStack {
            // Optional soft vignette (subtle)
            RadialGradient(colors: [DesignSystem.Colors.background.opacity(0.18), .clear],
                           center: .center, startRadius: 0, endRadius: size * 0.9)
                .blendMode(.multiply)
            
            // Glowing outer "C"
            Circle()
                .trim(from: gap, to: 1 - gap) // leaves a gap -> "C"
                .rotation(Angle(degrees: rotate ? 360 : 0))
                .stroke(outerColor, style: StrokeStyle(lineWidth: size * outerLineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .shadow(color: outerColor.opacity(0.95), radius: 18, x: 0, y: 0)
                .shadow(color: outerColor.opacity(0.65), radius: 36, x: 0, y: 0)
                .animation(.linear(duration: speed).repeatForever(autoreverses: false), value: rotate)
            
            // Red inner C ring with rounded edges (glow) - SPINNING
            Circle()
                .trim(from: gap, to: 1 - gap) // leaves a gap -> "C"
                .rotation(Angle(degrees: innerRotate ? -360 : 0)) // counter-rotation
                .stroke(ringColor.opacity(0.95), style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round))
                .frame(width: size * 0.55, height: size * 0.55)
                .shadow(color: ringColor.opacity(0.7), radius: 16)
                .shadow(color: ringColor.opacity(0.35), radius: 28)
                .animation(.linear(duration: speed * 0.7).repeatForever(autoreverses: false), value: innerRotate)
            
            // Orange core solid circle (glow) - STATIC
            Circle()
                .fill(coreColor)
                .frame(width: size * 0.25, height: size * 0.25)
                .shadow(color: coreColor.opacity(0.85), radius: 14)
                .shadow(color: coreColor.opacity(0.45), radius: 26)
        }
        .frame(width: size, height: size)
        .onAppear { 
            rotate = true
            innerRotate = true
        }
        .accessibilityLabel(Text("Loading"))
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        DesignSystem.Colors.background.ignoresSafeArea()
        GlowCSpinner(size: 140)
    }
}
