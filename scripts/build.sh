#!/usr/bin/env bash
# Compile-only build check. Mirrors the GitHub Actions CI command so
# local failures match remote failures. Signing disabled since no
# device target — this is a "does it compile?" gate, not an install.
#
# Usage: ./scripts/build.sh
#        ./scripts/build.sh > build.log 2>&1   # pipe everything to a file
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen missing. Run ./scripts/setup.sh first." >&2
  exit 1
fi

echo "==> Regenerating TabWatch.xcodeproj"
xcodegen generate

echo "==> Building TabWatch Watch App scheme for generic watchOS"

# xcbeautify makes failures readable; fall through to raw output if
# it's not installed.
FORMATTER="cat"
if command -v xcbeautify >/dev/null 2>&1; then
  FORMATTER="xcbeautify --renderer terminal"
fi

set -o pipefail
xcodebuild \
  -project TabWatch.xcodeproj \
  -scheme "TabWatch Watch App" \
  -destination "generic/platform=watchOS" \
  -skipPackagePluginValidation \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build \
  | $FORMATTER
