import ActivityKit
import WidgetKit
import SwiftUI

// NAVA Ember Black — Liquid Amber Island
private let islandOrange = Color(red: 232 / 255, green: 80 / 255, blue: 2 / 255)
private let islandCoral = Color(red: 1, green: 0.51, blue: 0.27)
private let islandSand = Color(red: 217 / 255, green: 195 / 255, blue: 171 / 255)
private let islandCloseURL = URL(string: "nava://voice?action=close")!
private let islandVoiceURL = URL(string: "nava://voice")!

/// Pure SwiftUI original emblem. Built into the extension, so no image bundle
/// or protected app assets are required to render the Dynamic Island.
private struct NAVAIslandOrb: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1, green: 0.88, blue: 0.64),
                            islandCoral,
                            Color(red: 0.79, green: 0.17, blue: 0.025),
                            Color(red: 0.17, green: 0.055, blue: 0.035)
                        ],
                        center: UnitPoint(x: 0.27, y: 0.22),
                        startRadius: 0,
                        endRadius: diameter * 0.82
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [islandSand.opacity(0.85), islandOrange.opacity(0.45), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.5, diameter * 0.035)
                )
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.8), islandSand.opacity(0.14), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: max(1, diameter * 0.09), lineCap: .round)
                )
                .frame(width: diameter * 0.64, height: diameter * 0.31)
                .rotationEffect(.degrees(-43))
                .offset(x: diameter * 0.08, y: diameter * 0.11)
                .blur(radius: diameter * 0.035)
            Ellipse()
                .fill(Color.white.opacity(0.36))
                .frame(width: diameter * 0.28, height: diameter * 0.11)
                .rotationEffect(.degrees(-28))
                .offset(x: -diameter * 0.14, y: -diameter * 0.21)
                .blur(radius: diameter * 0.055)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: islandOrange.opacity(0.5), radius: diameter * 0.18)
        .accessibilityLabel("نوا")
    }
}

/// Deliberately stylized equalizer, not a claim of sub-second live microphone
/// metering. ActivityKit only receives updates at actual state transitions.
private struct NAVAIslandWave: View {
    var compact = false
    var isActive = true

    private let samples: [CGFloat] = [
        0.12, 0.17, 0.28, 0.46, 0.73, 0.92, 0.68,
        0.52, 0.38, 0.54, 0.87, 1.0, 0.75, 0.45,
        0.25, 0.15, 0.10
    ]

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 1.5 : 2.1) {
            ForEach(0..<(compact ? 9 : samples.count), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [islandCoral, islandOrange, islandSand],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: compact ? 1.8 : 2.5,
                        height: max(2, (compact ? 18 : 26) *
                            samples[compact ? index + 4 : index])
                    )
                    .opacity(isActive ? 1 : 0.45)
            }
        }
        .frame(height: compact ? 19 : 29)
        .accessibilityLabel(isActive ? "در حال شنیدن" : "صدا متوقف شده")
    }
}

private struct NAVAIslandProcessingRing: View {
    var diameter: CGFloat = 27

    var body: some View {
        ZStack {
            Circle()
                .stroke(islandOrange.opacity(0.18), lineWidth: 3.5)
            Circle()
                .trim(from: 0.04, to: 0.77)
                .stroke(
                    AngularGradient(
                        colors: [islandOrange.opacity(0.27), islandCoral, islandSand],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel("در حال پردازش")
    }
}

private struct NAVAIslandReplyDots: View {
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == 3 ? islandSand : islandOrange)
                    .frame(width: CGFloat(index + 4), height: CGFloat(index + 4))
                    .opacity(0.5 + Double(index) * 0.15)
            }
        }
        .accessibilityLabel("در حال پاسخ")
    }
}

private struct NAVAIslandActivityContent: View {
    let context: ActivityViewContext<NAVAActivityAttributes>

    var body: some View {
        HStack(spacing: 13) {
            NAVAIslandOrb(diameter: 43)
            VStack(alignment: .leading, spacing: 6) {
                Text("NAVA")
                    .font(.system(size: 15, weight: .light, design: .rounded))
                    .tracking(3.5)
                    .foregroundStyle(.white)
                Text(context.state.phase.persianTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(islandSand)
            }
            Spacer(minLength: 6)
            if let endsAt = context.state.endsAt {
                Text(timerInterval: context.attributes.startedAt...endsAt, countsDown: true)
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(islandSand)
            } else {
                trailingStatus(context.state.phase)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
        .widgetURL(islandVoiceURL)
    }

    @ViewBuilder
    private func trailingStatus(_ phase: NAVAIslandPhase) -> some View {
        switch phase {
        case .listening, .recording:
            NAVAIslandWave(compact: true)
        case .processing:
            NAVAIslandProcessingRing()
        case .responding:
            NAVAIslandReplyDots()
        case .ready, .focus:
            Image(systemName: "sparkle")
                .foregroundStyle(islandOrange)
                .font(.system(size: 15, weight: .light))
        }
    }
}

struct NAVAActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NAVAActivityAttributes.self) { context in
            NAVAIslandActivityContent(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(alignment: .center, spacing: 10) {
                        NAVAIslandOrb(diameter: 33)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("NAVA")
                                .font(.system(size: 12, weight: .light, design: .rounded))
                                .tracking(2.5)
                                .foregroundStyle(.white)
                            Text(context.state.phase.persianTitle)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(islandSand)
                        }
                    }
                    .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 9) {
                        Text(context.state.status)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(islandSand)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 10)
                        // Controls reopen NAVA. Live Activity cannot start
                        // recording directly or impersonate Siri.
                        Link(destination: islandVoiceURL) {
                            Image(systemName: "mic")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.11), in: Circle())
                        }
                        .accessibilityLabel("باز کردن میکروفون نوا")
                        Link(destination: islandCloseURL) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.11), in: Circle())
                        }
                        .accessibilityLabel("بستن فعالیت نوا")
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 1)
                }
            } compactLeading: {
                NAVAIslandOrb(diameter: 22)
            } compactTrailing: {
                compactTrailing(context)
            } minimal: {
                NAVAIslandOrb(diameter: 23)
            }
            .keylineTint(islandOrange)
            .widgetURL(islandVoiceURL)
        }
    }

    @ViewBuilder
    private func compactTrailing(_ context: ActivityViewContext<NAVAActivityAttributes>) -> some View {
        if let endsAt = context.state.endsAt {
            Text(timerInterval: context.attributes.startedAt...endsAt, countsDown: true)
                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(islandSand)
        } else {
            switch context.state.phase {
            case .listening, .recording:
                NAVAIslandWave(compact: true)
            case .processing:
                NAVAIslandProcessingRing(diameter: 19)
            case .responding:
                NAVAIslandReplyDots()
            case .ready, .focus:
                Text("NAVA")
                    .font(.system(size: 10, weight: .light))
                    .tracking(1.8)
                    .foregroundStyle(islandSand)
            }
        }
    }

    @ViewBuilder
    private func expandedTrailing(_ context: ActivityViewContext<NAVAActivityAttributes>) -> some View {
        if let endsAt = context.state.endsAt {
            Text(timerInterval: context.attributes.startedAt...endsAt, countsDown: true)
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(islandSand)
        } else {
            switch context.state.phase {
            case .listening, .recording:
                NAVAIslandWave()
            case .processing:
                NAVAIslandProcessingRing(diameter: 29)
            case .responding:
                NAVAIslandReplyDots()
            case .ready, .focus:
                NAVAIslandOrb(diameter: 24)
            }
        }
    }
}
