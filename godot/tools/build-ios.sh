#!/bin/bash
set -euo pipefail

# Run with bash; executable bits need not survive copying from Windows.
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'iOS export needs macOS + Xcode. Run export_ios.gd --check for a config check on Windows.' >&2
  exit 1
fi
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$godot_bin" ]]; then
  echo 'Install Godot 4.7.1 in Applications, or set GODOT_BIN to its executable.' >&2
  exit 1
fi
version="$("$godot_bin" --version)"
if [[ "$version" != 4.7.1.stable* ]]; then
  echo "Expected Godot 4.7.1 stable; found $version. Use matching editor and export templates." >&2
  exit 1
fi
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path >/dev/null
template="$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable/ios.zip"
if [[ ! -f "$template" ]]; then
  echo 'In Godot: Editor > Manage Export Templates > Download and Install (4.7.1).' >&2
  exit 1
fi
if [[ ! "${HOLE_IOS_TEAM_ID:-}" =~ ^[A-Z0-9]{10}$ ]]; then
  echo 'Set HOLE_IOS_TEAM_ID to your 10-character Apple Team ID, then run again.' >&2
  exit 1
fi
export HOLE_IOS_TEAM_ID
export HOLE_IOS_BUNDLE_ID="${HOLE_IOS_BUNDLE_ID:-org.holemunch.pocketcity.prototype}"
# Every export gets its own directory so Xcode edits are never deleted.
mkdir -p "$project_root/builds/ios"
output_dir="$(mktemp -d "$project_root/builds/ios/export-XXXXXX")"
export HOLE_IOS_OUTPUT="$output_dir/HoleMunch.ipa"
"$godot_bin" --headless --path "$project_root" --editor --import --quit
"$godot_bin" --headless --path "$project_root" --editor --script res://tools/export_ios.gd
xcode_project="$output_dir/HoleMunch.xcodeproj"
if [[ ! -d "$xcode_project" ]]; then
  echo "Export did not create the expected project: $xcode_project" >&2
  exit 1
fi
printf '\nXcode project: %s\nChoose Team, select your iPhone, then Run. No signed IPA has been built.\n' "$xcode_project"
if [[ "${HOLE_IOS_OPEN_XCODE:-1}" == 1 ]]; then open "$xcode_project"; fi
