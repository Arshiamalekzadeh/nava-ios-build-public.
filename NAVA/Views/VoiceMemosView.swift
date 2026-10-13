import SwiftUI
import UIKit

struct VoiceMemosView: View {
    @EnvironmentObject private var memos: NAVAVoiceMemoStore
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var transcription: NAVATranscriptionService
    @EnvironmentObject private var chat: NAVAChatStore
    @EnvironmentObject private var store: NAVAStore
    @EnvironmentObject private var chatGPT: ChatGPTAuthManager
    @EnvironmentObject private var offlineSpeech: NAVAOfflineSpeechService
    @AppStorage("nava.voiceOfflineModel") private var offlineModel = "base"
    @State private var search = ""
    @State private var editMemo: NAVAVoiceMemo?
    @State private var editedTitle = ""
    @State private var transcribingID: UUID?
    @State private var transcriptSheet: NAVAVoiceMemo?
    @State private var transcriptResponse = ""
    @State private var pendingOfflineMemo: NAVAVoiceMemo?
    @State private var showOfflineConsent = false

    private var filtered: [NAVAVoiceMemo] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return memos.memos }
        return memos.memos.filter { $0.title.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NAVATheme.background.ignoresSafeArea()
                if memos.memos.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 63, weight: .ultraLight))
                            .foregroundStyle(NAVATheme.orange)
                        Text("اولین صدای خودت رو ضبط کن")
                            .font(NAVATheme.type(21, weight: .semibold))
                        Text("برخلاف تشخیص گفتار اپل، ضبط صدا به پشتیبانی فارسی نیاز نداره. فایل‌ها روی آیفون می‌مونن.")
                            .font(NAVATheme.type(13))
                            .foregroundStyle(NAVATheme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(30)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 11) {
                            HStack {
                                Text("\(memos.memos.count) فایل صوتی")
                                    .font(NAVATheme.type(13))
                                    .foregroundStyle(NAVATheme.muted)
                                Spacer()
                                Label("ذخیره فقط روی دستگاه", systemImage: "lock.shield")
                                    .font(NAVATheme.type(10))
                                    .foregroundStyle(NAVATheme.sand)
                            }
                            .padding(.vertical, 7)

                            ForEach(filtered) { memo in
                                memoCard(memo)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 110)
                    }
                    .searchable(text: $search, prompt: "جستجو بین ضبط‌ها")
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("آرشیو صدا")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) { recorderBar }
            .tint(NAVATheme.orange)
            .alert("تغییر نام ضبط", isPresented: Binding(
                get: { editMemo != nil },
                set: { if !$0 { editMemo = nil } }
            )) {
                TextField("عنوان", text: $editedTitle)
                Button("ذخیره") {
                    if let memo = editMemo { memos.rename(memo, to: editedTitle) }
                    editMemo = nil
                }
                Button("انصراف", role: .cancel) { editMemo = nil }
            } message: {
                Text("برای این فایل صوتی یک اسم انتخاب کن.")
            }
            .alert("مشکل ضبط یا پخش", isPresented: Binding(
                get: { memos.errorMessage != nil },
                set: { if !$0 { memos.errorMessage = nil } }
            )) {
                Button("باشه") { memos.errorMessage = nil }
            } message: {
                Text(memos.errorMessage ?? "")
            }
            .confirmationDialog("دریافت مدل تشخیص فارسی", isPresented: $showOfflineConsent) {
                Button("دانلود مدل و تبدیل به متن") {
                    if let memo = pendingOfflineMemo { transcribeOffline(memo) }
                    pendingOfflineMemo = nil
                }
                Button("انصراف", role: .cancel) {
                    pendingOfflineMemo = nil
                }
            } message: {
                Text("مدل \(offlineModel == "base" ? "Base" : "Tiny") یک‌بار دانلود می‌شه. تشخیص متن ضبط‌شده بعدش روی خود آیفون انجام می‌شه.")
            }
            .sheet(item: $transcriptSheet) { memo in
                transcriptDetail(memo)
            }
            .onDisappear {
                if memos.isRecording {
                    _ = memos.stop()
                    Task { await activity.updateStatus("آماده گفتگو") }
                }
                memos.stopPlayback()
            }
        }
    }

    private func memoCard(_ memo: NAVAVoiceMemo) -> some View {
        HStack(spacing: 13) {
            Button {
                memos.togglePlayback(memo)
            } label: {
                Image(systemName: memos.playingID == memo.id ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NAVATheme.orange)
                    .frame(width: 50, height: 50)
                    .background(NAVATheme.orange.opacity(0.11), in: Circle())
            }
            .accessibilityLabel(memos.playingID == memo.id ? "توقف پخش" : "پخش ضبط")

            VStack(alignment: .leading, spacing: 7) {
                Text(memo.title)
                    .font(NAVATheme.type(14, weight: .medium))
                    .lineLimit(2)
                Text("\(durationText(memo.duration)) · \(memo.createdAt.formatted(.dateTime.day().month().year()))")
                    .font(NAVATheme.type(11))
                    .foregroundStyle(NAVATheme.muted)
                if let transcript = memo.transcript {
                    Text(transcript)
                        .font(NAVATheme.type(11))
                        .foregroundStyle(NAVATheme.sand)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button {
                if memo.transcript != nil {
                        transcriptResponse = ""
                        transcriptSheet = memo
                } else {
                    askOfflineTranscription(memo)
                }
            } label: {
                Image(systemName: transcribingID == memo.id ? "hourglass" : "text.bubble")
                    .foregroundStyle(NAVATheme.sand)
                    .frame(width: 32, height: 42)
            }
            .disabled(transcribingID != nil)
            .accessibilityLabel(memo.transcript != nil ? "مشاهده متن ضبط" : "تبدیل گفتار فارسی آفلاین")
            ShareLink(item: memos.url(for: memo)) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(NAVATheme.sand)
                    .frame(width: 32, height: 42)
            }
            .accessibilityLabel("اشتراک‌گذاری فایل صوتی")
            Menu {
                Button("تشخیص فارسی آفلاین", systemImage: "waveform.badge.mic") {
                    askOfflineTranscription(memo)
                }
                if transcription.configured {
                    Button("ارسال برای تشخیص آنلاین", systemImage: "arrow.up.cloud") {
                        transcribe(memo)
                    }
                }
                if memo.transcript != nil {
                    Button("مشاهده متن", systemImage: "doc.text") {
                        transcriptResponse = ""
                        transcriptSheet = memo
                    }
                }
                Button("تغییر نام", systemImage: "pencil") {
                    editedTitle = memo.title
                    editMemo = memo
                }
                ShareLink(item: memos.url(for: memo)) {
                    Label("اشتراک‌گذاری", systemImage: "square.and.arrow.up")
                }
                Button("حذف ضبط", systemImage: "trash", role: .destructive) {
                    memos.delete(memo)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(NAVATheme.muted)
                    .frame(width: 27, height: 42)
            }
        }
        .padding(15)
        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(NAVATheme.border, lineWidth: 1)
        }
    }

    private var recorderBar: some View {
        VStack(spacing: 10) {
            if memos.isRecording {
                HStack {
                    Circle().fill(.red).frame(width: 9, height: 9)
                    Text("در حال ضبط")
                    Spacer()
                    Text(durationText(memos.elapsed))
                        .monospacedDigit()
                    Capsule()
                        .fill(NAVATheme.orange)
                        .frame(width: max(9, 65 * memos.level), height: 7)
                }
                .font(NAVATheme.type(12))
                .foregroundStyle(NAVATheme.sand)
            }
            Button {
                Task {
                    if memos.isRecording {
                        _ = memos.stop()
                        await activity.updateStatus("آماده گفتگو")
                    } else {
                        do {
                            try await memos.start()
                            await activity.start()
                            await activity.updateStatus("در حال ضبط صدا")
                        } catch { /* Error shown by the store. */ }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: memos.isRecording ? "stop.fill" : "mic.fill")
                    Text(memos.isRecording ? "پایان و ذخیره ضبط" : "شروع ضبط صدای جدید")
                        .font(NAVATheme.type(16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(17)
                .background(NAVATheme.ember, in: Capsule())
            }
            .buttonStyle(NAVAButtonStyle())
        }
        .padding(.horizontal, 19)
        .padding(.top, 14)
        .padding(.bottom, 7)
        .background(.ultraThinMaterial)
    }

    private func askOfflineTranscription(_ memo: NAVAVoiceMemo) {
        guard transcribingID == nil else { return }
        if offlineSpeech.wasPrepared(offlineModel) {
            transcribeOffline(memo)
        } else {
            pendingOfflineMemo = memo
            showOfflineConsent = true
        }
    }

    private func transcribeOffline(_ memo: NAVAVoiceMemo) {
        guard transcribingID == nil else { return }
        transcribingID = memo.id
        Task {
            defer { transcribingID = nil }
            do {
                try await offlineSpeech.prepare(model: offlineModel)
                let text = try await offlineSpeech.transcribe(file: memos.url(for: memo), model: offlineModel)
                memos.updateTranscript(id: memo.id, text: text)
                transcriptResponse = ""
                transcriptSheet = memo
            } catch {
                memos.errorMessage = "تشخیص فارسی آفلاین انجام نشد: \(error.localizedDescription)"
            }
        }
    }

    private func transcribe(_ memo: NAVAVoiceMemo) {
        guard transcribingID == nil else { return }
        transcribingID = memo.id
        Task {
            defer { transcribingID = nil }
            do {
                let transcript = try await transcription.transcribe(file: memos.url(for: memo))
                memos.updateTranscript(id: memo.id, text: transcript)
                transcriptResponse = ""
                transcriptSheet = memo
            } catch {
                memos.errorMessage = error.localizedDescription
            }
        }
    }

    private func transcriptDetail(_ memo: NAVAVoiceMemo) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label("متن شناسایی‌شده", systemImage: "text.bubble")
                        .font(NAVATheme.type(17, weight: .semibold))
                        .foregroundStyle(NAVATheme.sand)
                    Text(memos.memos.first(where: { $0.id == memo.id })?.transcript ?? "")
                        .font(NAVATheme.type(17))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 21))

                    Button {
                        UIPasteboard.general.string = memos.memos.first(where: { $0.id == memo.id })?.transcript
                    } label: {
                        Label("کپی متن", systemImage: "doc.on.doc")
                            .font(NAVATheme.type(14))
                    }

                    Button {
                        let text = memos.memos.first(where: { $0.id == memo.id })?.transcript ?? ""
                        guard !text.isEmpty else { return }
                        Task {
                            if case .unknown = NAVACommandParser.parse(text), chatGPT.canUsePlan {
                                transcriptResponse = await chat.sendAI(text, auth: chatGPT)
                            } else {
                                transcriptResponse = await chat.send(text, store: store)
                            }
                        }
                    } label: {
                        Label("انجام دستور با نوا", systemImage: "sparkle")
                            .font(NAVATheme.type(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .foregroundStyle(.white)
                            .background(NAVATheme.ember, in: RoundedRectangle(cornerRadius: 18))
                    }
                    if !transcriptResponse.isEmpty {
                        Text(transcriptResponse)
                            .font(NAVATheme.type(14))
                            .foregroundStyle(NAVATheme.sand)
                            .padding(16)
                            .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(20)
            }
            .background(NAVATheme.background.ignoresSafeArea())
            .navigationTitle("متن ضبط صدا")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("بستن") { transcriptSheet = nil }
                }
            }
            .tint(NAVATheme.orange)
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
