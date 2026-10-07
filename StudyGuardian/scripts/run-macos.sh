#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
  echo "Study Guardian is a native macOS app. Open StudyGuardian.xcodeproj on a Mac with Xcode 16+ to run it." >&2
  exit 1
fi
xcodebuild -project StudyGuardian.xcodeproj -scheme StudyGuardian -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath DerivedData \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- build
open DerivedData/Build/Products/Debug/StudyGuardian.app
