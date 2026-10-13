# NAVA iOS — Public Build Mirror

This public repository contains a **clean, source-only snapshot** of NAVA iOS for GitHub Actions IPA builds. It intentionally does not include the private repository's git history, credentials, signing profiles, or personal files.

**Important:** Only the unsigned iPhone IPA is produced by this repository. To install it, the owner must sideload and sign the app and WidgetKit extension using their own Apple account. The NAVA app's ChatGPT integration requires eligible account permissions; the app cannot replace Siri.

See the iOS Actions workflow in `.github/workflows/ios-unsigned-ipa.yml` for reproducible builds.
