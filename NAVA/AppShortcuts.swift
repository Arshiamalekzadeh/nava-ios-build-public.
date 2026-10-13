import AppIntents

/// Open the companion UI through the Action Button or Shortcuts.
struct OpenNAVAIntent: AppIntent {
    static var title: LocalizedStringResource = "Open NAVA"
    static var description = IntentDescription("Open your personal NAVA assistant.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Explicit Shortcuts action that saves a note without an AI API or chat session.
struct SaveNAVANoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Save NAVA Note"
    static var description = IntentDescription("Save text privately on this iPhone in NAVA.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Note")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$note) in NAVA")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let value = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return .result(dialog: "Nothing to save.")
        }
        await MainActor.run {
            NAVAStore().addNote(value)
        }
        return .result(dialog: "Saved in NAVA.")
    }
}

struct NAVAShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .orange }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenNAVAIntent(),
            phrases: ["Open \(.applicationName)", "Launch \(.applicationName)"],
            shortTitle: "Open NAVA",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: OpenNAVAVoiceIntent(),
            phrases: [
                "Talk to \(.applicationName)",
                "Open \(.applicationName) voice",
                "Start \(.applicationName)",
                "Listen with \(.applicationName)",
                "Ask \(.applicationName)"
            ],
            shortTitle: "Talk to NAVA",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: SaveNAVANoteIntent(),
            phrases: ["Save a note in \(.applicationName)"],
            shortTitle: "Save NAVA Note",
            systemImageName: "note.text"
        )
    }
}
