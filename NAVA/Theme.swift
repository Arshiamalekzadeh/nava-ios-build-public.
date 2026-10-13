import SwiftUI
import UIKit

enum NAVATheme {
    static let background = Color(hex: 0x000000)
    static let elevated = Color(hex: 0x101010)
    static let card = Color(hex: 0x141414)
    static let orange = Color(hex: 0xE85002)
    static let warm = Color(hex: 0xF16001)
    static let red = Color(hex: 0xC10801)
    static let sand = Color(hex: 0xD9C3AB)
    static let white = Color(hex: 0xF9F9F9)
    static let muted = Color(hex: 0xA7A7A7)
    static let subtle = Color(hex: 0x646464)
    static let border = Color.white.opacity(0.085)

    static let ember = LinearGradient(
        colors: [orange, red, Color(hex: 0x420500)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func type(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Kalameh is a licensed font and is not redistributed in this repository.
        // Add a legally obtained font to app resources to activate it.
        if UIFont(name: "Kalameh", size: size) != nil {
            return .custom("Kalameh", size: size)
        }
        return .system(size: size, weight: weight)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct NAVACard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(19)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(NAVATheme.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 23)
                            .strokeBorder(NAVATheme.border, lineWidth: 0.8)
                    }
            )
    }
}

struct NAVAEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(NAVATheme.orange)
            Text(title).font(NAVATheme.type(20, weight: .semibold))
            Text(subtitle)
                .font(NAVATheme.type(14))
                .foregroundStyle(NAVATheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

struct NAVAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.978 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

struct NAVASectionHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(NAVATheme.type(15, weight: .medium))
            .foregroundStyle(NAVATheme.muted)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
