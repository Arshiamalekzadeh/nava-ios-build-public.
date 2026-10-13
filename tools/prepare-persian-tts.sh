#!/usr/bin/env bash
set -euo pipefail

# Download the publicly published Persian Piper model converted for sherpa-onnx.
# Distributed with its upstream MODEL_CARD and any accompanying license.
# This is real offline TTS data, not padding. Do not commit 60+ MB weights.
MODEL="vits-piper-fa_IR-gyro-medium"
SOURCE="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/${MODEL}.tar.bz2"
TARGET="Assets/PersianTTS"
if [[ -s "$TARGET/fa_IR-gyro-medium.onnx" && -s "$TARGET/tokens.txt" && -d "$TARGET/espeak-ng-data" ]]; then
  echo "Persian offline Piper model already prepared"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo "Downloading real Persian offline voice: $SOURCE"
curl --fail --location --retry 4 --retry-delay 5 --connect-timeout 30   --output "$WORK/model.tar.bz2" "$SOURCE"
tar -xjf "$WORK/model.tar.bz2" -C "$WORK"

SRC="$WORK/$MODEL"
test -s "$SRC/fa_IR-gyro-medium.onnx" || { echo "Missing Persian acoustic model"; exit 1; }
test -s "$SRC/tokens.txt" || { echo "Missing phoneme tokens"; exit 1; }
test -d "$SRC/espeak-ng-data" || { echo "Missing Persian eSpeak-ng phoneme data"; exit 1; }
test -s "$SRC/fa_IR-gyro-medium.onnx.json" || { echo "Missing model metadata"; exit 1; }

mkdir -p "$TARGET"
cp -R "$SRC/." "$TARGET/"
echo "Prepared offline Persian TTS files:"
du -sh "$TARGET"
ls -lh "$TARGET/fa_IR-gyro-medium.onnx" "$TARGET/tokens.txt"
