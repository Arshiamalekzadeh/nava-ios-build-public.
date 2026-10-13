import SwiftUI
import Speech
import AVFoundation
import ActivityKit
import AppIntents
import UIKit

/// On-device diagnostics. A successful GitHub build cannot prove that an
/// extension survived iPhone sideload signing or that fa-IR Speech is installed.
struct NAVADiagnosticsView: View {
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var voiceRouter: NAVAVoiceRouter
    @EnvironmentObject private var persianTTS: NAVAPersianTTSService
    @State private var micStatus = "در حال بررسی…"
    @State private var speechStatus = "در حال بررسی…"
    @State private var persianStatus = "در حال بررسی…"
    @State private var extensionStatus = "در حال بررسی…"
    @State private var islandReport = ""
    @State private var latestCheck = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text("آزمایش واقعی روی همین آیفون")
                    .font(NAVATheme.type(22, weight: .bold))
                Text("هر بخش مستقل بررسی می‌شود. بیلد موفق، تضمین نصب صحیح Extension یا پشتیبانی تشخیص گفتار فارسی نیست.")
                    .font(NAVATheme.type(13))
                    .foregroundStyle(NAVATheme.muted)

                VStack(alignment: .leading, spacing: 14) {
                    diagnosticRow("میکروفون", micStatus, "mic")
                    diagnosticRow("اجازه Speech", speechStatus, "waveform")
                    diagnosticRow("تشخیص فارسی اپل", persianStatus, "character.bubble")
                    diagnosticRow("Widget Extension", extensionStatus, "capsule")
                    diagnosticRow("Live Activity", activity.diagnostic, "waveform.path")
                    diagnosticRow("موتور صدای فارسی مستقل", persianTTS.isModelBundled ? "Piper و داده‌های تلفظ داخل اپ هستن" : "فایل‌های صدای Piper پیدا نشدن", "speaker.wave.2")
                }
                .padding(18)
                .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 22))

                Button {
                    refresh()
                    NAVAShortcuts.updateAppShortcutParameters()
                } label: {
                    Label("بررسی دوباره و ثبت Shortcuts", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(15)
                        .background(NAVATheme.ember, in: RoundedRectangle(cornerRadius: 17))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("۱ · Voice")
                        .font(NAVATheme.type(17, weight: .semibold))
                    Text("WhisperKit برای تشخیص فرمان فارسی به Speech اپل نیاز ندارد؛ فقط مجوز میکروفون و مدل دانلودشده لازم است. اینجا می‌توانی مجوزهای قدیمی Speech و وضعیت میکروفون را هم جداگانه تست کنی.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Button("درخواست دسترسی میکروفون و تشخیص گفتار") {
                        Task {
                            _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
                            }
                            _ = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
                            }
                            refresh()
                        }
                    }
                    Button("تست صفحه Voice") { voiceRouter.open() }
                    Button {
                        Task { _ = await persianTTS.speak("سلام! من نوا هستم و می‌تونم به زبان فارسی صحبت کنم.") }
                    } label: {
                        Label("تست مستقل صدای فارسی نوا", systemImage: "speaker.wave.2.fill")
                    }
                    .disabled(!persianTTS.isModelBundled || persianTTS.isSynthesizing)
                    if let issue = persianTTS.errorMessage {
                        Text(issue).font(NAVATheme.type(12)).foregroundStyle(NAVATheme.sand)
                    }
                }
                .diagnosticPanel()

                VStack(alignment: .leading, spacing: 12) {
                    Text("۲ · Siri و Shortcuts")
                        .font(NAVATheme.type(17, weight: .semibold))
                    Text("در Shortcuts قسمت Apps دنبال NAVA بگرد. اگر اکشن Talk to NAVA هنوز دیده نمی‌شود، اپ را یک‌بار باز کن و «ثبت دوباره» را بزن. گاهی iOS برای ایندکس‌کردن نسخهٔ سایدلودشده زمان نیاز دارد.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Button("ثبت دوباره App Shortcuts") { NAVAShortcuts.updateAppShortcutParameters() }
                    Button("باز کردن Shortcuts") {
                        if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                    }
                    Button("کپی لینک باز کردن Voice") { UIPasteboard.general.string = "nava://voice" }
                }
                .diagnosticPanel()

                VStack(alignment: .leading, spacing: 12) {
                    Text("۳ · Dynamic Island")
                        .font(NAVATheme.type(17, weight: .semibold))
                    Text("در Settings آیفون، Live Activities اپ NAVA را فعال کن. برای تست، یک Activity ایجاد کن و آیفون را قفل و باز کن. وجود Activity بدون نمایش در جزیره ممکن است ناشی از امضای Widget Extension توسط Sideloadly باشد.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Text("پیش‌نمایش واقعی شش وضعیت، بدون فعال‌کردن میکروفون یا دانلود Whisper. هر دکمه یک Live Activity را به‌روز می‌کند؛ قفل دستگاه و خود Dynamic Island را هم بررسی کن.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    ForEach(NAVAIslandPhase.allCases, id: \.self) { phase in
                        Button {
                            Task {
                                let deadline = phase == .focus ? Date().addingTimeInterval(600) : nil
                                await activity.start(
                                    status: phase.persianTitle,
                                    endsAt: deadline,
                                    phase: phase
                                )
                                await activity.updateStatus(
                                    phase.persianTitle,
                                    endsAt: deadline,
                                    phase: phase
                                )
                                refresh()
                            }
                        } label: {
                            HStack {
                                Image(systemName: phase == .listening ? "waveform" :
                                                phase == .processing ? "circle.dotted" :
                                                phase == .responding ? "ellipsis.bubble" :
                                                phase == .recording ? "record.circle" :
                                                phase == .focus ? "timer" : "sparkle")
                                    .foregroundStyle(NAVATheme.orange)
                                    .frame(width: 22)
                                Text(phase.persianTitle)
                                    .font(NAVATheme.type(13))
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(NAVATheme.muted)
                            }
                        }
                    }
                    Button {
                        Task {
                            await activity.stop()
                            await activity.start(status: "در حال گوش دادن", phase: .listening)
                            refresh()
                        }
                    } label: {
                        Label("بازنشانی و ساخت Activity تازه", systemImage: "arrow.clockwise.circle")
                    }
                    Button("کپی گزارش نصب و ActivityKit") {
                        refresh()
                        UIPasteboard.general.string = islandReport
                    }
                    Text(islandReport)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(NAVATheme.muted)
                    Text("اگر ActivityKit فعال و شمارندهٔ فعالیت بالای صفر است ولی هیچ چیز در Lock Screen یا Dynamic Island دیده نمی‌شود، معمولاً اشکال در ثبت/امضای Widget Extension یا خود نسخهٔ iOS است؛ موفق بودن بیلد به‌تنهایی نمایش را تضمین نمی‌کند.")
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)
                    Button("پایان آزمایش") {
                        Task { await activity.stop(); refresh() }
                    }
                    if let error = activity.errorMessage {
                        Text(error).font(NAVATheme.type(12)).foregroundStyle(NAVATheme.sand)
                    }
                }
                .diagnosticPanel()

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("تنظیمات مجوزهای NAVA در آیفون", systemImage: "gearshape")
                }
                .padding(.bottom, 24)
            }
            .padding(20)
        }
        .background(NAVATheme.background.ignoresSafeArea())
        .foregroundStyle(NAVATheme.white)
        .navigationTitle("عیب‌یابی نوا")
        .navigationBarTitleDisplayMode(.inline)
        .tint(NAVATheme.orange)
        .onAppear(perform: refresh)
    }

    private func diagnosticRow(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(NAVATheme.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(NAVATheme.type(13, weight: .semibold))
                Text(detail)
                    .font(NAVATheme.type(11))
                    .foregroundStyle(NAVATheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func refresh() {
        activity.refreshDiagnostics()
        let microphone = AVAudioSession.sharedInstance().recordPermission
        switch microphone {
        case .granted: micStatus = "اجازه داده شده"
        case .denied: micStatus = "رد شده؛ در Settings فعال کن"
        case .undetermined: micStatus = "هنوز درخواست نشده"
        @unknown default: micStatus = "وضعیت نامشخص"
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speechStatus = "اجازه داده شده"
        case .denied: speechStatus = "اجازه رد شده"
        case .restricted: speechStatus = "محدودیت دستگاه"
        case .notDetermined: speechStatus = "هنوز درخواست نشده"
        @unknown default: speechStatus = "نامشخص"
        }
        let recognized = SFSpeechRecognizer.supportedLocales().contains {
            $0.identifier.replacingOccurrences(of: "_", with: "-").lowercased() == "fa-ir"
        }
        persianStatus = recognized
            ? (SFSpeechRecognizer(locale: Locale(identifier: "fa-IR"))?.isAvailable == true ? "روی این دستگاه در دسترس" : "پشتیبانی می‌شود ولی فعلاً در دسترس نیست")
            : "fa-IR در Speech این دستگاه پشتیبانی نمی‌شود"
        let widgetURL = Bundle.main.bundleURL.appendingPathComponent("PlugIns/NAVAWidgetExtension.appex")
        let bundle = Bundle(url: widgetURL)
        let identifier = bundle?.bundleIdentifier ?? "ناموجود"
        let point = (bundle?.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String ?? "ناموجود"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let widgetVersion = bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let isPresent = FileManager.default.fileExists(atPath: widgetURL.path)
        let signed = FileManager.default.fileExists(
            atPath: widgetURL.appendingPathComponent("_CodeSignature/CodeResources").path
        )
        extensionStatus = isPresent
            ? "\(identifier) · build \(widgetVersion) · \(signed ? "CodeResources موجود" : "امضای افزونه قابل‌تأیید نیست")"
            : "Extension در اپ نصب‌شده پیدا نشد؛ بسته و امضا را بررسی کن"
        let statuses = Activity<NAVAActivityAttributes>.activities.map {
            "\($0.id.prefix(8)): \($0.activityState)"
        }.joined(separator: ", ")
        islandReport = """
        NAVA iOS: \(UIDevice.current.systemVersion)
        Host bundle: \(Bundle.main.bundleIdentifier ?? "?")
        Host build: \(appVersion)
        Widget bundle: \(identifier)
        Widget build: \(widgetVersion)
        Widget exists: \(isPresent)
        Widget code resources: \(signed)
        Widget point: \(point)
        ActivityKit allowed: \(ActivityAuthorizationInfo().areActivitiesEnabled)
        Activity count: \(Activity<NAVAActivityAttributes>.activities.count)
        Activity states: \(statuses)
        """
        latestCheck = Date()
    }
}

private struct DiagnosticPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

private extension View {
    func diagnosticPanel() -> some View { modifier(DiagnosticPanel()) }
}
