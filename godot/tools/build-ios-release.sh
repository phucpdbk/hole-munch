#!/bin/bash
set -euo pipefail

# Signed App Store IPA from the Godot project (see APP-STORE.md). Needs macOS,
# Xcode signed in to your Apple account, Godot 4.7.1 and its iOS template.
# Usage: HOLE_IOS_TEAM_ID=ABCDE12345 bash tools/build-ios-release.sh
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'App Store export needs macOS + Xcode. On Windows run export_ios_release.gd with --check.' >&2
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
  echo "Expected Godot 4.7.1 stable; found $version." >&2
  exit 1
fi
xcodebuild -version
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
export HOLE_RELEASE_SETTINGS="${HOLE_RELEASE_SETTINGS:-$project_root/builds/release-settings.json}"
if [[ ! -f "$HOLE_RELEASE_SETTINGS" ]]; then
  echo 'Create builds/release-settings.json from tools/release-settings.example.json.' >&2
  exit 1
fi
mkdir -p "$project_root/builds/ios"
output_dir="$(mktemp -d "$project_root/builds/ios/release-XXXXXX")"
export HOLE_IOS_OUTPUT="$output_dir/HoleMunch.ipa"
"$godot_bin" --headless --path "$project_root" --editor --import --quit
"$godot_bin" --headless --path "$project_root" --editor --script res://tools/export_ios_release.gd
if [[ ! -f "$HOLE_IOS_OUTPUT" ]]; then
  echo "No IPA at $HOLE_IOS_OUTPUT. Open $output_dir/HoleMunch.xcodeproj and use Product > Archive." >&2
  exit 1
fi
shasum -a 256 "$HOLE_IOS_OUTPUT"
printf '\nSigned IPA: %s\nUpload it with Transporter or: xcrun altool --upload-app -t ios -f <ipa> --apiKey ... --apiIssuer ...\n' "$HOLE_IOS_OUTPUT"
