import SwiftUI

private struct NAVAReminderEditor: Identifiable {
    let id = UUID()
    let reminderID: UUID?
}

struct RemindersView: View {
    @EnvironmentObject private var store: NAVAStore
    @State private var editor: NAVAReminderEditor?
    @State private var title = ""
    @State private var date = Date().addingTimeInterval(3600)
    @State private var filter = 0
    @State private var query = ""
    @State private var isSaving = false
    @State private var errorText: String?

    private var listed: [NAVAReminder] {
        (filter == 0 ? store.activeReminders : store.completedReminders)
            .filter { query.isEmpty || $0.title.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NAVATheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        HStack(spacing: 12) {
                            stat("در انتظار", value: store.activeReminders.count, icon: "bell.badge")
                            stat("انجام‌شده", value: store.completedReminders.count, icon: "checkmark.circle")
                        }
                        .padding(.bottom, 10)

                        Picker("نمایش", selection: $filter) {
                            Text("در انتظار").tag(0)
                            Text("تکمیل‌شده").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)

                        if listed.isEmpty {
                            NAVAEmptyState(
                                icon: filter == 0 ? "checkmark.seal" : "checkmark.circle",
                                title: filter == 0 ? "کار عقب‌افتاده‌ای اینجا نیست" : "هنوز کاری تکمیل نشده",
                                subtitle: "با + می‌تونی یادآوری تازه بسازی."
                            )
                            .frame(minHeight: 300)
                        } else {
                            ForEach(listed) { reminder in
                                reminderCard(reminder)
                            }
                        }
                    }
                    .padding(18)
                }
                .searchable(text: $query, prompt: "جستجو در یادآورها")
            }
            .navigationTitle("یادآورها")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        title = ""
                        date = Date().addingTimeInterval(3600)
                        editor = NAVAReminderEditor(reminderID: nil)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 23))
                    }
                    .tint(NAVATheme.orange)
                }
            }
            .sheet(item: $editor) { item in
                NavigationStack {
                    Form {
                        Section("موضوع") {
                            TextField("مثلاً جلسه ساعت ۴", text: $title)
                        }
                        Section("زمان اعلان") {
                            DatePicker(
                                "زمان",
                                selection: $date,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                        Section {
                            Label("اعلان در زمان انتخاب‌شده روی همین آیفون نمایش داده می‌شه.", systemImage: "lock.shield")
                                .font(NAVATheme.type(12))
                                .foregroundStyle(NAVATheme.muted)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(NAVATheme.background.ignoresSafeArea())
                    .navigationTitle(item.reminderID == nil ? "یادآور جدید" : "ویرایش یادآور")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("انصراف") { editor = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(isSaving ? "ثبت..." : "ذخیره") {
                                Task {
                                    isSaving = true
                                    defer { isSaving = false }
                                    do {
                                        if let id = item.reminderID {
                                            try await store.updateReminder(id: id, title: title, date: date)
                                        } else {
                                            try await store.addReminder(title: title, date: date)
                                        }
                                        editor = nil
                                    } catch {
                                        errorText = error.localizedDescription
                                    }
                                }
                            }
                            .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .tint(NAVATheme.orange)
                }
            }
            .alert("خطا در یادآور", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("باشه") { errorText = nil }
            } message: { Text(errorText ?? "") }
        }
    }

    private func stat(_ label: String, value: Int, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(NAVATheme.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(label)
                    .font(NAVATheme.type(11))
                    .foregroundStyle(NAVATheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func reminderCard(_ reminder: NAVAReminder) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.completeReminder(id: reminder.id, completed: !reminder.isCompleted) }
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .light))
                    .foregroundStyle(reminder.isCompleted ? NAVATheme.sand : NAVATheme.orange)
            }
            .accessibilityLabel(reminder.isCompleted ? "علامت‌گذاری به‌عنوان انجام‌نشده" : "تکمیل یادآور")

            VStack(alignment: .leading, spacing: 8) {
                Text(reminder.title)
                    .font(NAVATheme.type(15, weight: .medium))
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? NAVATheme.muted : NAVATheme.white)
                    .lineLimit(3)
                Label {
                    Text(reminder.date, format: .dateTime.day().month().year().hour().minute())
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(NAVATheme.type(11))
                .foregroundStyle(!reminder.isCompleted && reminder.date < Date() ? NAVATheme.orange : NAVATheme.muted)
            }
            Spacer(minLength: 0)
            Menu {
                if !reminder.isCompleted {
                    Button("۱۰ دقیقه بعد", systemImage: "clock.arrow.circlepath") {
                        snooze(reminder, minutes: 10)
                    }
                    Button("یک ساعت بعد", systemImage: "clock") {
                        snooze(reminder, minutes: 60)
                    }
                    Button("ویرایش", systemImage: "pencil") {
                        title = reminder.title
                        date = max(reminder.date, Date().addingTimeInterval(3600))
                        editor = NAVAReminderEditor(reminderID: reminder.id)
                    }
                }
                Button(reminder.isCompleted ? "بازگرداندن" : "تکمیل", systemImage: "checkmark.circle") {
                    Task { await store.completeReminder(id: reminder.id, completed: !reminder.isCompleted) }
                }
                Button("حذف", systemImage: "trash", role: .destructive) {
                    store.deleteReminder(id: reminder.id)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 44)
                    .foregroundStyle(NAVATheme.sand)
            }
        }
        .padding(17)
        .background(NAVATheme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(NAVATheme.border, lineWidth: 1)
        }
    }

    private func snooze(_ reminder: NAVAReminder, minutes: Int) {
        Task {
            do {
                try await store.snoozeReminder(id: reminder.id, minutes: minutes)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
