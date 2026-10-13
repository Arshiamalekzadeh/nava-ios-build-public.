import SwiftUI
import UIKit

private enum NAVAVoiceMode: String, CaseIterable {
    case record = "ضبط صدا"
    case recognize = "فرمان گفتاری"
}

struct VoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NAVAStore
    @EnvironmentObject private var chat: NAVAChatStore
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var voiceRouter: NAVAVoiceRouter
    @EnvironmentObject private var chatGPT: ChatGPTAuthManager
    @EnvironmentObject private var memos: NAVAVoiceMemoStore
    @EnvironmentObject private var focus: NAVAFocusStore
    @EnvironmentObject private var offlineSpeech: NAVAOfflineSpeechService
    @EnvironmentObject private var transcription: NAVATranscriptionService
    @AppStorage("nava.voiceOfflineModel") private var offlineModel = "base"
    @AppStorage("nava.voiceShortcutName") private var shortcutName = ""
    @AppStorage("nava.shortcutAutoListen") private var shortcutAutoListen = true

    @StateObject private var speech = LocalSpeechService()
    @State private var mode: NAVAVoiceMode = .record
    @State private var isHandling = false
    @State private var isStartingCapture = false
    @State private var lastExecuted = ""
    @State private var feedback = ""
    @State private var lastHeardText = ""
    @State private var responsePhase = ""
    @State private var showVoiceHelp = false
    @State private var typedCommand = ""
    @State private var showArchive = false
    @State private var showModelDownloadConsent = false
    @State private var cloudFallbackMemo: NAVAVoiceMemo?
    @State private var isDismissing = false
    @FocusState private var textFocused: Bool

    private var isCapturing: Bool { memos.isRecording }
    private var statusText: String {
        if memos.isRecording { return "در حال ضبط صدای تو" }
        if offlineSpeech.isPreparing || offlineSpeech.isTranscribing { return offlineSpeech.phase }
        if isHandling { return responsePhase.isEmpty ? "نوا در حال پاسخ است…" : responsePhase }
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
                            if memos.isRecording {
                                Circle()
                                    .stroke(NAVATheme.orange.opacity(0.37), lineWidth: 1.5)
                                    .frame(width: 197, height: 197)
                                    .scaleEffect(1 + Double(memos.level) * 0.16)
                                    .animation(.easeOut(duration: 0.12), value: memos.level)
                                    .accessibilityHidden(true)
                            }
                        }
                            .padding(.top, 26)
                            .padding(.bottom, 8)

                        Text(statusText)
                            .font(NAVATheme.type(22, weight: .semibold))
                        Text(mode == .record
                             ? "صدات با کیفیت AAC فقط روی همین آیفون ذخیره می‌شه"
                             : "تشخیص فارسی با Whisper روی خود آیفون؛ مستقل از Speech اپل")
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
                            messagePanel("شنیدم: «\(lastHeardText)»", icon: "text.bubble")
                        }
                        if !feedback.isEmpty {
                            messagePanel(feedback, icon: "sparkle")
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
                            if let failedMemo = cloudFallbackMemo, transcription.configured {
                                Button {
                                    Task { await transcribeUsingOnlineFallback(failedMemo) }
                                } label: {
                                    Label("ارسال ضبط برای تشخیص آنلاین (اختیاری)", systemImage: "arrow.up.cloud")
                                        .font(NAVATheme.type(12, weight: .semibold))
                                        .foregroundStyle(NAVATheme.sand)
                                }
                                .disabled(isHandling)
                                Text("فایل فقط با لمس دکمه بالا به سرویس تنظیم‌شده ارسال می‌شه.")
                                    .font(NAVATheme.type(10))
                                    .foregroundStyle(NAVATheme.muted)
                            }
                        }
                        if let notice = speech.notice, !notice.isEmpty {
                            messagePanel(notice, icon: "info.circle")
                        }
                        if let error = memos.errorMessage, !error.isEmpty {
                            messagePanel(error, icon: "exclamationmark.triangle")
                        }

                        Button {
                            if !speech.speak("سلام، من نوا هستم.") {
                                showVoiceHelp = true
                            }
                        } label: {
                            Label("تست صدای نوا", systemImage: "speaker.wave.2")
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.sand)
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
            await activity.start(status: "آماده گفتگو", phase: .ready)
            await activity.updateStatus("آماده گفتگو", phase: .ready)
            if voiceRouter.consumeAutoListen() && shortcutAutoListen {
                mode = .recognize
                await launchVoiceFromShortcut()
            }
        }
        .onChange(of: voiceRouter.autoListenRequested) { _, requested in
            if requested, shortcutAutoListen, voiceRouter.consumeAutoListen() {
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
            speech.stop()
            if memos.isRecording { _ = memos.stop() }
            Task { await activity.updateStatus("آماده گفتگو") }
        }
        .onDisappear {
            isDismissing = true
            speech.stop()
            if memos.isRecording { _ = memos.stop() }
            Task { await activity.updateStatus("آماده گفتگو") }
        }
        .alert("صدای فارسی خروجی در iOS پیدا نشد", isPresented: $showVoiceHelp) {
            Button("تنظیمات NAVA") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("باشه", role: .cancel) {}
        } message: {
            Text("Whisper صدای تو رو به متن تبدیل می‌کنه، ولی پخش پاسخ با صدای فارسی به یک موتور گفتار جدا نیاز داره. iOS در این دستگاه فعلاً صدای فارسی در اختیار برنامه قرار نمی‌ده؛ متن پاسخ همیشه قابل‌مشاهده است.")
        }
        .confirmationDialog("دانلود موتور فارسی آفلاین", isPresented: $showModelDownloadConsent) {
            Button("دانلود مدل و شروع ضبط") {
                Task { await startPersianVoiceCapture() }
            }
            Button("انصراف", role: .cancel) {}
        } message: {
            Text("مدل \(offlineModel == "base" ? "Base" : "Tiny") یک بار از اینترنت دانلود می‌شه و ده‌ها تا صدها مگابایت حجم داره. تشخیص گفتار بعدش بدون API و روی آیفون انجام می‌شه.")
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
                speech.stop()
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
                    Image(systemName: isCapturing ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 26))
                    Text(isCapturing
                         ? (mode == .record ? "پایان و ذخیره ضبط" : "توقف و اجرای فرمان")
                         : (mode == .record ? "شروع ضبط صدا" : "شروع فرمان فارسی آفلاین"))
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
            .disabled(isHandling || isStartingCapture || offlineSpeech.isPreparing || offlineSpeech.isTranscribing)
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
        speech.stop()
        if memos.isRecording { _ = memos.stop() }
        await activity.stop()
        voiceRouter.requestedAction = nil
        dismiss()
    }

    private func launchVoiceFromShortcut() async {
        if memos.isRecording { return }
        if offlineSpeech.wasPrepared(offlineModel) {
            await startPersianVoiceCapture()
        } else {
            // The user must approve the first model download explicitly.
            showModelDownloadConsent = true
        }
    }

    private func microphoneTapped() async {
        guard !isHandling else { return }
        if memos.isRecording {
            guard let memo = memos.stop() else {
                feedback = "صدای کوتاهی ضبط نشد؛ دوباره امتحان کن."
                return
            }
            if mode == .record {
                feedback = "صدای «\(memo.title)» ذخیره شد. از آرشیو می‌تونی پخشش کنی."
                await activity.updateStatus("ضبط ذخیره شد")
            } else {
                await processPersianRecording(memo)
            }
            return
        }

        feedback = ""
        lastHeardText = ""
        responsePhase = ""
        cloudFallbackMemo = nil
        if mode == .record {
            do {
                try await memos.start()
                await activity.start(status: "در حال ضبط صدا")
                await activity.updateStatus("در حال ضبط صدا")
            } catch {
                feedback = error.localizedDescription
            }
        } else if offlineSpeech.wasPrepared(offlineModel) {
            await startPersianVoiceCapture()
        } else {
            showModelDownloadConsent = true
        }
    }

    private func startPersianVoiceCapture() async {
        guard !memos.isRecording && !isHandling && !isStartingCapture else { return }
        isStartingCapture = true
        defer { isStartingCapture = false }
        do {
            try await offlineSpeech.prepare(model: offlineModel)
            try await memos.start()
            feedback = ""
            await activity.start(status: "در حال شنیدن فارسی")
            await activity.updateStatus("در حال شنیدن فارسی")
        } catch {
            feedback = error.localizedDescription
            await activity.updateStatus("آماده گفتگو")
        }
    }

    private func processPersianRecording(_ memo: NAVAVoiceMemo) async {
        guard !isHandling else { return }
        isHandling = true
        responsePhase = "در حال تشخیص فارسی روی آیفون…"
        defer {
            isHandling = false
            responsePhase = ""
        }
        await activity.updateStatus("در حال تشخیص فارسی")
        do {
            let text = try await offlineSpeech.transcribe(
                file: memos.url(for: memo),
                model: offlineModel
            )
            memos.updateTranscript(id: memo.id, text: text)
            lastHeardText = text
            cloudFallbackMemo = nil
            await processText(text)
        } catch {
            feedback = "تشخیص آفلاین انجام نشد: \(error.localizedDescription)"
            if transcription.configured { cloudFallbackMemo = memo }
            await activity.updateStatus("آماده گفتگو")
        }
    }

    private func transcribeUsingOnlineFallback(_ memo: NAVAVoiceMemo) async {
        guard !isHandling else { return }
        isHandling = true
        responsePhase = "در حال دریافت متن از سرویس انتخابی…"
        defer {
            isHandling = false
            responsePhase = ""
        }
        await activity.updateStatus("در حال تبدیل صدا")
        do {
            // Never automatically upload recorded audio.
            let text = try await transcription.transcribe(file: memos.url(for: memo))
            memos.updateTranscript(id: memo.id, text: text)
            lastHeardText = text
            cloudFallbackMemo = nil
            await processText(text)
        } catch {
            feedback = "سرویس آنلاین پاسخ نداد: \(error.localizedDescription)"
            await activity.updateStatus("آماده گفتگو")
        }
    }

    private func sendTypedCommand() {
        let text = typedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isHandling else { return }
        typedCommand = ""
        textFocused = false
        executeCommand(text)
    }

    private func executeCommand(_ text: String) {
        guard !isHandling else { return }
        isHandling = true
        lastHeardText = text
        Task {
            defer {
                isHandling = false
                responsePhase = ""
            }
            await processText(text)
        }
    }

    private func processText(_ text: String) async {
        lastHeardText = text
        responsePhase = "در حال بررسی فرمان…"
        await activity.updateStatus("در حال پاسخ")
        let response: String
        if case .unknown = NAVACommandParser.parse(text), chatGPT.canUsePlan {
            responsePhase = "در حال دریافت پاسخ هوشمند…"
            response = await chat.sendAI(text, auth: chatGPT)
        } else {
            response = await chat.send(text, store: store)
        }
        feedback = "نوا: \(response)"
        if !speech.speak(response) {
            // A missing system fa-IR TTS voice must never conceal the reply.
            // The response remains prominently readable in the UI.
        }
        responsePhase = ""
        await activity.updateStatus("آماده گفتگو", phase: .ready)
    }
}
