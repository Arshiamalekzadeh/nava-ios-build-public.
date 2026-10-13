import SwiftUI
import UIKit

struct HomeView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var store: NAVAStore
    @EnvironmentObject private var activityManager: LiveActivityManager
    @EnvironmentObject private var chatGPT: ChatGPTAuthManager
    @EnvironmentObject private var voiceRouter: NAVAVoiceRouter
    @EnvironmentObject private var memos: NAVAVoiceMemoStore
    @EnvironmentObject private var focus: NAVAFocusStore
    @State private var showMemos = false
    @State private var showBackup = false
    @State private var showFocus = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var persianDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fa_IR")
        formatter.calendar = Calendar(identifier: .persian)
        formatter.dateFormat = "EEEE، d MMMM"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                NAVATheme.background.ignoresSafeArea()
                RadialGradient(
                    colors: [NAVATheme.orange.opacity(0.24), NAVATheme.red.opacity(0.08), .clear],
                    center: .init(x: 0.05, y: 0.02),
                    startRadius: 15, endRadius: 440
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView {
                    VStack(alignment: .leading, spacing: 23) {
                        header
                        voiceHero
                        statusRow
                        quickActions
                        nextUp
                        latestNote
                        tools
                        accountCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 11)
                    .padding(.bottom, 33)
                }
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(NAVATheme.white)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { activityManager.refreshDiagnostics() }
            .sheet(isPresented: $showMemos) {
                VoiceMemosView()
                    .environmentObject(memos)
                    .environmentObject(activityManager)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showFocus) {
                NAVAFocusView()
                    .environmentObject(focus)
                    .environmentObject(activityManager)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showBackup) {
                NAVABackupView()
                    .environmentObject(store)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            NAVAEmblem(size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("NAVA")
                    .font(.system(size: 17, weight: .ultraLight))
                    .tracking(5)
                Text("PERSONAL OS · 4.0")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(NAVATheme.sand)
            }
            Spacer()
            Button { selectedTab = 4 } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17))
                    .frame(width: 42, height: 42)
                    .background(NAVATheme.card, in: Circle())
            }
            .accessibilityLabel("تنظیمات NAVA")
        }
    }

    private var voiceHero: some View {
        Button {
            voiceRouter.open()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("دستیار شخصی تو", systemImage: "sparkle")
                        .font(NAVATheme.type(12, weight: .medium))
                        .foregroundStyle(NAVATheme.sand)
                    Spacer()
                    Text(persianDate)
                        .font(NAVATheme.type(11))
                        .foregroundStyle(NAVATheme.muted)
                }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("بگو، بنویس،\nانجام بده.")
                            .font(NAVATheme.type(30, weight: .bold))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("فرمان‌های روزمره، یادآورها و ضبط صدا؛ همه یک‌جا.")
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.muted)
                            .lineLimit(3)
                        HStack(spacing: 9) {
                            Image(systemName: "mic.fill")
                            Text("باز کردن نوا")
                            Image(systemName: "arrow.up.left")
                        }
                        .font(NAVATheme.type(12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(NAVATheme.ember, in: Capsule())
                    }
                    Spacer(minLength: 0)
                    NAVAOrb(diameter: 126, active: false)
                        .frame(width: 130, height: 145)
                        .accessibilityHidden(true)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(NAVATheme.card)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(NAVATheme.orange.opacity(0.11))
                            .frame(width: 170, height: 170)
                            .blur(radius: 48)
                    }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(NAVATheme.orange.opacity(0.28), lineWidth: 0.8)
            }
        }
        .buttonStyle(NAVAButtonStyle())
        .accessibilityLabel("گفت‌وگو یا ضبط صدا با نوا")
    }

    private var statusRow: some View {
        HStack(spacing: 9) {
            statusMetric("\(store.notes.count)", caption: "یادداشت", icon: "note.text")
            statusMetric("\(store.activeReminders.count)", caption: "یادآور", icon: "bell")
            statusMetric("\(memos.memos.count)", caption: "صدا", icon: "waveform")
        }
    }

    private func statusMetric(_ number: String, caption: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(NAVATheme.orange)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(number)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                Text(caption)
                    .font(NAVATheme.type(10))
                    .foregroundStyle(NAVATheme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 19))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            NAVASectionHeader(text: "دسترسی سریع")
            LazyVGrid(columns: columns, spacing: 12) {
                tile("گفت‌وگو", subtitle: "فرمان متنی و AI", icon: "bubble.left.and.bubble.right") {
                    selectedTab = 1
                }
                tile("ضبط صدا", subtitle: "آرشیو و پخش M4A", icon: "waveform.badge.mic") {
                    showMemos = true
                }
                tile("یادداشت‌ها", subtitle: "ویرایش، پین و جست‌وجو", icon: "square.and.pencil") {
                    selectedTab = 2
                }
                tile("یادآورها", subtitle: "ثبت، تکمیل و تعویق", icon: "calendar.badge.clock") {
                    selectedTab = 3
                }
                tile("Focus", subtitle: "تایمر و صدای محیطی", icon: "timer") {
                    showFocus = true
                }
                tile("فراخوانی Siri", subtitle: "Shortcuts و Action Button", icon: "waveform.path") {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private func tile(_ label: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(NAVATheme.orange)
                    .frame(height: 27)
                Text(label)
                    .font(NAVATheme.type(15, weight: .semibold))
                Text(subtitle)
                    .font(NAVATheme.type(10))
                    .foregroundStyle(NAVATheme.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 89, alignment: .leading)
            .padding(16)
            .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22).strokeBorder(NAVATheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(NAVAButtonStyle())
    }

    private var nextUp: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NAVASectionHeader(text: "برنامه پیش‌رو")
                Spacer()
                Button("همه") { selectedTab = 3 }
                    .font(NAVATheme.type(12))
                    .foregroundStyle(NAVATheme.orange)
            }
            if let reminder = store.activeReminders.first {
                HStack(spacing: 14) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(NAVATheme.orange)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reminder.title)
                            .font(NAVATheme.type(14, weight: .medium))
                            .lineLimit(2)
                        Text(reminder.date, format: .dateTime.day().month().hour().minute())
                            .font(NAVATheme.type(11))
                            .foregroundStyle(NAVATheme.muted)
                    }
                    Spacer()
                    Button {
                        Task { await store.completeReminder(id: reminder.id, completed: true) }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 23))
                            .foregroundStyle(NAVATheme.sand)
                    }
                    .accessibilityLabel("تکمیل یادآور")
                }
                .padding(17)
                .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
            } else {
                Text("فعلاً یادآور بازی نداری؛ روزت رو برنامه‌ریزی کن.")
                    .font(NAVATheme.type(12))
                    .foregroundStyle(NAVATheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(19)
                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private var latestNote: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                NAVASectionHeader(text: "آخرین یادداشت")
                Spacer()
                Button("همه") { selectedTab = 2 }
                    .font(NAVATheme.type(12))
                    .foregroundStyle(NAVATheme.orange)
            }
            if let note = store.orderedNotes.first {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: note.isPinned ? "pin.fill" : "note.text")
                        .foregroundStyle(NAVATheme.orange)
                    Text(note.text)
                        .font(NAVATheme.type(13))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(17)
                .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
            } else {
                Text("اولین ایده‌ات رو ثبت کن.")
                    .font(NAVATheme.type(12))
                    .foregroundStyle(NAVATheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(17)
                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 12) {
            NAVASectionHeader(text: "ابزارهای نوا")
            HStack(spacing: 12) {
                Button {
                    showBackup = true
                } label: {
                    Label("پشتیبان‌گیری", systemImage: "externaldrive")
                        .font(NAVATheme.type(13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 18))
                }
                Button {
                    Task {
                        if activityManager.isRunning {
                            await activityManager.stop()
                        } else {
                            await activityManager.start()
                        }
                    }
                } label: {
                    Label(activityManager.isRunning ? "توقف Island" : "فعال‌کردن Island", systemImage: "capsule")
                        .font(NAVATheme.type(13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 18))
                }
                .disabled(activityManager.isWorking)
            }
            if let error = activityManager.errorMessage {
                Text(error).font(NAVATheme.type(11)).foregroundStyle(NAVATheme.sand)
            }
        }
    }

    private var accountCard: some View {
        Button {
            if chatGPT.canUsePlan {
                selectedTab = 1
            } else {
                selectedTab = 4
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: chatGPT.canUsePlan ? "checkmark.shield" : "person.crop.circle.badge.questionmark")
                    .foregroundStyle(NAVATheme.orange)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 5) {
                    Text(chatGPT.canUsePlan ? "ChatGPT متصل" : "حساب هوش مصنوعی")
                        .font(NAVATheme.type(14, weight: .semibold))
                    Text(chatGPT.canUsePlan ? "چت هوشمند در نوا آماده است" : "وضعیت ورود و مجوز حساب رو بررسی کن")
                        .font(NAVATheme.type(11))
                        .foregroundStyle(NAVATheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 11))
                    .foregroundStyle(NAVATheme.muted)
            }
            .padding(18)
            .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(NAVAButtonStyle())
    }
}
