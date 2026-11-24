#!/usr/bin/env bash
# Downloads the ML Kit Latin text recognition model bundle for iOS.
# google_mlkit_text_recognition uses Swift Package Manager, which cannot copy this bundle
# into the app automatically. After running this script, add ios/Runner/LatinOCRResources.bundle
# to the Runner target in Xcode (Build Phases > Copy Bundle Resources).
set -euo pipefail
cd "$(dirname "$0")/../Runner"
VERSION="9.0.3"
curl -fL -o LatinOCRResources.bundle.zip \
  "https://github.com/d-date/google-mlkit-swiftpm/releases/download/${VERSION}/LatinOCRResources.bundle.zip"
rm -rf LatinOCRResources.bundle
unzip -q LatinOCRResources.bundle.zip
rm LatinOCRResources.bundle.zip
echo "Downloaded $(pwd)/LatinOCRResources.bundle"
