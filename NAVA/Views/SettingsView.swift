import SwiftUI
import UIKit
import Speech
import AVFoundation
import AppIntents

struct SettingsView: View {
    @EnvironmentObject private var store: NAVAStore
    @EnvironmentObject private var chat: NAVAChatStore
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var chatGPT: ChatGPTAuthManager
    @EnvironmentObject private var voiceMemos: NAVAVoiceMemoStore
    @EnvironmentObject private var transcription: NAVATranscriptionService
    @EnvironmentObject private var offlineSpeech: NAVAOfflineSpeechService
    @EnvironmentObject private var persianTTS: NAVAPersianTTSService
    @EnvironmentObject private var voiceRouter: NAVAVoiceRouter
    @AppStorage("nava.voiceOfflineModel") private var offlineModel = "base"
    @AppStorage("nava.voiceShortcutName") private var voiceShortcutName = ""
    @AppStorage("nava.voiceAutoSpeak") private var autoSpeak = true
    @AppStorage("nava.shortcutAutoListen") private var shortcutAutoListen = true
    @AppStorage("nava.voiceAutoStartOnOpen") private var autoStartOnOpen = true
    @AppStorage("nava.voiceSensitivity") private var voiceSensitivity = 0.16
    @State private var showBackup = false
    @State private var showShortcutSetup = false
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
                            Text("Personal OS · نسخه ۴.۶")
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
                        Text("Small · دقیق‌تر، حافظه و دانلود بیشتر").tag("small")
                    }
                    .pickerStyle(.menu)
                    Text("اگر فارسی را اشتباه تشخیص می‌دهد، مدل Small را امتحان کن؛ روی آیفون ۱۵ پرو هم پردازش آن از Base کندتر است.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
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

                Section("کنترل گوشی با فرمان فارسی") {
                    NavigationLink {
                        NAVADeviceControlsSetupView()
                    } label: {
                        Label("روشنایی، چراغ قوه و تنظیم صدا", systemImage: "iphone")
                    }
                }

                Section("استودیوی صدا") {
                    Label("ضبط آفلاین M4A · \(voiceMemos.memos.count) فایل", systemImage: "waveform")
                    Label("موتور فارسی اپل: \(SFSpeechRecognizer(locale: Locale(identifier: "fa-IR"))?.isAvailable == true ? "در دسترس" : "در دسترس نیست")",
                          systemImage: "text.bubble")
                        .font(NAVATheme.type(12))
                    Toggle("نوا پاسخ‌ها را با صدای فارسی بخواند", isOn: $autoSpeak)
                    Label("مکالمه صوتی همیشه با تشخیص زنده و ارسال خودکار است", systemImage: "waveform")
                        .font(NAVATheme.type(12))
                    Toggle("شروع مکالمه با بازکردن صفحه Voice", isOn: $autoStartOnOpen)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("حساسیت تشخیص پایان صحبت")
                            Spacer()
                            Text(voiceSensitivity <= 0.13 ? "زیاد" : voiceSensitivity >= 0.22 ? "کم" : "عادی")
                                .foregroundStyle(NAVATheme.sand)
                        }
                        Slider(value: $voiceSensitivity, in: 0.10...0.25, step: 0.01)
                            .tint(NAVATheme.orange)
                        Text("برای شناسایی صدای آرام، حساسیت رو بیشتر (آستانه کمتر) کن. برای جلوگیری از تشخیص صدای محیط، حساسیت رو کمتر (آستانه بیشتر) کن.")
                            .font(NAVATheme.type(11))
                            .foregroundStyle(NAVATheme.muted)
                    }
                    .font(NAVATheme.type(12))
                    Text("در صفحه Voice متن فارسی هنگام صحبت به‌روز می‌شود. با حدود ۱٫۵ ثانیه مکث پاسخ آماده می‌شود. هنگام پاسخ هم می‌توانی حرف بزنی تا نوا پخش را قطع کند و جملهٔ جدیدت را بگیرد. سرعت و حذف اکو به مدل، آیفون و مسیر صدا بستگی دارد.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Label(
                        persianTTS.isModelBundled ? "Piper فارسی روی آیفون نصب شده" : "مدل Piper فارسی در بسته نصب پیدا نشد",
                        systemImage: persianTTS.isModelBundled ? "checkmark.seal" : "exclamationmark.triangle"
                    )
                    .font(NAVATheme.type(13))
                    .foregroundStyle(persianTTS.isModelBundled ? NAVATheme.sand : .orange)
                    Text("این موتور گفتار فارسی کاملاً مستقل از صدای Siri و Apple Speech است. مدل Piper و داده‌های تلفظ با خود برنامه نصب می‌شن، به اینترنت یا API Key نیاز نداره و حتی در حالت Silent قابل پخشه.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Button {
                        Task {
                            _ = await persianTTS.speak("سلام! من نوا هستم و می‌تونم باهات فارسی صحبت کنم.")
                        }
                    } label: {
                        Label(
                            persianTTS.isSynthesizing ? "در حال ساخت صدای فارسی..." : "تست صدای فارسی مستقل",
                            systemImage: "speaker.wave.2.fill"
                        )
                    }
                    .disabled(!persianTTS.isModelBundled || persianTTS.isSynthesizing)
                    if persianTTS.isPlaying {
                        Button("توقف پخش") { persianTTS.stop() }
                    }
                    if let error = persianTTS.errorMessage {
                        Text(error)
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.sand)
                    }
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

                Section("فراخوانی با Siri و Shortcuts") {
                    Label("اکشن Talk to NAVA به‌طور خودکار ثبت می‌شه", systemImage: "checkmark.circle")
                        .foregroundStyle(NAVATheme.sand)
                    Toggle("شروع شنیدن فارسی بعد از اجرای میان‌بر", isOn: $shortcutAutoListen)
                    Button {
                        NAVAShortcuts.updateAppShortcutParameters()
                        showShortcutSetup = true
                    } label: {
                        Label("راه‌اندازی و تست سریع Siri / Shortcuts", systemImage: "waveform.circle")
                            .font(NAVATheme.type(14, weight: .semibold))
                    }
                    Text("پس از نصب و یک‌بار بازکردن NAVA، اکشن Talk to NAVA در Shortcuts منتشر می‌شه. برای Action Button یا Back Tap باید خودت در تنظیمات iOS اون اکشن رو انتخاب کنی.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
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
                    Button {
                        Task {
                            await activity.start(status: "نوا آماده گفتگو", phase: .ready)
                            activity.refreshDiagnostics()
                        }
                    } label: {
                        Label("روشن‌کردن Dynamic Island برای تست", systemImage: "capsule")
                    }
                    Button {
                        Task { await activity.stop() }
                    } label: {
                        Label("پایان Live Activity نوا", systemImage: "xmark.circle")
                    }
                    Text("اگر Activity count روی صفره، یعنی فعالیت فعالی وجود نداره. اول روی روشن‌کردن Island بزن و سپس از صفحه خارج شو. iOS ممکنه جزیره رو وقتی صفحه اپ بازه نمایش نده؛ روی لاک‌اسکرین هم بررسی کن.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
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
            .sheet(isPresented: $showShortcutSetup, onDismiss: {
                let key = NAVAShortcutsSetup.pendingVoiceTestKey
                if UserDefaults.standard.bool(forKey: key) {
                    UserDefaults.standard.removeObject(forKey: key)
                    voiceRouter.open(listen: UserDefaults.standard.object(forKey: "nava.shortcutAutoListen") as? Bool ?? true)
                }
            }) {
                NAVAShortcutsSetupView()
                    .environmentObject(voiceRouter)
                    .environment(\.layoutDirection, .rightToLeft)
            }
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
