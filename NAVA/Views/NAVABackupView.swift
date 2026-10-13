import SwiftUI
import UniformTypeIdentifiers

struct NAVABackupView: View {
    @EnvironmentObject private var store: NAVAStore
    @State private var archiveURL: URL?
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var message = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NAVATheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "externaldrive.badge.icloud")
                            .font(.system(size: 42, weight: .ultraLight))
                            .foregroundStyle(NAVATheme.orange)
                            .padding(.top, 20)

                        Text("اطلاعات نوا دست خودته")
                            .font(NAVATheme.type(23, weight: .semibold))

                        Text("از یادداشت‌ها و یادآورها فایل JSON بگیر یا یک نسخه قبلی رو برگردون. ضبط‌های صدا به‌دلیل حجم و حریم خصوصی در این فایل قرار نمی‌گیرن؛ هر ضبط رو از آرشیو صدا جداگانه Share کن.")
                            .font(NAVATheme.type(13))
                            .foregroundStyle(NAVATheme.muted)
                            .lineSpacing(6)

                        backupStat("یادداشت", store.notes.count, icon: "note.text")
                        backupStat("یادآور", store.reminders.count, icon: "bell")

                        Button {
                            prepareBackup()
                        } label: {
                            Label("ساخت نسخه پشتیبان", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .foregroundStyle(.white)
                                .background(NAVATheme.ember, in: RoundedRectangle(cornerRadius: 19))
                        }

                        if let archiveURL {
                            ShareLink(item: archiveURL) {
                                Label("ذخیره فایل در Files یا ارسال...", systemImage: "doc.zipper")
                                    .frame(maxWidth: .infinity)
                                    .padding(15)
                                    .foregroundStyle(NAVATheme.sand)
                                    .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 19))
                            }
                        }

                        Button {
                            showImporter = true
                        } label: {
                            Label(isImporting ? "در حال بازیابی..." : "بازیابی فایل JSON", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding(15)
                                .foregroundStyle(NAVATheme.white)
                                .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 19))
                        }
                        .disabled(isImporting)

                        if !message.isEmpty {
                            Label(message, systemImage: "checkmark.circle")
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.sand)
                        }
                    }
                    .padding(23)
                }
            }
            .navigationTitle("پشتیبان‌گیری")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    Task { await importArchive(url) }
                case .failure(let error):
                    errorText = error.localizedDescription
                }
            }
            .alert("پشتیبان‌گیری انجام نشد", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("باشه") { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func backupStat(_ label: String, _ count: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(NAVATheme.orange)
            Text(label).font(NAVATheme.type(14))
            Spacer()
            Text("\(count)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
        }
        .padding(17)
        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func prepareBackup() {
        do {
            let bytes = try store.exportData()
            let directory = FileManager.default.temporaryDirectory
            let file = directory.appendingPathComponent("NAVA-backup-\(Int(Date().timeIntervalSince1970)).json")
            try bytes.write(to: file, options: [.atomic])
            archiveURL = file
            message = "نسخه آماده شد. از دکمه Share برای ذخیره استفاده کن."
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func importArchive(_ url: URL) async {
        isImporting = true
        defer { isImporting = false }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let bytes = try Data(contentsOf: url)
            guard bytes.count < 10_000_000 else {
                throw NAVAStoreError.notFound
            }
            try await store.importData(bytes)
            message = "داده‌های جدید بدون حذف موارد موجود بازیابی شدن."
            archiveURL = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
