# NAVA 4.6.0 (47): live Persian input

Recognition now takes live 16 kHz mono microphone buffers from the shared
AVAudioEngine voice-processing input. It decodes an in-memory hypothesis as more audio arrives;
Voice no longer waits for an M4A recording to be stopped or manually sent.
Only the final decode of a completed turn executes an action. Voice mode
always submits turns automatically; the obsolete manual/continuous toggle
has been removed. Archive recording remains a separate mode.

One decoder task serializes hypotheses and final decoding. A generation token
rejects late microphone callbacks and inference results after cancellation.
The next turn drains cancelled inference before reusing the model. Silence
retains a bounded pre-roll buffer and keeps listening. A final segment with
no recognized text resumes listening without executing a previous hypothesis.
Reply playback uses a player node in the same engine as the echo-cancelled
input. Sustained voiced input stops playback, cancels the outstanding reply,
and retains the user's audio prefix. Reply-generation tokens reject delayed
TTS output, completion callbacks and cancelled AI replies. The Persian TTS
renderer serializes inference and caches its loaded model between replies.

Device controls include brightness and flashlight. Volume uses an explicitly
configured Shortcuts workflow. Matching, one-use callback tokens allow a
voice-initiated shortcut to return to the conversation; cancellation/error
callbacks do not assert that the requested volume was applied. Brightness
and torch requests use local iOS APIs, not model-generated tools. The settings
screen also contains a standard MPVolumeView for direct manual volume changes.

## CI

Run command parser, VAD, and live buffer tests before simulator/device builds.
Live buffer tests cover samples being available during speech, short pauses,
automatic turn completion, frozen final audio, prolonged idle, subsequent
speech, fresh windows and the long-turn memory bound. Added checks cover
short-noise rejection, one interruption event per reply, assistant-name calls,
URL encoding, fractional volume and stale/expired/ambiguous callback rejection.
These latest changes and added tests are awaiting GitHub Actions validation:
the user has now requested the final GitHub build. Validate all tests and
the iPhone IPA packaging before distributing the new artifact.

## Device acceptance still required

- On iPhone 15 Pro, enter Voice using the chat microphone. Speak a sentence
  lasting at least 5 seconds: partial Persian text must appear before stopping.
  Try Base first for latency, then compare Small for accuracy and speed.
- Pause roughly 1.5 seconds. Exactly one final command/answer must execute;
  partial text must never execute a reminder, note, URL or AI request.
- With spoken replies enabled, wait until playback ends. A second sentence
  must be accepted automatically without a send button or another mic tap.
- While a long answer plays, interrupt it with a complete new sentence. Output
  must stop, the beginning of the interruption must remain in the transcript,
  and only the new final sentence may execute. Repeat during response synthesis
  and an in-flight AI request. A late old result must never resume playback.
- Let a complete answer play without speaking. Its own speaker audio must not
  trigger interruption or become a command. Compare speaker volume, headphones
  and Bluetooth; acoustic echo-cancellation effectiveness is not statically verified.
- Call "نوا" in an open conversation: it should answer, then keep listening.
- Try brightness, torch on/off and volume. Create the volume shortcut using
  the in-app guide. Check success/cancel/error returns, and that old callbacks
  do not start a new microphone session. After locking, iOS may restore brightness.
- Leave it quiet for over a minute, then speak. It should still accept speech.
- Close during preparation, microphone permission, live inference, and final
  inference. No late text, command, recording or playback should start.
- Switch to recording mode and back; neither recorder may compete with the
  other. Check built-in microphone, Bluetooth routing and permission denial.
- An audio-session interruption should surface a failure rather than showing
  a microphone that appears active after capture has stopped.

The implementation supports local incremental transcription and interruption
during reply generation/playback. It does not provide an always-on custom
wake word outside the foreground app. Hypotheses can be revised; actual delay,
accuracy and echo rejection depend on device/model/route. A build alone cannot
verify live microphone latency, Persian accuracy or the reported blank Island.
