import SwiftUI
import UIKit

private enum NAVAVoiceMode: String, CaseIterable {
    case record = "ضبط صدا"
    case recognize = "فرمان گفتاری"
}

struct VoiceView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NAVAStore
    @EnvironmentObject private var chat: NAVAChatStore
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var voiceRouter: NAVAVoiceRouter
    @EnvironmentObject private var chatGPT: ChatGPTAuthManager
    @EnvironmentObject private var memos: NAVAVoiceMemoStore
    @EnvironmentObject private var focus: NAVAFocusStore
    @EnvironmentObject private var offlineSpeech: NAVAOfflineSpeechService
    @EnvironmentObject private var persianTTS: NAVAPersianTTSService
    @AppStorage("nava.voiceAutoSpeak") private var autoSpeak = true
    @AppStorage("nava.voiceOfflineModel") private var offlineModel = "base"
    @AppStorage("nava.voiceShortcutName") private var shortcutName = ""
    @AppStorage("nava.shortcutAutoListen") private var shortcutAutoListen = true
    @AppStorage("nava.voiceAutoStartOnOpen") private var autoStartOnOpen = true
    @AppStorage("nava.voiceSensitivity") private var voiceSensitivity = 0.16

    @StateObject private var liveSpeech = NAVARealtimeSpeechService()
    @State private var mode: NAVAVoiceMode = .recognize
    @State private var isHandling = false
    @State private var responseTask: Task<Void, Never>?
    @State private var isStartingCapture = false
    @State private var lastExecuted = ""
    @State private var feedback = ""
    @State private var lastHeardText = ""
    @State private var responsePhase = ""
    @State private var showVoiceHelp = false
    @State private var typedCommand = ""
    @State private var showArchive = false
    @State private var showModelDownloadConsent = false
    @State private var isDismissing = false
    @State private var continuousSession = false
    @State private var conversationRevision = 0
    @State private var waitingForAudioToFinish = false
    @State private var conversationalError = ""
    @FocusState private var textFocused: Bool

    private var isCapturing: Bool { memos.isRecording || liveSpeech.isListening }
    private var inputLevel: CGFloat { memos.isRecording ? memos.level : CGFloat(liveSpeech.level) }
    private var statusText: String {
        if persianTTS.isPlaying { return "نوا داره صحبت می‌کنه؛ می‌تونی حرفش رو قطع کنی" }
        if persianTTS.isSynthesizing { return "نوا در حال ساخت صدای فارسی است…" }
        if isHandling { return responsePhase.isEmpty ? "نوا در حال پاسخ است…" : responsePhase }
        if liveSpeech.isListening { return "دارم زنده گوش می‌دم… صحبت کن" }
        if liveSpeech.isFinalizing { return "دارم جمله‌ات رو کامل می‌کنم…" }
        if memos.isRecording { return continuousSession ? "دارم گوش می‌دم… صحبت کن" : "در حال ضبط صدای تو" }
        if offlineSpeech.isPreparing || offlineSpeech.isTranscribing { return offlineSpeech.phase }
        return "نوا آماده است"
    }

    var body: some View {
        ZStack {
            NAVATheme.background.ignoresSafeArea()
            RadialGradient(
                colors: [NAVATheme.orange.opacity(isCapturing ? 0.33 : 0.19), .clear],
                center: .init(x: 0.5, y: 0.27),
                startRadius: 30, endRadius: 350
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: isCapturing)

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 18) {
                        ZStack {
                            NAVAOrb(diameter: 185, active: isCapturing)
                            if isCapturing {
                                Circle()
                                    .stroke(NAVATheme.orange.opacity(0.37), lineWidth: 1.5)
                                    .frame(width: 197, height: 197)
                                    .scaleEffect(1 + Double(inputLevel) * 0.16)
                                    .animation(.easeOut(duration: 0.12), value: inputLevel)
                                    .accessibilityHidden(true)
                            }
                        }
                            .padding(.top, 26)
                            .padding(.bottom, 8)

                        Text(statusText)
                            .font(NAVATheme.type(22, weight: .semibold))
                        Text(mode == .record
                             ? "صدات با کیفیت AAC فقط روی همین آیفون ذخیره می‌شه"
                             : "متن حرفت هنگام صحبت ظاهر می‌شه؛ با مکث، خودم پاسخ می‌دم")
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.muted)
                            .multilineTextAlignment(.center)

                        if memos.isRecording {
                            HStack(spacing: 10) {
                                Circle().fill(NAVATheme.orange).frame(width: 9, height: 9)
                                Text(String(format: "%02d:%02d", Int(memos.elapsed) / 60, Int(memos.elapsed) % 60))
                                    .monospacedDigit()
                                Capsule()
                                    .fill(NAVATheme.ember)
                                    .frame(width: max(8, memos.level * 140), height: 7)
                                    .frame(maxWidth: 145, alignment: .leading)
                            }
                            .font(NAVATheme.type(15, weight: .medium))
                            .foregroundStyle(NAVATheme.sand)
                        }

                        if !lastHeardText.isEmpty {
                            messagePanel("\(liveSpeech.isListening ? "متن زنده" : "شنیدم"): «\(lastHeardText)»", icon: "text.bubble")
                        }
                        if !feedback.isEmpty {
                            messagePanel(feedback, icon: "sparkle")
                        }
                        if !conversationalError.isEmpty {
                            messagePanel(conversationalError, icon: "exclamationmark.triangle")
                        }
                        if mode == .recognize {
                            Label(offlineSpeech.phase, systemImage: "waveform.badge.mic")
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.sand)
                                .multilineTextAlignment(.center)
                            if !offlineSpeech.wasPrepared(offlineModel) {
                                Text("اولین بار باید مدل دانلود بشه؛ بعدش فارسی رو آفلاین تشخیص می‌ده.")
                                    .font(NAVATheme.type(11))
                                    .foregroundStyle(NAVATheme.muted)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        if let audioError = persianTTS.errorMessage, !audioError.isEmpty {
                            messagePanel(audioError, icon: "speaker.slash")
                        }
                        if let error = memos.errorMessage, !error.isEmpty {
                            messagePanel(error, icon: "exclamationmark.triangle")
                        }

                        Button {
                            Task {
                                let ok = await persianTTS.speak("سلام! من نوا هستم. از این به بعد می‌تونیم فارسی با هم صحبت کنیم.")
                                if !ok { showVoiceHelp = true }
                            }
                        } label: {
                            Label("تست صدای نوا", systemImage: "speaker.wave.2")
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.sand)
                        }
                        .disabled(isCapturing || liveSpeech.isFinalizing || isHandling || persianTTS.isSynthesizing)
                        if let error = activity.errorMessage {
                            messagePanel(error, icon: "exclamationmark.triangle")
                        }
                        if !memos.memos.isEmpty {
                            Button {
                                showArchive = true
                            } label: {
                                Label("آرشیو ضبط‌ها · \(memos.memos.count) فایل", systemImage: "waveform.badge.mic")
                                    .font(NAVATheme.type(13))
                                    .foregroundStyle(NAVATheme.sand)
                            }
                            .padding(.vertical, 8)
                        }

                        Button {
                            if !ChatGPTBridge.openVoiceShortcut(named: shortcutName) {
                                ChatGPTBridge.openOfficialAppOrWebsite()
                            }
                        } label: {
                            Label("باز کردن ChatGPT Voice رسمی", systemImage: "arrow.up.right.square")
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.muted)
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) { controlPanel }
        .foregroundStyle(NAVATheme.white)
        .task {
            if voiceRouter.requestedAction == "close" {
                await closeFromIsland()
                return
            }
            focus.stopSound()
            if let result = voiceRouter.lastDeviceControlResult { feedback = result }
            await activity.start(status: "آماده گفتگو", phase: .ready)
            await activity.updateStatus("آماده گفتگو", phase: .ready)
            if voiceRouter.consumeAutoListen() {
                if shortcutAutoListen {
                    mode = .recognize
                    await launchVoiceFromShortcut()
                }
            } else if autoStartOnOpen {
                // Entering the dedicated Voice screen is a foreground,
                // user-initiated action. No background wake-word listener.
                await launchVoiceFromShortcut()
            }
        }
        .onReceive(liveSpeech.$partialText) { text in
            if !text.isEmpty && continuousSession { lastHeardText = text }
        }
        .onChange(of: liveSpeech.completedTurn?.id) { _, _ in
            guard let turn = liveSpeech.completedTurn, continuousSession, !isDismissing else { return }
            beginLiveTurn(turn.text)
        }
        .onChange(of: liveSpeech.interruptionID) { _, token in
            guard token != nil, continuousSession, !isDismissing else { return }
            interruptReply()
        }
        .onChange(of: liveSpeech.errorMessage) { _, error in
            guard let error, continuousSession, !isDismissing else { return }
            conversationalError = error
            stopContinuousSession()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                stopContinuousSession()
                persianTTS.stop()
            } else if phase == .active, shortcutAutoListen, voiceRouter.consumeAutoListen() {
                Task { await launchVoiceFromShortcut() }
            }
        }
        .onChange(of: voiceRouter.lastDeviceControlResult) { _, result in
            if let result { feedback = result }
        }
        .onChange(of: persianTTS.isPlaying) { _, playing in
            if !playing {
                liveSpeech.finishReplyMonitoring()
                if continuousSession, liveSpeech.isListening, !isHandling, !isDismissing {
                    Task { await activity.updateStatus("دارم گوش می‌دم", phase: .listening) }
                }
                if waitingForAudioToFinish {
                    waitingForAudioToFinish = false
                    Task { await resumeHandsFreeListening() }
                } else if !isCapturing && !isHandling && !isDismissing {
                    Task { await activity.updateStatus("آماده گفتگو", phase: .ready) }
                }
            }
        }
        .onChange(of: voiceRouter.autoListenRequested) { _, requested in
            if requested, shortcutAutoListen, scenePhase == .active, voiceRouter.consumeAutoListen() {
                mode = .recognize
                Task { await launchVoiceFromShortcut() }
            }
        }
        .onChange(of: voiceRouter.requestedAction) { _, action in
            if action == "close" {
                Task { await closeFromIsland() }
            }
        }
        .onChange(of: mode) { _, _ in
            if mode == .record {
                stopContinuousSession()
                persianTTS.stop()
            }
            if memos.isRecording { _ = memos.stop() }
            if mode == .recognize {
                Task { await launchVoiceFromShortcut() }
            }
            if !continuousSession {
                Task { await activity.updateStatus("آماده گفتگو", phase: .ready) }
            }
        }
        .onDisappear {
            isDismissing = true
            stopContinuousSession()
            persianTTS.stop()
            if memos.isRecording { _ = memos.stop() }
            Task { await activity.stop() }
        }
        .alert("تست موتور مستقل صدای فارسی", isPresented: $showVoiceHelp) {
            Button("تنظیمات NAVA") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("باشه", role: .cancel) {}
        } message: {
            Text(persianTTS.errorMessage ?? "مدل Piper فارسی برای پخش مستقل استفاده می‌شه. نتیجه تست صوتی رو بررسی کن.")
        }
        .confirmationDialog("دانلود موتور فارسی آفلاین", isPresented: $showModelDownloadConsent) {
            Button("دانلود مدل و شروع ضبط") {
                Task { await startPersianVoiceCapture() }
            }
            Button("انصراف", role: .cancel) { stopContinuousSession() }
        } message: {
            Text("مدل \(offlineModel.capitalized) یک بار از اینترنت دانلود می‌شه و ممکنه صدها مگابایت حجم داشته باشه. تشخیص گفتار بعدش بدون API و روی آیفون انجام می‌شه.")
        }
        .sheet(isPresented: $showArchive) {
            VoiceMemosView()
                .environmentObject(memos)
                .environmentObject(activity)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                isDismissing = true
                stopContinuousSession()
                persianTTS.stop()
                if memos.isRecording { _ = memos.stop() }
                Task { await activity.stop() }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(NAVATheme.card, in: Circle())
            }
            .accessibilityLabel("بستن صفحه صدا")
            Spacer()
            NAVAEmblem(size: 28)
            Text("NAVA")
                .font(.system(size: 14, weight: .light))
                .tracking(4)
            Spacer()
            Button {
                showArchive = true
            } label: {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 17))
                    .frame(width: 44, height: 44)
                    .background(NAVATheme.card, in: Circle())
            }
            .accessibilityLabel("آرشیو صدا")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var controlPanel: some View {
        VStack(spacing: 13) {
            if !lastHeardText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(NAVATheme.orange)
                    Text("شنیدم: \(lastHeardText)")
                        .font(NAVATheme.type(12, weight: .medium))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            if isHandling {
                HStack(spacing: 9) {
                    ProgressView().tint(NAVATheme.orange)
                    Text(responsePhase)
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.sand)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            if mode == .recognize {
                if continuousSession {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(liveSpeech.isListening ? NAVATheme.orange : NAVATheme.sand)
                            .frame(width: 8, height: 8)
                        Text(persianTTS.isPlaying ? "حرف بزن؛ نوا پاسخ را قطع می‌کند و گوش می‌دهد" :
                            liveSpeech.isListening ? "متن زنده است؛ با مکث خودم پاسخ می‌دم" :
                            "دارم جوابت رو آماده می‌کنم")
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.sand)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                }
            }
            Picker("حالت نوا", selection: $mode) {
                ForEach(NAVAVoiceMode.allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                TextField("سؤال یا فرمان فارسی...", text: $typedCommand, axis: .vertical)
                    .lineLimit(1...2)
                    .font(NAVATheme.type(14))
                    .tint(NAVATheme.orange)
                    .focused($textFocused)
                    .onSubmit(sendTypedCommand)
                    .submitLabel(.send)
                Button(action: sendTypedCommand) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(NAVATheme.orange, in: Circle())
                }
                .disabled(isHandling || typedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 7)
            .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 14)

            Button {
                Task { await microphoneTapped() }
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: (continuousSession || isCapturing) ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 26))
                    Text(mode == .record
                         ? (isCapturing ? "پایان و ذخیره ضبط" : "شروع ضبط صدا")
                         : (continuousSession ? "پایان مکالمه" :
                            (isCapturing ? "توقف و اجرای فرمان" :
                             "شروع مکالمه زنده فارسی")))
                        .font(NAVATheme.type(16, weight: .semibold))
                    Spacer()
                    Image(systemName: "waveform")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(NAVATheme.ember, in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(NAVAButtonStyle())
            .disabled((isHandling && !continuousSession) ||
                      (isStartingCapture && !continuousSession) ||
                      (offlineSpeech.isPreparing && !continuousSession) ||
                      (offlineSpeech.isTranscribing && !continuousSession))
            .padding(.horizontal, 14)
        }
        .padding(.top, 15)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private func messagePanel(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).foregroundStyle(NAVATheme.orange)
            Text(text)
                .font(NAVATheme.type(13))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(15)
        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 19))
    }

    /// A close action in the expanded Dynamic Island opens NAVA via
    /// deep link first, then stops any running microphone before ending
    /// the Live Activity. Widgets cannot directly control AVAudioSession.
    private func closeFromIsland() async {
        guard voiceRouter.requestedAction == "close" else { return }
        isDismissing = true
        stopContinuousSession()
        persianTTS.stop()
        if memos.isRecording { _ = memos.stop() }
        await activity.stop()
        voiceRouter.requestedAction = nil
        dismiss()
    }

    private func launchVoiceFromShortcut() async {
        guard !isCapturing, !isHandling, !isStartingCapture,
              !persianTTS.isPlaying, !persianTTS.isSynthesizing, !isDismissing else { return }
        continuousSession = true
        if offlineSpeech.wasPrepared(offlineModel) {
            await startPersianVoiceCapture()
        } else {
            showModelDownloadConsent = true
        }
    }

    private func microphoneTapped() async {
        if mode == .recognize {
            if continuousSession {
                stopContinuousSession()
                persianTTS.stop()
                await activity.updateStatus("آماده گفتگو", phase: .ready)
            } else {
                await launchVoiceFromShortcut()
            }
            return
        }
        guard !isHandling else { return }
        if memos.isRecording {
            if let memo = memos.stop() {
                feedback = "صدای «\(memo.title)» ذخیره شد. از آرشیو می‌تونی پخشش کنی."
            }
            await activity.updateStatus("آماده گفتگو", phase: .ready)
            return
        }
        let revision = conversationRevision
        do {
            try await memos.start()
            guard revision == conversationRevision, !isDismissing else {
                _ = memos.stop(save: false)
                return
            }
            await activity.start(status: "در حال ضبط صدا", phase: .recording)
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func startPersianVoiceCapture() async {
        guard continuousSession, !isCapturing, !isHandling, !isStartingCapture, !isDismissing else { return }
        isStartingCapture = true
        let revision = conversationRevision
        defer { isStartingCapture = false }
        do {
            try await offlineSpeech.prepare(model: offlineModel)
            guard revision == conversationRevision, continuousSession, !isDismissing else { return }
            persianTTS.stop()
            try await liveSpeech.start(using: offlineSpeech, sensitivity: voiceSensitivity)
            guard revision == conversationRevision, continuousSession, !isDismissing else {
                liveSpeech.stop()
                return
            }
            conversationalError = ""
            await activity.start(status: "تشخیص زنده فارسی", phase: .listening)
        } catch {
            guard revision == conversationRevision, !isDismissing else { return }
            stopContinuousSession()
            conversationalError = error.localizedDescription
            await activity.updateStatus("آماده گفتگو", phase: .ready)
        }
    }

    private func stopContinuousSession() {
        conversationRevision += 1
        responseTask?.cancel()
        responseTask = nil
        isHandling = false
        continuousSession = false
        waitingForAudioToFinish = false
        persianTTS.stop()
        liveSpeech.stop()
    }

    private func interruptReply() {
        conversationRevision += 1
        responseTask?.cancel()
        responseTask = nil
        isHandling = false
        responsePhase = ""
        waitingForAudioToFinish = false
        persianTTS.stop()
        let revision = conversationRevision
        Task {
            guard revision == conversationRevision, continuousSession, !isDismissing else { return }
            await activity.updateStatus("دارم گوش می‌دم", phase: .listening)
        }
    }

    private func beginLiveTurn(_ text: String) {
        guard continuousSession, !isDismissing else { return }
        if isHandling || persianTTS.isPlaying || persianTTS.isSynthesizing {
            interruptReply()
        }
        guard !text.isEmpty else {
            // A rejected/noisy segment is not a command and does not require
            // pressing send or restarting the microphone.
            Task { await resumeHandsFreeListening() }
            return
        }
        let revision = conversationRevision
        isHandling = true
        responseTask = Task {
            await processText(text, expectedRevision: revision)
            guard !Task.isCancelled, revision == conversationRevision, continuousSession, !isDismissing else { return }
            isHandling = false
            responseTask = nil
            if persianTTS.isPlaying {
                waitingForAudioToFinish = true
            } else {
                liveSpeech.finishReplyMonitoring()
                await resumeHandsFreeListening()
            }
        }
    }

    private func resumeHandsFreeListening() async {
        guard continuousSession, !isDismissing, !isCapturing,
              !isStartingCapture, !isHandling,
              !persianTTS.isPlaying, !persianTTS.isSynthesizing else { return }
        await startPersianVoiceCapture()
    }
    private func sendTypedCommand() {
        let text = typedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isHandling else { return }
        stopContinuousSession()
        if memos.isRecording { _ = memos.stop(save: false) }
        persianTTS.stop()
        typedCommand = ""
        textFocused = false
        executeCommand(text)
    }

    private func executeCommand(_ text: String) {
        guard !isHandling else { return }
        let revision = conversationRevision
        isHandling = true
        lastHeardText = text
        Task {
            defer {
                if revision == conversationRevision {
                    isHandling = false
                    responsePhase = ""
                }
            }
            await processText(text, expectedRevision: revision)
        }
    }

    private func processText(_ text: String, expectedRevision: Int? = nil) async {
        if let expectedRevision, expectedRevision != conversationRevision { return }
        lastHeardText = text
        responsePhase = "در حال بررسی فرمان…"
        await activity.updateStatus("در حال پاسخ")
        if let expectedRevision, expectedRevision != conversationRevision { return }
        if continuousSession {
            do {
                try await liveSpeech.start(using: offlineSpeech, sensitivity: voiceSensitivity, monitorReply: true)
            } catch {
                guard !Task.isCancelled else { return }
                conversationalError = error.localizedDescription
                stopContinuousSession()
                return
            }
        }
        if Task.isCancelled { return }
        if let expectedRevision, expectedRevision != conversationRevision { return }
        let response: String
        if case .unknown = NAVACommandParser.parse(text), chatGPT.canUsePlan {
            responsePhase = "در حال دریافت پاسخ هوشمند…"
            response = await chat.sendAI(text, auth: chatGPT)
        } else {
            response = await chat.send(text, store: store, resumeVoiceAfterShortcut: continuousSession)
        }
        if let expectedRevision, expectedRevision != conversationRevision { return }
        feedback = "نوا: \(response)"
        if autoSpeak {
            responsePhase = "در حال ساخت و پخش صدای فارسی…"
            await activity.updateStatus("در حال پاسخ", phase: .responding)
            if let expectedRevision, expectedRevision != conversationRevision { return }
            // Fully offline Piper + sherpa-onnx audio, NOT Apple's missing fa-IR TTS.
            let played = await persianTTS.speak(response, through: continuousSession ? liveSpeech.audio : nil)
            if Task.isCancelled { return }
            if let expectedRevision, expectedRevision != conversationRevision { return }
            if !played, let error = persianTTS.errorMessage {
                feedback += "\n\n\(error)"
            }
        }
        responsePhase = ""
        if persianTTS.isPlaying {
            await activity.updateStatus("در حال پاسخ", phase: .responding)
        } else if continuousSession && liveSpeech.isListening {
            await activity.updateStatus("دارم گوش می‌دم", phase: .listening)
        } else {
            await activity.updateStatus("آماده گفتگو", phase: .ready)
        }
    }
}
