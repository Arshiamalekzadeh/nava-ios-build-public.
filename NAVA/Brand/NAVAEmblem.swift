import SwiftUI

/// Lightweight native emblem inspired by the supplied liquid-metal VAYUO symbol.
/// The wordmark in NAVA remains NAVA, not VAYUO WORLD.
struct NAVAEmblem: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.06), lineWidth: size * 0.012)

            Path { path in
                path.move(to: CGPoint(x: size * 0.14, y: size * 0.37))
                path.addCurve(
                    to: CGPoint(x: size * 0.79, y: size * 0.23),
                    control1: CGPoint(x: size * 0.24, y: size * 0.03),
                    control2: CGPoint(x: size * 0.67, y: size * 0.04)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.35, y: size * 0.33),
                    control1: CGPoint(x: size * 0.61, y: size * 0.16),
                    control2: CGPoint(x: size * 0.46, y: size * 0.26)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.66, y: size * 0.68),
                    control1: CGPoint(x: size * 0.32, y: size * 0.61),
                    control2: CGPoint(x: size * 0.52, y: size * 0.83)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.84, y: size * 0.40),
                    control1: CGPoint(x: size * 0.72, y: size * 0.64),
                    control2: CGPoint(x: size * 0.82, y: size * 0.50)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.56, y: size * 0.87),
                    control1: CGPoint(x: size * 0.91, y: size * 0.71),
                    control2: CGPoint(x: size * 0.71, y: size * 0.96)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.14, y: size * 0.37),
                    control1: CGPoint(x: size * 0.34, y: size * 0.87),
                    control2: CGPoint(x: size * 0.06, y: size * 0.60)
                )
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: 0xFEF3D9),
                        Color(hex: 0xB3B8C0),
                        Color(hex: 0x30343A),
                        Color(hex: 0xD5D8DD),
                        Color(hex: 0x111923)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .white.opacity(0.12), radius: size * 0.04)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xDBDDE0), Color(hex: 0x343942), Color(hex: 0x090E17)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.26, y: -size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("NAVA emblem")
    }
}

struct NAVAOrb: View {
    var diameter: CGFloat = 230
    var active: Bool = true
    @State private var phase = false

    var body: some View {
        ZStack {
            Circle()
                .fill(NAVATheme.orange.opacity(0.13))
                .blur(radius: 53)
                .frame(width: diameter * 1.33, height: diameter * 1.33)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.clear, NAVATheme.orange.opacity(0.7), NAVATheme.sand.opacity(0.7), .clear],
                        center: .center
                    ),
                    lineWidth: 0.9
                )
                .frame(width: diameter * 1.11, height: diameter * 1.11)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xFFB350),
                            NAVATheme.orange,
                            Color(hex: 0x782008),
                            Color(hex: 0x150500)
                        ],
                        center: .init(x: 0.33, y: 0.25),
                        startRadius: 4,
                        endRadius: diameter * 0.75
                    )
                )
                .overlay {
                    Circle()
                        .fill(
                            EllipticalGradient(
                                colors: [Color.white.opacity(0.67), .clear],
                                center: .init(x: 0.35, y: 0.2),
                                startRadiusFraction: 0.03,
                                endRadiusFraction: 0.65
                            )
                        )
                        .blur(radius: diameter * 0.1)
                }
                .overlay {
                    Circle()
                        .strokeBorder(NAVATheme.sand.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: NAVATheme.orange.opacity(0.30), radius: active ? 45 : 13)
                .frame(width: diameter * (phase ? 1.02 : 0.96))

            Circle()
                .trim(from: 0.06, to: 0.38)
                .stroke(NAVATheme.sand.opacity(0.64), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: diameter * 0.87, height: diameter * 0.87)
                .rotationEffect(.degrees(phase ? 24 : -18))
                .blur(radius: 1.7)
        }
        .frame(width: diameter * 1.4, height: diameter * 1.4)
        .onAppear { phase = true }
        .animation(active ? .easeInOut(duration: 3.5).repeatForever(autoreverses: true) : .default, value: phase)
        .accessibilityLabel("NAVA abstract orange orb")
    }
}
