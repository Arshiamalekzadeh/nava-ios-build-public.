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
    @EnvironmentObject private var persianTTS: NAVAPersianTTSService
    @AppStorage("nava.voiceAutoSpeak") private var autoSpeak = true
    @EnvironmentObject private var transcription: NAVATranscriptionService
    @AppStorage("nava.voiceOfflineModel") private var offlineModel = "base"
    @AppStorage("nava.voiceShortcutName") private var shortcutName = ""
    @AppStorage("nava.shortcutAutoListen") private var shortcutAutoListen = true
    @AppStorage("nava.voiceContinuous") private var continuousVoice = true
    @AppStorage("nava.voiceAutoStartOnOpen") private var autoStartOnOpen = true
    @AppStorage("nava.voiceSensitivity") private var voiceSensitivity = 0.16

    @StateObject private var speech = LocalSpeechService()
    @State private var mode: NAVAVoiceMode = .recognize
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
    @State private var continuousSession = false
    @State private var conversationRevision = 0
    @State private var isCompletingTurn = false
    @State private var waitingForAudioToFinish = false
    @State private var heardSpeech = false
    @State private var loudFrames = 0
    @State private var lastLoudAt: TimeInterval = 0
    @State private var conversationalError = ""
    @FocusState private var textFocused: Bool

    private var isCapturing: Bool { memos.isRecording }
    private var statusText: String {
        if memos.isRecording { return continuousSession ? "دارم گوش می‌دم… صحبت کن" : "در حال ضبط صدای تو" }
        if offlineSpeech.isPreparing || offlineSpeech.isTranscribing { return offlineSpeech.phase }
        if persianTTS.isSynthesizing { return "نوا در حال ساخت صدای فارسی است…" }
        if persianTTS.isPlaying { return "نوا داره صحبت می‌کنه…" }
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
        .onReceive(memos.$elapsed) { elapsed in
            monitorHandsFreeSilence(at: elapsed)
        }
        .onChange(of: persianTTS.isPlaying) { _, playing in
            if !playing && waitingForAudioToFinish {
                waitingForAudioToFinish = false
                Task { await resumeHandsFreeListening() }
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
            if mode == .record {
                stopContinuousSession()
                persianTTS.stop()
            }
            if memos.isRecording { _ = memos.stop() }
            if !continuousSession {
                Task { await activity.updateStatus("آماده گفتگو", phase: .ready) }
            }
        }
        .onDisappear {
            isDismissing = true
            stopContinuousSession()
            speech.stop()
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
            if mode == .recognize {
                Toggle(isOn: $continuousVoice) {
                    Label("مکالمه بدون دکمه ارسال", systemImage: "waveform")
                        .font(NAVATheme.type(13, weight: .medium))
                }
                .tint(NAVATheme.orange)
                .disabled(continuousSession || memos.isRecording || isHandling)
                .padding(.horizontal, 16)
                if continuousSession {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(memos.isRecording ? NAVATheme.orange : NAVATheme.sand)
                            .frame(width: 8, height: 8)
                        Text(memos.isRecording ? "وقتی مکث کنی، خودم جواب می‌دم" :
                            (persianTTS.isPlaying ? "بعد از جواب دوباره گوش می‌دم" : "دارم جوابت رو آماده می‌کنم"))
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
                             (continuousVoice ? "شروع مکالمه فارسی" : "شروع فرمان فارسی آفلاین"))))
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
        speech.stop()
        persianTTS.stop()
        if memos.isRecording { _ = memos.stop() }
        await activity.stop()
        voiceRouter.requestedAction = nil
        dismiss()
    }

    private func launchVoiceFromShortcut() async {
        if memos.isRecording { return }
        if continuousVoice { continuousSession = true }
        if offlineSpeech.wasPrepared(offlineModel) {
            await startPersianVoiceCapture()
        } else {
            // The user must approve the first model download explicitly.
            showModelDownloadConsent = true
        }
    }

    private func microphoneTapped() async {
        if mode == .recognize && continuousSession {
            stopContinuousSession()
            if memos.isRecording { _ = memos.stop(save: false) }
            persianTTS.stop()
            await activity.updateStatus("آماده گفتگو", phase: .ready)
            return
        }
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
        } else {
            if continuousVoice { continuousSession = true }
            if offlineSpeech.wasPrepared(offlineModel) {
                await startPersianVoiceCapture()
            } else {
                showModelDownloadConsent = true
            }
        }
    }

    private func startPersianVoiceCapture() async {
        guard !memos.isRecording && !isHandling && !isStartingCapture else { return }
        isStartingCapture = true
        defer { isStartingCapture = false }
        do {
            try await offlineSpeech.prepare(model: offlineModel)
            try await memos.start()
            heardSpeech = false
            loudFrames = 0
            lastLoudAt = 0
            conversationalError = ""
            feedback = ""
            await activity.start(status: "در حال شنیدن فارسی")
            await activity.updateStatus("در حال شنیدن فارسی")
        } catch {
            if continuousSession { stopContinuousSession() }
            feedback = error.localizedDescription
            await activity.updateStatus("آماده گفتگو", phase: .ready)
        }
    }

    /// Basic, on-device voice activity detection using AVAudioRecorder levels.
    /// It does not upload audio or continuously call Whisper while capturing.
    /// Only a completed speech segment is transcribed, with explicit recording
    /// permission and an active foreground NAVA conversation.
    private func monitorHandsFreeSilence(at elapsed: TimeInterval) {
        guard continuousSession, mode == .recognize, memos.isRecording,
              !isHandling, !isCompletingTurn, !isStartingCapture, !isDismissing else { return }
        guard elapsed >= 0.55 else { return }

        // Recorder's non-zero meter floor is approximately 0.06. Require
        // successive loud frames to avoid treating clicks as speech.
        let level = Double(memos.level)
        if level >= max(0.1, voiceSensitivity) {
            loudFrames += 1
            if loudFrames >= 3 {
                heardSpeech = true
                lastLoudAt = elapsed
            }
        } else {
            loudFrames = 0
        }

        if heardSpeech && elapsed >= 1.2 &&
            ((elapsed - lastLoudAt) >= 1.45 || elapsed >= 26.0) {
            isCompletingTurn = true
            Task { await finishHandsFreeTurn() }
        } else if !heardSpeech && elapsed >= 35.0 {
            // Never silently upload/interpret a long empty recording.
            stopContinuousSession()
            _ = memos.stop(save: false)
            feedback = "صدایی تشخیص ندادم. برای شروع دوباره، میکروفون رو بزن."
            Task { await activity.updateStatus("آماده گفتگو", phase: .ready) }
        }
    }

    private func stopContinuousSession() {
        conversationRevision += 1
        continuousSession = false
        waitingForAudioToFinish = false
        isCompletingTurn = false
        heardSpeech = false
        loudFrames = 0
    }

    private func finishHandsFreeTurn() async {
        guard continuousSession, memos.isRecording, !isDismissing else {
            isCompletingTurn = false
            return
        }
        let memo = memos.stop()
        isCompletingTurn = false
        guard let memo else {
            conversationalError = "فایل فرمان ضبط نشد. دوباره در حال گوش‌دادنم."
            await resumeHandsFreeListening()
            return
        }
        let revision = conversationRevision
        await processPersianRecording(memo, expectedRevision: revision)
        guard conversationRevision == revision, continuousSession, !isDismissing else { return }
        if persianTTS.isPlaying {
            waitingForAudioToFinish = true
            await activity.updateStatus("در حال پاسخ", phase: .responding)
        } else {
            await resumeHandsFreeListening()
        }
    }

    private func resumeHandsFreeListening() async {
        guard continuousSession, !isDismissing, !memos.isRecording,
              !isStartingCapture, !isHandling,
              !persianTTS.isPlaying && !persianTTS.isSynthesizing else { return }
        await startPersianVoiceCapture()
    }

    private func processPersianRecording(_ memo: NAVAVoiceMemo, expectedRevision: Int? = nil) async {
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
            if let expectedRevision, expectedRevision != conversationRevision { return }
            memos.updateTranscript(id: memo.id, text: text)
            lastHeardText = text
            cloudFallbackMemo = nil
            await processText(text, expectedRevision: expectedRevision)
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

    private func processText(_ text: String, expectedRevision: Int? = nil) async {
        if let expectedRevision, expectedRevision != conversationRevision { return }
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
        if let expectedRevision, expectedRevision != conversationRevision { return }
        feedback = "نوا: \(response)"
        if autoSpeak {
            responsePhase = "در حال ساخت و پخش صدای فارسی…"
            await activity.updateStatus("در حال پاسخ", phase: .responding)
            // Fully offline Piper + sherpa-onnx audio, NOT Apple's missing fa-IR TTS.
            let played = await persianTTS.speak(response)
            if !played, let error = persianTTS.errorMessage {
                feedback += "\n\n\(error)"
            }
        }
        responsePhase = ""
        if persianTTS.isPlaying {
            await activity.updateStatus("در حال پاسخ", phase: .responding)
        } else {
            await activity.updateStatus("آماده گفتگو", phase: .ready)
        }
    }
}
