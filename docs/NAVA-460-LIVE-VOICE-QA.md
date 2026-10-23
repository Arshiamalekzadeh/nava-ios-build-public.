# NAVA 4.6.0 (47): live Persian input

Recognition now takes live 16 kHz mono microphone buffers from WhisperKit's
AudioProcessor. It decodes an in-memory hypothesis as more audio arrives;
Voice no longer waits for an M4A recording to be stopped or manually sent.
Only the final decode of a completed turn executes an action. Voice mode
always submits turns automatically; the obsolete manual/continuous toggle
has been removed. Archive recording remains a separate mode.

One decoder task serializes hypotheses and final decoding. A generation token
rejects late microphone callbacks and inference results after cancellation.
The next turn drains cancelled inference before reusing the model. Silence
retains a bounded pre-roll buffer and keeps listening. A final segment with
no recognized text resumes listening without executing a previous hypothesis.

## CI

Run command parser, VAD, and live buffer tests before simulator/device builds.
Live buffer tests cover samples being available during speech, short pauses,
automatic turn completion, frozen final audio, prolonged idle, subsequent
speech, fresh windows and the long-turn memory bound.

## Device acceptance still required

- On iPhone 15 Pro, enter Voice using the chat microphone. Speak a sentence
  lasting at least 5 seconds: partial Persian text must appear before stopping.
  Try Base first for latency, then compare Small for accuracy and speed.
- Pause roughly 1.5 seconds. Exactly one final command/answer must execute;
  partial text must never execute a reminder, note, URL or AI request.
- With spoken replies enabled, wait until playback ends. A second sentence
  must be accepted automatically without a send button or another mic tap.
- Leave it quiet for over a minute, then speak. It should still accept speech.
- Close during preparation, microphone permission, live inference, and final
  inference. No late text, command, recording or playback should start.
- Switch to recording mode and back; neither recorder may compete with the
  other. Check built-in microphone, Bluetooth routing and permission denial.
- An audio-session interruption should surface a failure rather than showing
  a microphone that appears active after capture has stopped.

This is incremental on-device recognition with automatic conversational turns.
It is not full-duplex speech-to-speech: microphone capture stops during final
decoding and reply playback, so interrupting NAVA mid-reply is not implemented.
Hypotheses can be revised; actual delay and accuracy depend on device/model.
An iOS build alone cannot verify live microphone latency or Persian accuracy.
