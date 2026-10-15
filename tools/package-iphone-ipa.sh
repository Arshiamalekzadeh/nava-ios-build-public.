#!/usr/bin/env bash
# NAVA unsigned iPhone packaging and real payload validation.
# XcodeGen/Xcode sometimes keep stale CFBundleShortVersionString in the
# generated Info.plist even after MARKETING_VERSION changes. This script
# stamps BOTH unsigned bundles from the release version before packaging.
set -euo pipefail

EXPECTED_VERSION="4.5.1"
EXPECTED_BUILD="46"
APP="build-device/Build/Products/Release-iphoneos/NAVA.app"
EXT="$APP/PlugIns/NAVAWidgetExtension.appex"
MODEL_DIR="$APP/PersianTTS"

fatal() { echo "::error::$*" >&2; exit 1; }
plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}
set_plist_value() {
    local plist="$1" key="$2" expected="$3" actual
    actual="$(plist_value "$plist" "$key")"
    echo "$plist: $key before packaging = ${actual:-<missing>}"
    if [[ "$actual" != "$expected" ]]; then
        echo "::warning::Correcting generated $key from '${actual:-<missing>}' to '$expected'"
        if [[ -n "$actual" ]]; then
            /usr/libexec/PlistBuddy -c "Set :$key $expected" "$plist"
        else
            /usr/libexec/PlistBuddy -c "Add :$key string $expected" "$plist"
        fi
    fi
    [[ "$(plist_value "$plist" "$key")" == "$expected" ]] ||
        fatal "Could not set $key to $expected in $plist"
}

[[ -d "$APP" ]] || fatal "NAVA.app was not built"
[[ -f "$APP/Info.plist" ]] || fatal "Missing host Info.plist"
[[ -d "$EXT" && -f "$EXT/Info.plist" ]] ||
    fatal "Missing embedded Dynamic Island widget extension"
[[ "$(plist_value "$APP/Info.plist" CFBundleIdentifier)" == "com.arshia.nava" ]] ||
    fatal "Unexpected host application bundle identifier"

for bundle in "$APP" "$EXT"; do
    set_plist_value "$bundle/Info.plist" CFBundleShortVersionString "$EXPECTED_VERSION"
    set_plist_value "$bundle/Info.plist" CFBundleVersion "$EXPECTED_BUILD"
done

[[ "$(plist_value "$APP/Info.plist" NSSupportsLiveActivities)" == "true" ]] ||
    fatal "NSSupportsLiveActivities missing or disabled"
[[ "$(plist_value "$EXT/Info.plist" NSExtension:NSExtensionPointIdentifier)" == "com.apple.widgetkit-extension" ]] ||
    fatal "Not a WidgetKit extension"
[[ "$(plist_value "$APP/Info.plist" CFBundleURLTypes:0:CFBundleURLSchemes:0)" == "nava" ]] ||
    fatal "Missing nava:// URL scheme"

for track in EmberRain StillSpace NightDrive; do
    find "$APP" -name "$track.wav" -print -quit | grep -q . ||
        fatal "Missing actual playable Focus track: $track"
done

[[ -s "$MODEL_DIR/fa_IR-gyro-medium.onnx" ]] ||
    fatal "Real Persian Piper voice model missing from NAVA IPA"
[[ -s "$MODEL_DIR/tokens.txt" ]] || fatal "Persian phoneme tokens missing"
[[ -d "$MODEL_DIR/espeak-ng-data" ]] || fatal "eSpeak-ng data missing"
[[ -s "$MODEL_DIR/fa_IR-gyro-medium.onnx.json" ]] ||
    fatal "Piper acoustic voice model configuration missing"

echo "Bundled Persian TTS bytes:"
du -sh "$MODEL_DIR" || true
echo "Embedded dynamic island extension:"
du -sh "$EXT" || true

rm -rf Payload NAVA-unsigned-iPhone.ipa
mkdir -p Payload
ditto "$APP" "Payload/NAVA.app"
zip -q -r -y NAVA-unsigned-iPhone.ipa Payload
unzip -t NAVA-unsigned-iPhone.ipa | tail -n 1
ls -lh NAVA-unsigned-iPhone.ipa

IPA_BYTES="$(stat -f%z NAVA-unsigned-iPhone.ipa)"
echo "IPA size: $IPA_BYTES bytes"
[[ "$IPA_BYTES" -ge 5242880 ]] || fatal "IPA smaller than 5 MiB"
echo "NAVA $EXPECTED_VERSION ($EXPECTED_BUILD) packaged successfully with WidgetKit and offline Persian Piper."
