import SwiftUI

private struct NAVANoteEditor: Identifiable {
    let id = UUID()
    let noteID: UUID?
}

struct NotesView: View {
    @EnvironmentObject private var store: NAVAStore
    @State private var query = ""
    @State private var editor: NAVANoteEditor?
    @State private var draft = ""
    @State private var selectedFilter = 0

    private var filtered: [NAVANote] {
        store.orderedNotes.filter { note in
            (selectedFilter == 0 || note.isPinned) &&
            (query.isEmpty || note.text.localizedStandardContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NAVATheme.background.ignoresSafeArea()
                if store.notes.isEmpty {
                    NAVAEmptyState(
                        icon: "note.text",
                        title: "ایده بعدی از تو شروع می‌شه",
                        subtitle: "یادداشت جدید بساز، ویرایش کن، پین کن و با دیگران به اشتراک بذار."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Picker("فیلتر", selection: $selectedFilter) {
                                Text("همه یادداشت‌ها").tag(0)
                                Text("پین‌شده‌ها").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom, 9)

                            HStack {
                                Text("\(filtered.count) یادداشت")
                                    .font(NAVATheme.type(12))
                                    .foregroundStyle(NAVATheme.muted)
                                Spacer()
                                Text("خصوصی · روی دستگاه")
                                    .font(NAVATheme.type(11))
                                    .foregroundStyle(NAVATheme.sand)
                            }

                            ForEach(filtered) { note in
                                noteCard(note)
                            }
                            if filtered.isEmpty {
                                ContentUnavailableView.search(text: query)
                            }
                        }
                        .padding(18)
                    }
                    .searchable(text: $query, prompt: "جستجو در یادداشت‌ها")
                }
            }
            .navigationTitle("یادداشت‌ها")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draft = ""
                        editor = NAVANoteEditor(noteID: nil)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 23))
                    }
                    .tint(NAVATheme.orange)
                    .accessibilityLabel("یادداشت جدید")
                }
            }
            .sheet(item: $editor) { editor in
                NavigationStack {
                    VStack(spacing: 17) {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("ذخیره خصوصی روی آیفون")
                            Spacer()
                            Text("\(draft.count) کاراکتر")
                        }
                        .font(NAVATheme.type(12))
                        .foregroundStyle(NAVATheme.muted)

                        TextEditor(text: $draft)
                            .font(NAVATheme.type(17))
                            .scrollContentBackground(.hidden)
                            .padding(14)
                            .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 19))
                    }
                    .padding(18)
                    .background(NAVATheme.background.ignoresSafeArea())
                    .navigationTitle(editor.noteID == nil ? "یادداشت جدید" : "ویرایش یادداشت")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("انصراف") { self.editor = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("ذخیره") {
                                if let id = editor.noteID {
                                    store.updateNote(id: id, text: draft)
                                } else {
                                    store.addNote(draft)
                                }
                                self.editor = nil
                            }
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .tint(NAVATheme.orange)
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private func noteCard(_ note: NAVANote) -> some View {
        Button {
            draft = note.text
            editor = NAVANoteEditor(noteID: note.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if note.isPinned {
                        Label("پین‌شده", systemImage: "pin.fill")
                            .font(NAVATheme.type(11))
                            .foregroundStyle(NAVATheme.orange)
                    } else {
                        Image(systemName: "text.alignright")
                            .foregroundStyle(NAVATheme.orange)
                    }
                    Spacer()
                    Text(note.createdAt, style: .date)
                        .font(NAVATheme.type(11))
                        .foregroundStyle(NAVATheme.muted)
                }
                Text(note.text)
                    .font(NAVATheme.type(15))
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 17) {
                    Image(systemName: "pencil")
                    Text("برای ویرایش لمس کن")
                        .font(NAVATheme.type(11))
                    Spacer()
                    Menu {
                        Button(note.isPinned ? "برداشتن پین" : "پین کردن", systemImage: note.isPinned ? "pin.slash" : "pin") {
                            store.togglePin(id: note.id)
                        }
                        ShareLink(item: note.text) {
                            Label("اشتراک متن", systemImage: "square.and.arrow.up")
                        }
                        Button("حذف یادداشت", systemImage: "trash", role: .destructive) {
                            store.deleteNote(id: note.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                    }
                    .accessibilityLabel("گزینه‌های یادداشت")
                }
                .foregroundStyle(NAVATheme.muted)
            }
            .padding(18)
            .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 21))
            .overlay {
                RoundedRectangle(cornerRadius: 21)
                    .strokeBorder(note.isPinned ? NAVATheme.orange.opacity(0.4) : NAVATheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(NAVAButtonStyle())
        .foregroundStyle(NAVATheme.white)
        .contextMenu {
            Button(note.isPinned ? "برداشتن پین" : "پین کردن") {
                store.togglePin(id: note.id)
            }
            Button("حذف", role: .destructive) {
                store.deleteNote(id: note.id)
            }
        }
    }
}
