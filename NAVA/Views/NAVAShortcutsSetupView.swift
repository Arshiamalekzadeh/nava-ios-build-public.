import AppIntents
import SwiftUI
import UIKit

/// App Shortcuts are published by NAVAShortcuts automatically at installation.
/// Personal automations, hardware buttons and Siri settings still require
/// the iPhone owner's permission in iOS.
struct NAVAShortcutsSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var voiceRouter: NAVAVoiceRouter
    @AppStorage("nava.shortcutAutoListen") private var autoListen = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(NAVATheme.orange)
                        .padding(.top, 16)
                    Text("نوا آمادهٔ فراخوانی با Siri است")
                        .font(NAVATheme.type(24, weight: .bold))
                    Text("اکشن Talk to NAVA همراه نصب برنامه، خودکار به iOS معرفی می‌شه. لازم نیست دستی یک اکشن سفارشی بسازی.")
                        .font(NAVATheme.type(13))
                        .foregroundStyle(NAVATheme.muted)

                    SiriTipView(intent: OpenNAVAVoiceIntent())
                        .padding(.vertical, 9)

                    VStack(alignment: .leading, spacing: 13) {
                        Label("بگو: Siri, talk to NAVA", systemImage: "waveform")
                            .font(NAVATheme.type(15, weight: .semibold))
                            .foregroundStyle(NAVATheme.sand)
                        Toggle("شروع ضبط فارسی پس از اجرای میان‌بر", isOn: $autoListen)
                            .font(NAVATheme.type(13))
                        Text("با این گزینه، Shortcuts و Siri بعد از بازکردن نوا، مستقیماً حالت تشخیص فارسی رو فعال می‌کنن. میکروفون فقط وقتی اپ در پیش‌زمینه باز شده و مجوزش داده شده، شروع می‌شه. دانلود اولیه Whisper نیاز به تأیید تو داره.")
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.muted)
                    }
                    .padding(17)
                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 11) {
                        Text("اکشن‌های آمادهٔ نوا")
                            .font(NAVATheme.type(17, weight: .semibold))
                        Label("Talk to NAVA · بازکردن و شروع شنیدن", systemImage: "mic")
                        Label("Open NAVA · بازکردن برنامه", systemImage: "arrow.up.right.square")
                        Label("Save NAVA Note · ذخیره یادداشت", systemImage: "note.text")
                    }
                    .font(NAVATheme.type(13))
                    .padding(17)
                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))

                    Button {
                        NAVAShortcuts.updateAppShortcutParameters()
                        dismiss()
                        voiceRouter.open(listen: autoListen)
                    } label: {
                        Label("تست Talk to NAVA همین حالا", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .foregroundStyle(.white)
                            .background(NAVATheme.ember, in: RoundedRectangle(cornerRadius: 19))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("برای Action Button و Back Tap")
                            .font(NAVATheme.type(16, weight: .semibold))
                        Text("iOS اجازه نمی‌ده نوا بدون تأییدت دکمه‌های سیستمی رو تغییر بده. از Settings → Action Button → Shortcut یا Accessibility → Touch → Back Tap، اکشن Talk to NAVA رو انتخاب کن.")
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.muted)
                        ShortcutsLink()
                        Button {
                            NAVAShortcuts.updateAppShortcutParameters()
                        } label: {
                            Label("ثبت مجدد اکشن‌ها در سیستم", systemImage: "arrow.clockwise")
                                .font(NAVATheme.type(13))
                        }
                        .tint(NAVATheme.orange)
                    }
                    .padding(17)
                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(NAVATheme.background.ignoresSafeArea())
            .foregroundStyle(NAVATheme.white)
            .navigationTitle("Siri & Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("بستن") { dismiss() }
                }
            }
            .onAppear {
                NAVAShortcuts.updateAppShortcutParameters()
            }
        }
    }
}
