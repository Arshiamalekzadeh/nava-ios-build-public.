import SwiftUI

struct NAVAFocusView: View {
    @EnvironmentObject private var focus: NAVAFocusStore
    @EnvironmentObject private var activity: LiveActivityManager
    @State private var now = Date()

    private let sessionLengths = [15, 25, 45, 60]
    private let soundColumns = [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)]

    var body: some View {
        NavigationStack {
            ZStack {
                NAVATheme.background.ignoresSafeArea()
                RadialGradient(
                    colors: [NAVATheme.orange.opacity(0.19), .clear],
                    center: .top, startRadius: 0, endRadius: 440
                )
                .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("تمرکز با نوا")
                                    .font(NAVATheme.type(27, weight: .bold))
                                Text("زمان مشخص، صدای آرام، ذهن منظم.")
                                    .font(NAVATheme.type(13))
                                    .foregroundStyle(NAVATheme.muted)
                            }
                            Spacer()
                            Image(systemName: "timer")
                                .font(.system(size: 34, weight: .ultraLight))
                                .foregroundStyle(NAVATheme.orange)
                        }

                        focusTimerCard

                        if !focus.isActive {
                            NAVASectionHeader(text: "مدت جلسه")
                            HStack(spacing: 8) {
                                ForEach(sessionLengths, id: \.self) { minutes in
                                    Button {
                                        focus.selectedMinutes = minutes
                                    } label: {
                                        Text("\(minutes) دقیقه")
                                            .font(NAVATheme.type(12, weight: .medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 13)
                                            .background(
                                                focus.selectedMinutes == minutes ? NAVATheme.orange.opacity(0.22) : NAVATheme.card,
                                                in: RoundedRectangle(cornerRadius: 14)
                                            )
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .strokeBorder(focus.selectedMinutes == minutes ? NAVATheme.orange : NAVATheme.border, lineWidth: 1)
                                            }
                                    }
                                    .buttonStyle(NAVAButtonStyle())
                                }
                            }
                        }

                        NAVASectionHeader(text: "صدای محیطی آفلاین")
                        LazyVGrid(columns: soundColumns, spacing: 11) {
                            ForEach(NAVAFocusSound.allCases) { sound in
                                Button {
                                    focus.changeSound(sound)
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Image(systemName: sound.icon)
                                            .font(.system(size: 25, weight: .ultraLight))
                                            .foregroundStyle(NAVATheme.orange)
                                        Text(sound.title)
                                            .font(NAVATheme.type(14, weight: .semibold))
                                        Text(sound.subtitle)
                                            .font(NAVATheme.type(10))
                                            .foregroundStyle(NAVATheme.muted)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
                                    .padding(15)
                                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(focus.selectedSound == sound ? NAVATheme.orange : NAVATheme.border, lineWidth: 1)
                                    }
                                }
                                .buttonStyle(NAVAButtonStyle())
                            }
                        }
                        if let error = focus.errorMessage {
                            Text(error)
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.sand)
                        }

                        Text("سه صدای اختصاصی به‌صورت آفلاین داخل خود برنامه هستن. پایان جلسه با اعلان آیفون یادآوری می‌شه؛ برای شنیدن در پس‌زمینه صدا رو روشن نگه دار.")
                            .font(NAVATheme.type(12))
                            .foregroundStyle(NAVATheme.muted)
                            .lineSpacing(5)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { controlBar }
            .foregroundStyle(NAVATheme.white)
            .onAppear { focus.refresh() }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                now = date
                focus.refresh()
            }
        }
    }

    private var focusTimerCard: some View {
        VStack(spacing: 13) {
            Text(focus.isActive ? "جلسه در حال اجراست" : "برای شروع آماده‌ای؟")
                .font(NAVATheme.type(13))
                .foregroundStyle(NAVATheme.sand)

            if let end = focus.endsAt, end > now {
                Text(timerInterval: now...end, countsDown: true)
                    .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(String(format: "%02d:00", focus.selectedMinutes))
                    .font(.system(size: 54, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
            }
            Text(focus.isActive ? "اعلان پایان جلسه تنظیم شده" : "یک بازه بدون حواس‌پرتی برای خودت بساز")
                .font(NAVATheme.type(12))
                .foregroundStyle(NAVATheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 27))
        .overlay {
            RoundedRectangle(cornerRadius: 27)
                .strokeBorder(NAVATheme.orange.opacity(0.24), lineWidth: 1)
        }
    }

    private var controlBar: some View {
        VStack(spacing: 11) {
            if focus.isActive {
                Button {
                    if focus.soundPlaying { focus.stopSound() }
                    else { focus.playSound() }
                } label: {
                    Label(focus.soundPlaying ? "بی‌صدا کردن محیط" : "پخش صدای محیط", systemImage: focus.soundPlaying ? "speaker.slash" : "speaker.wave.2")
                        .font(NAVATheme.type(14))
                        .foregroundStyle(NAVATheme.sand)
                }
            }

            Button {
                Task {
                    if focus.isActive {
                        await focus.cancel(activity: activity)
                    } else {
                        await focus.start(activity: activity)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: focus.isActive ? "stop.fill" : "play.fill")
                    Text(focus.isActive ? "پایان تمرکز" : "شروع \(focus.selectedMinutes) دقیقه تمرکز")
                }
                .font(NAVATheme.type(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(17)
                .background(NAVATheme.ember, in: Capsule())
            }
            .buttonStyle(NAVAButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}
