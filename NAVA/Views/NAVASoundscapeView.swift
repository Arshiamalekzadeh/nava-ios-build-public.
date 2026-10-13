import SwiftUI

struct NAVASoundscapeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = NAVASoundscapePlayer()

    var body: some View {
        ZStack {
            NAVATheme.background.ignoresSafeArea()
            RadialGradient(colors: [NAVATheme.orange.opacity(0.2), .clear],
                           center: .init(x: 0.5, y: 0.32), startRadius: 25, endRadius: 330)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Text("NAVA / FOCUS")
                            .font(.system(size: 11, weight: .medium)).tracking(4)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.07), in: Circle())
                        }
                    }
                    NAVAOrb(diameter: 158, active: player.playing != nil)
                        .padding(.top, 22)
                    Text("فضای خودت را پیدا کن")
                        .font(NAVATheme.type(25, weight: .semibold))
                    Text("محیط‌های صوتی اختصاصی؛ کاملاً آفلاین، بدون تبلیغ و بدون ارسال داده.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 11) {
                        ForEach(NAVASoundscapePlayer.Track.allCases) { track in
                            Button { player.toggle(track) } label: {
                                HStack(spacing: 15) {
                                    Image(systemName: track.symbol)
                                        .foregroundStyle(NAVATheme.orange)
                                        .font(.system(size: 21, weight: .light))
                                        .frame(width: 34)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(track.title)
                                            .font(NAVATheme.type(15, weight: .semibold))
                                        Text(track.detail)
                                            .font(NAVATheme.type(11))
                                            .foregroundStyle(NAVATheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: player.playing == track ? "pause.fill" : "play.fill")
                                        .foregroundStyle(NAVATheme.sand)
                                }
                                .padding(18)
                                .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(player.playing == track
                                        ? NAVATheme.orange.opacity(0.6) : NAVATheme.border, lineWidth: 1))
                            }
                            .buttonStyle(NAVAButtonStyle())
                        }
                    }
                    if let error = player.errorMessage {
                        Text(error).font(NAVATheme.type(12)).foregroundStyle(NAVATheme.sand)
                    }
                    Button("قطع پخش") { player.stop() }
                        .font(NAVATheme.type(12))
                        .disabled(player.playing == nil)
                }
                .frame(maxWidth: 480)
                .padding(24)
            }
        }
        .foregroundStyle(NAVATheme.white)
        .onDisappear { player.stop() }
    }
}
