# NAVA Personal OS 4.4 — voice OUTPUT and Dynamic Island device QA

## What is actually new

**Input:** Existing WhisperKit multilingual Core ML Base/Tiny hears Farsi and produces text. This already worked on the user's physical iPhone (recognized `سلام`).

**Output:** iOS 27 doesn't expose a usable `fa-IR` `AVSpeechSynthesisVoice` on the user device. NAVA 4.4 adds a **separate, real, offline Persian synthesizer**, based on upstream sherpa-onnx v1.13.8 + the published Piper Gyro Persian voice. This bundle contains ~63MB ONNX weights, phoneme tokens and eSpeak-ng pronunciation data, downloaded at *build time*. Speech is generated into a WAV file in app-local temporary storage on-device and played by AVAudioPlayer using the spoken-audio playback category. There is no API key, per-request charge or upload. The voice is a synthetic Persian voice that may have imperfect pronunciation; it is NOT the official ChatGPT Voice.

**Island:** NAVA 4.3 had a real bug: `LiveActivityManager.updateStatus` discarded the `phase` argument and defaulted every phase to `ready`. NAVA 4.4 now preserves the explicitly requested phase and reports actual ActivityKit states, installed extension bundle ID, version and whether signature resources are present. If signing strips/unregisters the WidgetKit extension, **Swift code cannot bypass Apple's Live Activities requirement**.

## Packaging QA (GitHub Actions)

- Use a **successful 4.4.0 (Build 44)** *device* job artifact: `NAVA-unsigned-iPhone-IPA`.
- Check that both iPhone and Simulator build compile.
- The IPA validation must verify `NAVA.app/PersianTTS/fa_IR-gyro-medium.onnx`, `tokens.txt`, `espeak-ng-data`, valid ActivityKit keys and `PlugIns/NAVAWidgetExtension.appex`.
- Host and Widget Extension version and build numbers must match 4.4.0 / 44.
- The IPA is unsigned. Sideloadly must sign **both** the app and embedded widget extension for the same Apple account/team. The extension is vital for system Dynamic Island and lock-screen Live Activities.

## Real iPhone voice playback tests

1. Install without deleting the current app to preserve local notes and memos. Keep enough free storage.
2. NAVA Settings → `استودیوی صدا`: look for `Piper فارسی روی آیفون نصب شده`.
3. Tap **تست صدای فارسی مستقل** with the physical iPhone's volume audible, even if Ring/Silent switch is on. You should hear a synthetic Persian greeting.
4. NAVA Voice → `فرمان گفتاری` → microphone → say `سلام` → Stop. Confirm Whisper transcript, text reply, `نوا در حال ساخت صدای فارسی است…`, then actual audible reply.
5. If silent, inspect `persianTTS.errorMessage` in Voice/Settings, test with Bluetooth temporarily off and raise media volume. Try sentence `سلام! من نوا هستم` via Settings to isolate TTS from the language model and microphone.
6. If it works but pronunciation is imperfect, that is a model-quality issue, not Apple Speech authorization.

## Dynamic Island fault isolation

1. Settings → NAVA → **Live Activities** ON (if visible), and ensure Lock Screen Live Activities is allowed on the device. Disable Focus modes or settings that suppress the activity during testing as needed.
2. NAVA → Settings → `تست Voice، Siri و Dynamic Island`. Scroll to **۳ · Dynamic Island** and tap **بازنشانی و ساخت Activity تازه**.
3. Inspect the diagnostic report (there is a Copy button). Verify:
   - `ActivityKit allowed: true`
   - `Widget exists: true`
   - `Widget point: com.apple.widgetkit-extension`
   - `Widget build: 44`
   - `Activity count: 1`
   - `Activity states: ... active`
   - `Widget code resources: true` where signing exposes them.
4. Lock the phone. Check **Lock Screen Live Activity**. Unlock. Check small Dynamic Island. Long-press it.
5. If Activity count is 1 and active but both island and Lock Screen are empty, likely extension registration/signature iOS 27 beta issue. Send the copied diagnostics and Sideloadly signing log. We cannot claim to replace Siri or force the system Island to render from app UI.
6. To avoid stale tests, tap `پایان آزمایش` before starting another test.

## Source and license provenance

- Sherpa runtime: https://github.com/k2-fsa/sherpa-onnx (Apache-2.0)
- Model: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-fa_IR-gyro-medium.tar.bz2
- Model card: https://huggingface.co/rhasspy/piper-voices/blob/main/fa/fa_IR/gyro/medium/MODEL_CARD . The model card points to its upstream dataset and does not assert a simple standalone license for the training data; preserve the bundled MODEL_CARD and check licensing before redistributing commercially.
