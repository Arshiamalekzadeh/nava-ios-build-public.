import SwiftUI
import UIKit
import Speech

struct SettingsView: View {
    @EnvironmentObject private var store: NAVAStore
    @EnvironmentObject private var chat: NAVAChatStore
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var chatGPT: ChatGPTAuthManager
    @EnvironmentObject private var voiceMemos: NAVAVoiceMemoStore
    @EnvironmentObject private var transcription: NAVATranscriptionService
    @EnvironmentObject private var offlineSpeech: NAVAOfflineSpeechService
    @AppStorage("nava.voiceOfflineModel") private var offlineModel = "base"
    @AppStorage("nava.voiceShortcutName") private var voiceShortcutName = ""
    @AppStorage("nava.voiceAutoSpeak") private var autoSpeak = true
    @State private var showBackup = false
    @State private var showDeleteMemos = false
    @State private var transcriptionMessage = ""
    @State private var offlineModelMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showDeleteChatConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        NAVAEmblem(size: 55)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("NAVA")
                                .font(.system(size: 20, weight: .ultraLight))
                                .tracking(5)
                            Text("Personal OS · نسخه ۴.۰")
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.sand)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("حساب ChatGPT") {
                    if let account = chatGPT.credentials {
                        Label("حساب متصل: \(account.email ?? "ChatGPT")", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(NAVATheme.sand)
                        Label(
                            account.planEnabled ? "اجازه استفاده از ChatGPT Plus فعال است" : "ورود انجام شده؛ مجوز استفاده از طرح هنوز فعال نیست",
                            systemImage: account.planEnabled ? "checkmark.circle" : "exclamationmark.circle"
                        )
                        .font(NAVATheme.type(12))
                        Button("ورود دوباره با این حساب") {
                            Task { await chatGPT.signIn() }
                        }
                        Button("ورود با یک حساب دیگر") {
                            Task { await chatGPT.signIn(newAccount: true) }
                        }
                        Button("خروج از حساب ChatGPT", role: .destructive) {
                            Task { await chatGPT.signOut() }
                        }
                    } else {
                        Button {
                            Task { await chatGPT.signIn() }
                        } label: {
                            Label("Continue with ChatGPT", systemImage: "person.crop.circle.badge.checkmark")
                                .font(NAVATheme.type(15, weight: .semibold))
                        }
                    }
                    if chatGPT.isSigningIn {
                        HStack {
                            ProgressView()
                            Text(chatGPT.message)
                                .font(NAVATheme.type(12))
                        }
                        Button("لغو ورود", role: .cancel) { chatGPT.cancel() }
                    } else if !chatGPT.message.isEmpty {
                        Text(chatGPT.message).font(NAVATheme.type(12)).foregroundStyle(NAVATheme.sand)
                    }
                    if let error = chatGPT.errorMessage {
                        Text(error).font(NAVATheme.type(12)).foregroundStyle(.red)
                    }
                    Text("ورود در دامنه رسمی OpenAI انجام می‌شود. تاریخچه و Memory اپ ChatGPT وارد NAVA نمی‌شود.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                }

                Section("عیب‌یابی مستقیم آیفون") {
                    NavigationLink {
                        NAVADiagnosticsView()
                    } label: {
                        Label("تست Voice، Siri و Dynamic Island", systemImage: "stethoscope")
                    }
                    Text("میکروفون، پشتیبانی Speech فارسی، امضای Widget Extension و تعداد Live Activityها رو روی همین آیفون بررسی کن.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                }

                Section("میان‌بر مکالمه صوتی") {
                    TextField("نام Shortcut، مثلاً NAVA Voice", text: $voiceShortcutName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("اگر اپ ChatGPT اکشن Voice Mode را در Shortcuts نشان می‌دهد، آن را داخل میان‌بر بساز و دقیقاً همین نام را اینجا وارد کن.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)

                    Button {
                        NAVAShortcuts.updateAppShortcutParameters()
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("باز کردن Shortcuts", systemImage: "square.stack.3d.up")
                    }
                }

                Section("موتور فارسی آفلاین · Whisper") {
                    Label("بدون وابستگی به Speech اپل یا هزینه API", systemImage: "waveform.badge.mic")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.sand)
                    Picker("مدل تشخیص فارسی", selection: $offlineModel) {
                        Text("Tiny · سریع‌تر و سبک‌تر").tag("tiny")
                        Text("Base · دقت بهتر").tag("base")
                    }
                    .pickerStyle(.menu)
                    Text("مدل جدا از IPA دانلود می‌شه و ممکنه ده‌ها تا صدها مگابایت حجم داشته باشه. بعد از دریافت، تشخیص صدا روی خود آیفون انجام می‌شه؛ برای بار اول اتصال اینترنت لازم داری.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Label(
                        offlineSpeech.wasPrepared(offlineModel)
                            ? "مدل انتخاب‌شده قبلاً آماده شده"
                            : "مدل انتخاب‌شده هنوز دریافت نشده",
                        systemImage: offlineSpeech.wasPrepared(offlineModel) ? "checkmark.circle" : "arrow.down.circle"
                    )
                    .font(NAVATheme.type(12))
                    Button {
                        Task {
                            do {
                                offlineModelMessage = ""
                                try await offlineSpeech.prepare(model: offlineModel)
                                offlineModelMessage = "مدل آماده شد؛ می‌تونی مستقیم فارسی صحبت کنی."
                            } catch {
                                offlineModelMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Label(
                            offlineSpeech.isPreparing ? "در حال دریافت و آماده‌سازی…" : "دانلود / بارگذاری موتور فارسی",
                            systemImage: "arrow.down.to.line"
                        )
                    }
                    .disabled(offlineSpeech.isPreparing || offlineSpeech.isTranscribing)
                    Text(offlineSpeech.phase)
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.sand)
                    if !offlineModelMessage.isEmpty {
                        Text(offlineModelMessage)
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.sand)
                    }
                }

                Section("استودیوی صدا") {
                    Label("ضبط آفلاین M4A · \(voiceMemos.memos.count) فایل", systemImage: "waveform")
                    Label("موتور فارسی اپل: \(SFSpeechRecognizer(locale: Locale(identifier: "fa-IR"))?.isAvailable == true ? "در دسترس" : "در دسترس نیست")",
                          systemImage: "text.bubble")
                        .font(NAVATheme.type(12))
                    Toggle("خواندن پاسخ با صدای دستگاه", isOn: $autoSpeak)
                    Text("فرمان گفتاری NAVA حالا از Whisper آفلاین استفاده می‌کنه، نه Speech اپل. خروجی صوتی هنوز به نصب صدای فارسی روی iOS وابسته است و ChatGPT Plus به‌تنهایی Voice API نمی‌ده.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Button("بازکردن تنظیمات دسترسی NAVA") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("تبدیل گفتار فارسی · اختیاری") {
                    Text("اگر سرور شخصیِ Whisper یا کلید API جداگانه داری، ضبط‌های نوا می‌تونن با اجازه خودت به متن تبدیل بشن. ChatGPT Plus به‌تنهایی هزینه یا دسترسی این سرویس رو پوشش نمی‌ده.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    TextField("آدرس HTTPS سرویس", text: $transcription.endpoint)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("مدل، مثل gpt-4o-mini-transcribe", text: $transcription.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("کلید API (برای سرور خصوصی اختیاری)", text: $transcription.secret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("ذخیره تنظیمات تبدیل صدا") {
                        do {
                            try transcription.saveSettings()
                            transcriptionMessage = "تنظیمات امن ذخیره شد."
                        } catch {
                            transcriptionMessage = error.localizedDescription
                        }
                    }
                    if !transcriptionMessage.isEmpty {
                        Text(transcriptionMessage)
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.sand)
                    }
                    Label(transcription.configured ? "سرویس تنظیم شده" : "سرویس هنوز آماده نیست",
                          systemImage: transcription.configured ? "checkmark.shield" : "info.circle")
                        .font(NAVATheme.type(12))
                }

                Section("فایل‌ها و پشتیبان‌گیری") {
                    Button {
                        showBackup = true
                    } label: {
                        Label("پشتیبان‌گیری و بازیابی JSON", systemImage: "externaldrive")
                    }
                    Text("یادداشت و یادآور را می‌تونی به Files صادر کنی. فایل‌های صوتی جداگانه از آرشیو صدا Share می‌شن.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    if !voiceMemos.memos.isEmpty {
                        Button("حذف تمام ضبط‌های صوتی", role: .destructive) {
                            showDeleteMemos = true
                        }
                    }
                }

                Section("فراخوانی با Siri") {
                    Label("اکشن Talk to NAVA در Shortcuts", systemImage: "waveform")
                    Text("می‌تونی از «Siri, talk to NAVA» استفاده کنی یا اکشن Talk to NAVA رو به Action Button و Back Tap وصل کنی. جایگزین موتور سیستمی Siri نمی‌شه.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Button("باز کردن Shortcuts") {
                        NAVAShortcuts.updateAppShortcutParameters()
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("حریم خصوصی") {
                    Label("یادداشت و یادآور: ذخیره محلی", systemImage: "iphone")
                    Label("بدون ذخیره رمز حساب ChatGPT", systemImage: "lock.shield")
                    Button("پاک‌کردن گفت‌وگوی محلی", role: .destructive) {
                        showDeleteChatConfirmation = true
                    }
                    Button("پاک‌کردن یادداشت‌ها و یادآورها", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }

                Section("Dynamic Island") {
                    Text(activity.diagnostic)
                        .font(.system(size: 12, design: .monospaced))
                    Button("بررسی مجدد Live Activity") { activity.refreshDiagnostics() }
                    if let error = activity.errorMessage {
                        Text(error).foregroundStyle(NAVATheme.sand)
                    }
                    Text("ویجت نوا فقط وضعیت فعالیت خود نوا را نمایش می‌دهد و به میکروفون یا Voice Mode اپ رسمی ChatGPT دسترسی ندارد.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                }

                Section("فونت") {
                    Text("تم از فونت کلمه پشتیبانی می‌کند. تا زمان افزودن نسخه دارای مجوزِ فونت به پروژه، از فونت پیش‌فرض سیستم iOS استفاده می‌شود.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NAVATheme.background.ignoresSafeArea())
            .navigationTitle("تنظیمات")
            .tint(NAVATheme.orange)
            .onAppear { activity.refreshDiagnostics() }
            .sheet(isPresented: $showBackup) {
                NAVABackupView()
                    .environmentObject(store)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .confirmationDialog("همه ضبط‌های صوتی برای همیشه حذف شوند؟", isPresented: $showDeleteMemos) {
                Button("حذف همه ضبط‌ها", role: .destructive) { voiceMemos.deleteAll() }
                Button("انصراف", role: .cancel) { }
            }
            .confirmationDialog(
                "همه یادداشت‌ها و یادآورها حذف شوند؟",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("حذف همه", role: .destructive) { store.deleteAll() }
            }
            .confirmationDialog(
                "همه پیام‌های محلی نوا حذف شوند؟",
                isPresented: $showDeleteChatConfirmation,
                titleVisibility: .visible
            ) {
                Button("حذف گفت‌وگو", role: .destructive) { chat.clear() }
            }
        }
    }
}
