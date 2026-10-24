# NAVA 4.5.1 (46): voice and Island validation

Device report: iPhone 15 Pro, iOS 27. The Island is black and empty;
Persian recognition is inaccurate and speech does not submit after a pause.
The sideload/signing method has not yet been identified.

## Automated checks

Both build workflows compile and run `VoiceActivityDetectorTests.swift` and
the existing command parser tests before building the app and extension.
The new tests cover quiet speech followed by a pause, ambient noise without
speech, a single click, and the maximum length of a spoken turn.

## Physical device checks still required

1. Install build 46 with the embedded Widget Extension preserved and signed.
   In Settings > NAVA, allow microphone access and Live Activities.
2. Open NAVA diagnostics and reset the Live Activity. Switch through all six
   phases. Verify the orange orb in compact/minimal presentation, long-press
   to expand, and check the lock-screen content. If the whole surface is still
   blank, copy the installation/ActivityKit report and record the signing tool.
   A successful build does not validate iOS 27 device rendering or signing.
3. Select Small in the offline Persian model settings and explicitly approve
   the download. Compare the same Persian phrases against Base. No measured
   recognition improvement is claimed before that device comparison.
4. Enable continuous voice and automatic spoken responses. Enter Voice using
   the chat microphone. Speak quietly, pause for about 1.5 seconds, and check
   transcription, the spoken response, and automatic listening for a new turn.
5. Scroll during speech to verify metering continues in the common run-loop
   mode. Stop or close during model preparation or the microphone permission
   prompt: no delayed recording may begin after cancellation.
6. Play the voice test while idle. During recording it must be disabled so it
   cannot replace the recording audio session. The Island should return to
   ready after standalone playback ends.

The orb uses an opaque orange base and bounded rendering. This is a rendering
simplification, not proof that the reported blank Island has been reproduced.
