import SwiftUI
import WidgetKit

private struct NAVALaunchEntry: TimelineEntry {
    let date: Date
}

private struct NAVALaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> NAVALaunchEntry {
        NAVALaunchEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (NAVALaunchEntry) -> Void) {
        completion(NAVALaunchEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NAVALaunchEntry>) -> Void) {
        completion(Timeline(entries: [NAVALaunchEntry(date: Date())], policy: .never))
    }
}

struct NAVAQuickLaunchWidget: Widget {
    private let link = URL(string: "nava://voice")!

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NAVAQuickLaunch", provider: NAVALaunchProvider()) { _ in
            Group {
                if #available(iOS 17.0, *) {
                    GeometryReader { geo in
                        VStack(spacing: geo.size.height > 80 ? 9 : 2) {
                            Image(systemName: "waveform")
                                .font(.system(size: geo.size.height > 80 ? 24 : 19, weight: .light))
                                .foregroundStyle(Color(red: 232 / 255, green: 80 / 255, blue: 2 / 255))
                            Text("NAVA")
                                .font(.system(size: geo.size.height > 80 ? 15 : 11, weight: .medium))
                                .tracking(geo.size.height > 80 ? 3 : 1)
                            if geo.size.height > 80 {
                                Text("لمس کن و صحبت کن")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .containerBackground(for: .widget) {
                        Color.black
                    }
                    .widgetURL(link)
                }
            }
        }
        .configurationDisplayName("NAVA Quick Voice")
        .description("Open NAVA Voice from a Home Screen or Lock Screen widget.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
