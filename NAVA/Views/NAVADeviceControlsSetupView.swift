import SwiftUI
import MediaPlayer

struct NAVADeviceControlsSetupView: View {
    @AppStorage("nava.deviceVolumeShortcut") private var shortcutName = "NAVA Volume"
    @AppStorage("nava.deviceVolumeShortcutReady") private var shortcutReady = false

    var body: some View {
        Form {
            Section("فرمان‌های فارسی") {
                Text("روشنایی پنجاه درصد\nنور صفحه رو کم کن\nچراغ قوه رو روشن کن\nچراغ قوه رو خاموش کن\nصدا رو سی درصد کن\nصدا رو زیاد کن")
                Text("روشنایی و چراغ قوه مستقیم اجرا می‌شوند. تنظیم روشنایی iOS پس از قفل گوشی ممکن است به مقدار قبلی برگردد. چراغ قوه به اجازه دوربین نیاز دارد؛ عکس یا ویدیو ضبط نمی‌شود.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("تنظیم صدا با Shortcuts · راه‌اندازی یک بار") {
                TextField("نام شورتکات", text: $shortcutName)
                    .autocorrectionDisabled()
                Text("۱. در Shortcuts یک شورتکات با همین نام بساز.\n۲. اکشن Get Numbers from Input را اضافه کن و ورودی آن را Shortcut Input بگذار.\n۳. اکشن Set Volume را اضافه کن و مقدار صدا را به متغیر Numbers مرحلهٔ قبل وصل کن.\n۴. ذخیره کن و گزینهٔ پایین را روشن کن.")
                Text("نوا مقدار بین ۰ و ۱ می‌فرستد؛ مثلاً ۰٫۵ یعنی ۵۰ درصد. نیازی به تقسیم دوباره بر صد نیست. این فرمان Shortcuts را باز می‌کند؛ نوا نمی‌تواند موفقیت اجرای شورتکات را تأیید کند.")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("شورتکات را ساخته و تنظیم کرده‌ام", isOn: $shortcutReady)
                Link("باز کردن Shortcuts", destination: URL(string: "shortcuts://")!)
                Text("پس از اجرای شورتکات، iOS می‌تواند به نوا برگردد. اگر فرمان را در مکالمهٔ صوتی داده باشی و شروع خودکار میان‌بر روشن باشد، شنیدن ادامه پیدا می‌کند.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("تنظیم دستی صدای رسانه") {
                NAVASystemVolumeControl().frame(height: 44)
                Text("این کنترل رسمی iOS بدون شورتکات کار می‌کند؛ فرمان صوتی صدا به راه‌اندازی بالا نیاز دارد.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("کنترل گوشی")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NAVASystemVolumeControl: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsRouteButton = false
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
