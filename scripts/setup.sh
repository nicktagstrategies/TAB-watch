#!/usr/bin/env bash
# One-shot bootstrap for the watch app on your Mac.
#
# Installs XcodeGen if missing, regenerates the Xcode project from
# project.yml, and opens it in Xcode. Runs idempotent — safe to re-run.
#
# Usage: ./scripts/setup.sh
set -euo pipefail

# Repo root no matter where this is invoked from.
cd "$(dirname "$0")/.."

need_xcode_path() {
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild not found. Install Xcode 26+ from the Mac App Store, launch it once to accept the license, then re-run this script." >&2
    exit 1
  fi
}

need_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Install from https://brew.sh first, then re-run." >&2
    exit 1
  fi
}

need_xcodegen() {
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "==> Installing XcodeGen via Homebrew"
    need_homebrew
    brew install xcodegen
  fi
}

need_xcode_path
need_xcodegen

echo "==> Generating TabWatch.xcodeproj from project.yml"
xcodegen generate

echo ""
echo "==> Done. Opening TabWatch.xcodeproj in Xcode."
echo ""
echo "Next steps inside Xcode:"
echo "  1. Select the project in the sidebar."
echo "  2. For BOTH the 'TabWatch Watch App' and 'TabWatch Widget' targets:"
echo "     Signing & Capabilities → Team → pick your Apple ID team."
echo "  3. Pick your watch as the run destination, hit ⌘R."
echo ""
echo "If something breaks: ./scripts/build.sh > build.log 2>&1 — then paste"
echo "the last ~50 lines of build.log into the chat."
echo ""

open TabWatch.xcodeproj
