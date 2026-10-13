# NAVA 4.3: Persian Voice + Siri / Shortcuts reliability

## What was broken

In NAVA 4.2, Voice could show **«نوا در حال پاسخ است…»** while awaiting the chat model, without first displaying the recognized Persian transcript. The button labelled "Test NAVA Voice" also silently failed to speak because Apple's **fa-IR text-to-speech (TTS) voice is absent** on some iPhones. Whisper speech recognition was already a separate working engine, but text input and spoken output were conflated.

The existing **Talk to NAVA** App Shortcut would only open the Voice screen; it didn't automatically start the microphone. iOS may take time to index shortcuts after a free Apple ID sideload.

## Fixes in 4.3

- **Immediate transcript:** As soon as Whisper returns a recognized sentence, NAVA displays it in a persistent area above the microphone controls, *before* contacting the connected text-model or performing an iOS command.
- **Meaningful stages:** Listening, local transcription, checking local command, waiting for the model, and completion are distinct UI states. Slow text-model network requests now have a shorter request timeout.
- **Reliable microphone launch:** The `Talk to NAVA` App Intent opens the Voice scene and, if `nava.shortcutAutoListen` is enabled, starts Persian recording as soon as the app is foregrounded. The first Whisper download still requires consent; iOS still requires microphone permission.
- **Shortcuts registration:** An AppShortcutsProvider publishes Talk to NAVA, Open NAVA and Save NAVA Note automatically. A new onboarding screen shows the Apple Siri tip and a native **ShortcutsLink**, reindexes the actions and offers an in-app functional test.
- **Voice output:** Audio transcription ≠ text-to-speech. NAVA checks for available Persian AVSpeechSynthesisVoice resources, configures AVAudioSession for audible spoken output even with the mute switch enabled, and clearly reports if iOS doesn't provide a Persian voice. Text responses remain available.

## How to test

1. Install the new successful `4.3.0 (43)` unsigned IPA. Confirm the version in Sideloadly.
2. Open Settings → `موتور فارسی آفلاین · Whisper`; download Base or Tiny if needed.
3. Open Voice → `فرمان گفتاری` → say `نوا، ساعت چنده` → tap Stop. **Check that the on-screen «شنیدم» transcript appears before the response.** If there is no transcript, test Archive and record a 5-second Persian sentence first.
4. Open Home → `فراخوانی Siri`, then tap `تست Talk to NAVA همین حالا`. If the Whisper model is ready, NAVA should open and start recording (after existing microphone permission).
5. In the same screen, use Apple's native Shortcuts button to open the application's shortcut gallery and look for Talk to NAVA.
6. Say `Siri, talk to NAVA` where supported, or use Settings → Action Button / Accessibility → Touch → Back Tap to choose Talk to NAVA. **iOS does not let a sideloaded third-party app silently assign system buttons or replace Siri.**
7. Tap `تست صدای نوا`. If the device has a Persian system speech voice, it should speak; otherwise NAVA should display a specific unavailable-voice message and leave text responses usable.

## Honest limits

A good iPhone IPA build confirms Swift compilation, assets and WidgetKit packaging, **not** on-device microphone, model execution or Siri registration. iOS may restrict some App Shortcuts features for free-signed installations. ChatGPT Plus sign-in does **not** confer OpenAI Voice API or install Persian TTS voices. A separately implemented on-device Persian TTS engine or authorized external TTS service would be needed to guarantee spoken answers without a Persian system voice.
