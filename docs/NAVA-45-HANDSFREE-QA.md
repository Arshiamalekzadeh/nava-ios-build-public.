# NAVA 4.5 – Hands-free Persian Voice and Dynamic Island QA

Entering Voice selects spoken-command mode and, if enabled, starts listening in the foreground. During an active hands-free session, the native microphone records an M4A chunk. After consecutive speech-level samples and about 1.45 seconds of quiet, the chunk is processed by offline WhisperKit with language fa. The recognized text goes through local NAVA commands or, for unsupported free-form prompts and only with separate valid account authorization, the text AI. Piper produces Persian speech offline; when playback ends, the microphone resumes automatically.

This is automatic sequential turn-taking, not simultaneous streaming duplex audio, official ChatGPT Voice, or a system Siri replacement. No send button is required after each spoken phrase. A clear End Conversation button stops the mic and cancels any pending audible reply. If no speech is detected for 35 seconds, the session stops to avoid indefinite silent recordings. Ambient noise and quiet speech can affect simple audio-level detection; adjust the sensitivity threshold in Settings.

## Diagnostic screenshots

iOS 27 screenshot showed Widget exists: true, Widget code resources: true, ActivityKit allowed: true, with Activity count: 0. This means no activity was running at the moment of inspection; it does not by itself prove an extension failure. Settings now has a direct Start Dynamic Island test. After touching the control, inspect the activity count and error. Even when the count is positive, the system ultimately controls the exact Dynamic Island/Lock Screen presentation. The app never silently creates a new Live Activity for a Ready-only or closing event.

## Shortcuts constraints

NAVA publishes the official Talk to NAVA, Open NAVA, Save NAVA Note App Intents, reindexes on app launch, and provides native ShortcutsLink and SiriTipView onboarding. iOS requires user permission to create personal Shortcuts or assign the Action Button, Back Tap, or Siri behavior. A free-signed sideload may affect Siri app-intent indexing. These settings cannot be silently modified.

## Physical iPhone tests

1. Install a successful NAVA 4.5.0 (45) IPA with both the host and WidgetKit extension signed; do not remove the old app if preserving local data.
2. Verify Whisper Base/Tiny was explicitly downloaded, and test the bundled Persian Piper TTS from Settings.
3. From Home open Voice. After permissions, say “نوا ساعت چنده” and stop talking. Without tapping Send, wait for the transcript and answer, then its audible Persian voice; the next turn should begin on its own.
4. Say a second command to verify automatic rearming; press End Conversation to stop recording.
5. Adjust microphone threshold in Settings for quiet speech or ambient noise.
6. Settings → Dynamic Island → Start → Diagnostics: inspect activity count and any error; check the island while locked and unlocked.
7. From Home → Siri launch, test Talk to NAVA; if not indexed, open Shortcuts and review NAVA actions and app permissions.
8. Confirm audio does not upload automatically and no recording happens when Voice is closed.

Passing Xcode compilation validates source/package integrity, not all microphone, sideload, model, Shortcut, and Dynamic Island runtime behavior.
