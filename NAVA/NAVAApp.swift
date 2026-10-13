import SwiftUI
import AppIntents

@main
struct NAVAApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = NAVAStore()
    @StateObject private var chat = NAVAChatStore()
    @StateObject private var activityManager = LiveActivityManager()
    @StateObject private var chatGPT = ChatGPTAuthManager()
    @StateObject private var voiceRouter = NAVAVoiceRouter()
    @StateObject private var voiceMemos = NAVAVoiceMemoStore()
    @StateObject private var focus = NAVAFocusStore()
    @StateObject private var transcription = NAVATranscriptionService()
    @StateObject private var offlineSpeech = NAVAOfflineSpeechService()
    @StateObject private var persianTTS = NAVAPersianTTSService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(chat)
                .environmentObject(activityManager)
                .environmentObject(chatGPT)
                .environmentObject(voiceRouter)
                .environmentObject(voiceMemos)
                .environmentObject(focus)
                .environmentObject(transcription)
                .environmentObject(offlineSpeech)
                .environmentObject(persianTTS)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .onAppear {
                    voiceRouter.consumeShortcutFlag()
                    // Refresh iOS's App Intents index after sideload/reinstall.
                    NAVAShortcuts.updateAppShortcutParameters()
                    activityManager.refreshDiagnostics()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { voiceRouter.consumeShortcutFlag() }
                }
                .onOpenURL { voiceRouter.handle($0) }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NAVAOpenVoiceRequested"))) { _ in
                    voiceRouter.consumeShortcutFlag()
                }
                .fullScreenCover(item: $voiceRouter.presentation) { _ in
                    VoiceView()
                        .environmentObject(store)
                        .environmentObject(chat)
                        .environmentObject(activityManager)
                        .environmentObject(chatGPT)
                        .environmentObject(voiceRouter)
                        .environmentObject(voiceMemos)
                        .environmentObject(focus)
                        .environmentObject(transcription)
                        .environmentObject(offlineSpeech)
                        .environmentObject(persianTTS)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                .sheet(item: $chatGPT.browser, onDismiss: {
                    chatGPT.cancelIfBrowserDismissed()
                }) { browser in
                    NAVAOAuthSafariView(url: browser.url)
                        .ignoresSafeArea()
                }
        }
    }
}
