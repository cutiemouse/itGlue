#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
  echo "Study Guardian requires a Mac with Xcode 16+ and macOS 14+. Native verification cannot run here." >&2
  exit 1
fi
xcodebuild -project StudyGuardian.xcodeproj -scheme StudyGuardian -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath DerivedData \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- build
xcodebuild -project StudyGuardian.xcodeproj -scheme StudyGuardian -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath DerivedData \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- test
