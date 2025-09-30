import SwiftUI

public struct GlowCSpinner: View {
    // Tunables
    public var size: CGFloat = 120
    public var speed: Double = 1.5  // seconds per full rotation
    public var outerLineWidth: CGFloat = 0.18  // Now proportional to size
    public var gap: CGFloat = 0.18  // how big the "C" gap is (0...1 trim span)
    public var outerColor: Color = .white
    public var ringColor: Color = Color(red: 1.0, green: 0.30, blue: 0.25)  // warm red
    public var coreColor: Color = Color(red: 1.0, green: 0.74, blue: 0.20)  // orange

    @State private var rotate = false
    @State private var innerRotate = false

    public init(
        size: CGFloat = 120,
        speed: Double = 1.5,
        outerLineWidth: CGFloat = 0.18,
        gap: CGFloat = 0.18,
        outerColor: Color = .white,
        ringColor: Color = Color(red: 1.0, green: 0.30, blue: 0.25),
        coreColor: Color = Color(red: 1.0, green: 0.74, blue: 0.20)
    ) {
        // Ensure all values are valid and not NaN
        self.size = size.isNaN ? 120 : max(1, size)
        self.speed = speed.isNaN ? 1.5 : max(0.1, speed)
        self.outerLineWidth = outerLineWidth.isNaN ? 0.18 : max(0.01, min(0.5, outerLineWidth))
        self.gap = gap.isNaN ? 0.18 : max(0.0, min(0.5, gap))
        self.outerColor = outerColor
        self.ringColor = ringColor
        self.coreColor = coreColor
    }

    public var body: some View {
        ZStack {
            // Clean outer "C" without glow
            Circle()
                .trim(from: gap, to: 1 - gap)  // leaves a gap -> "C"
                .rotation(Angle(degrees: rotate ? 360 : 0))
                .stroke(
                    outerColor,
                    style: StrokeStyle(lineWidth: size * outerLineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .animation(
                    .linear(duration: speed).repeatForever(autoreverses: false), value: rotate)

            // Red inner C ring without glow - SPINNING
            Circle()
                .trim(from: gap, to: 1 - gap)  // leaves a gap -> "C"
                .rotation(Angle(degrees: innerRotate ? -360 : 0))  // counter-rotation
                .stroke(ringColor, style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round))
                .frame(width: size * 0.55, height: size * 0.55)
                .animation(
                    .linear(duration: speed * 0.7).repeatForever(autoreverses: false),
                    value: innerRotate)

            // Orange core solid circle without glow - STATIC
            Circle()
                .fill(coreColor)
                .frame(width: size * 0.25, height: size * 0.25)
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
        Color.black.ignoresSafeArea()
        GlowCSpinner(size: 140)
    }
}
