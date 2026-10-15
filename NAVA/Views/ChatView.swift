import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var chat: NAVAChatStore
    @EnvironmentObject private var store: NAVAStore
    @EnvironmentObject private var chatGPT: ChatGPTAuthManager
    @EnvironmentObject private var voiceRouter: NAVAVoiceRouter
    @State private var draft = ""
    @State private var isBusy = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 17) {
                            ForEach(chat.messages) { message in
                                HStack {
                                    if message.role == .user { Spacer(minLength: 38) }
                                    VStack(alignment: .trailing, spacing: 8) {
                                        Text(message.text)
                                            .font(NAVATheme.type(15))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(message.createdAt, style: .time)
                                            .font(.system(size: 10))
                                            .foregroundStyle(NAVATheme.muted)
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 12)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .background(
                                        message.role == .user
                                            ? AnyShapeStyle(NAVATheme.ember)
                                            : AnyShapeStyle(NAVATheme.card),
                                        in: RoundedRectangle(cornerRadius: 20)
                                    )
                                    if message.role == .nava { Spacer(minLength: 38) }
                                }
                                .id(message.id)
                            }
                        }
                        .padding(19)
                    }
                    .onChange(of: chat.messages.count) { _, _ in
                        if let last = chat.messages.last {
                            withAnimation(.easeOut(duration: 0.24)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                VStack(spacing: 11) {
                    if chat.messages.count < 3 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                quick("راهنما")
                                quick("ساعت چنده")
                                quick("لیست یادآورها")
                                quick("نقشه تهران")
                            }
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                    if let pending = chat.pendingAction {
                        Button {
                            UIApplication.shared.open(pending.destination)
                            chat.dismissAction()
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "arrow.up.right")
                                Text(pending.title)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.circle")
                            }
                            .font(NAVATheme.type(13, weight: .semibold))
                            .foregroundStyle(NAVATheme.white)
                            .padding(15)
                            .background(NAVATheme.ember, in: RoundedRectangle(cornerRadius: 17))
                        }
                        .accessibilityLabel("تأیید و باز کردن لینک")
                    }

                    if chatGPT.canUsePlan {
                        Label("ChatGPT متصل است · گفت‌وگوی هوشمند در NAVA", systemImage: "checkmark.shield")
                            .font(NAVATheme.type(12, weight: .medium))
                            .foregroundStyle(NAVATheme.sand)
                    } else {
                        Button {
                            Task { await chatGPT.signIn() }
                        } label: {
                            Label("Continue with ChatGPT · اتصال حساب به NAVA", systemImage: "person.crop.circle.badge.checkmark")
                                .font(NAVATheme.type(12, weight: .medium))
                                .foregroundStyle(NAVATheme.sand)
                        }
                        .disabled(chatGPT.isSigningIn)
                        if let error = chatGPT.errorMessage {
                            Text(error).font(NAVATheme.type(11)).foregroundStyle(.red)
                        }
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        Button {
                            focused = false
                            voiceRouter.open(listen: true)
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(NAVATheme.orange)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("شروع مکالمه صوتی با نوا")
                        TextField("فرمان یا یادداشتت رو بنویس…", text: $draft, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($focused)
                            .font(NAVATheme.type(14))
                            .tint(NAVATheme.orange)
                            .padding(.vertical, 12)
                        Button {
                            let text = draft
                            draft = ""
                            focused = false
                            isBusy = true
                            Task {
                                if chatGPT.canUsePlan {
                                    await chat.sendAI(text, auth: chatGPT)
                                } else {
                                    await chat.send(text, store: store)
                                }
                                isBusy = false
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 37, height: 37)
                                .background(NAVATheme.orange, in: Circle())
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
                        .accessibilityLabel("ارسال فرمان")
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(NAVATheme.border, lineWidth: 1)
                    }
                }
                .padding(15)
                .background(NAVATheme.background)
            }
            .background(NAVATheme.background.ignoresSafeArea())
            .navigationTitle("گفت‌وگو با نوا")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NAVAEmblem(size: 32)
                }
            }
        }
    }

    private func quick(_ command: String) -> some View {
        Button(command) {
            Task { await chat.send(command, store: store) }
        }
        .font(NAVATheme.type(12))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .foregroundStyle(NAVATheme.sand)
        .background(NAVATheme.card, in: Capsule())
    }
}
