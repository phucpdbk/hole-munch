# Android release — Hole Munch

This pipeline builds the Godot game, not the older Capacitor project at the repository root.
The checked-in Android preset remains an installable debug APK for local testing.
`tools/build-android-release.ps1` applies production overrides in memory and exports a signed AAB.
No store upload or account creation is performed by these scripts.

## Before the first production build

1. Choose the permanent package ID. The example uses `com.phucpdbk.holemunch`; confirm it is yours and available before creating the Play listing. Changing it later creates a separate app. Prototype saves do not migrate to a different package.
2. Create and verify your Google Play developer account and create the app listing.
3. In AdMob create the Android app, then one rewarded unit and one interstitial unit. Link the published store listing when available. In **Privacy & messaging**, configure and publish the applicable messages. The SDK cannot publish those messages for you.
4. Copy `tools/release-settings.example.json` to `builds/release-settings.json`; fill the three AdMob IDs. These IDs are public identifiers, not signing secrets. Release builds reject empty IDs and Google's sample publisher ID.
5. Create an upload keystore (instructions below). Enroll in Play App Signing when uploading. Back up the upload key and password securely, separately from the repo.
6. Publish the updated root `privacy.html` at `https://phucpdbk.github.io/hole-munch/privacy.html` before submission. The local edit is not automatically deployed. Verify the live text/date and set the same URL in Play and AdMob.

The proposed audience is general, not specifically directed to under-13 children. This is a product decision, not a replacement for Play's target-audience questionnaire or IARC content rating. If the actual design/marketing targets children or a mixed audience, stop and implement the relevant age/ads controls before release. Do not select an older audience merely to avoid those requirements. G-rated ad content alone is not a children's-compliance mechanism.

## Create the upload key locally

Run this yourself in a local PowerShell terminal; keytool prompts for the password and certificate details. Do not paste passwords in chat, source files or command arguments. Use the same key/store password (Godot supplies one password).

```powershell
New-Item -ItemType Directory -Force godot/builds | Out-Null
& 'C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe' -genkeypair -v -keystore godot/builds/hole-munch-upload.jks -alias hole-munch-upload -keyalg RSA -keysize 3072 -validity 10000
```

Keep this key across updates. Do not regenerate it for every build. `.jks`, `.keystore` and `godot/builds/` are ignored by Git. The script refuses the standard Android debug alias/key filename.

## Build

Prerequisites: Godot 4.7.1 + matching Android export templates/Gradle template, JDK 17+, Android SDK platform 36 and build tools, and the AdMob **release** AARs installed through AdMob Manager. A fresh clone must restore the ignored AARs. Gradle may need network access for dependencies.

```powershell
$env:HOLE_ANDROID_KEYSTORE = (Resolve-Path godot/builds/hole-munch-upload.jks).Path
$env:HOLE_ANDROID_KEY_ALIAS = 'hole-munch-upload'
$releasePassword = Read-Host 'Upload keystore password' -AsSecureString
$releaseCredential = [pscredential]::new('upload', $releasePassword)
$env:HOLE_ANDROID_KEYSTORE_PASSWORD = $releaseCredential.GetNetworkCredential().Password
try {
    & godot/tools/build-android-release.ps1 -CheckOnly
    & godot/tools/build-android-release.ps1
} finally {
    Remove-Item Env:HOLE_ANDROID_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    $releaseCredential = $null
    $releasePassword = $null
}
```

Output: `builds/hole-munch-release.aab`, signed using the upload key. The script verifies the JAR signature and prints a SHA-256 hash. Use Play internal testing first. Each later upload needs a higher `version_code`.

Release changes:
- Target API 36, ARM64, AAB, production package/name/version and release signing.
- Production AdMob IDs injected into the manifest/runtime project settings; debug uses test ad units.
- The prototype GitHub APK update checker runs in debug only.
- No signing password is stored in project settings or export presets. Avoid verbose export logging because build tools can print command arguments.
- Builds and tooling are excluded from resource scanning with `.gdignore`.

## Consent implementation

Every launch refreshes UMP state before requesting ads. When available, the native `can_request_ads` gate is used. The installed Poing 5.1 wrapper does not expose it, so the fallback accepts only a **fresh** UMP `NOT_REQUIRED` or `OBTAINED` status. Refresh errors fail closed even if a previous-session decision might otherwise be usable; gameplay continues. This deliberately favors privacy over ad availability.

The Privacy button is on the home and pause screens. Advertising choices appears only when UMP reports the privacy-options form is required; otherwise the player can retry the consent refresh. Opening the form invalidates cached ads, pending responses and retries so older requests cannot overwrite new choices. UMP's obtained status means the choices have been collected, not that the player agreed to personalization. Google applies those choices to subsequent requests.

No app-level consent string is persisted. G-rated ad content is requested; the app does not falsely flag every request as child-directed. Debug units stay separate from production units. Do not click your own live ads while testing.

## Verification

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path godot --editor --script res://tools/check_privacy.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path godot -- --smoke
python godot/tools/check_android_native.py godot/builds/hole-munch-release.aab
```

The native check inspects every ELF load segment for 16 KiB alignment. Also validate generated APKs with `zipalign -c -P 16 4`, Play's bundle checks, and an Android device/emulator in 16 KiB mode. Passing ELF alignment alone does not prove runtime compatibility.

Manual internal-testing checks still required:
- Fresh install in a consent-required region with registered test devices and UMP debug geography; accept and reject personalization, restart, reopen privacy choices.
- Offline first launch, refresh failure, form failure, and reconnect/retry: gameplay remains usable, no ads before the gate allows them.
- Changing choices while a request is in flight: old ads do not reappear. Rewarded failure pays nothing; successful reward pays once.
- Background/resume during an ad, home/pause/privacy navigation, audio restoration and save persistence.
- Inspect final manifest, target API, permissions, production app/ad IDs, signing certificate and package; check release AARs and device behavior.
- Verify public privacy URL, developer/support identity, Data safety, target audience, ads declaration, content rating and AdMob message configuration.

## Play Data safety draft — review against the final SDK build

The current Android build includes AdMob, and its merged manifest includes advertising ID permissions. Do **not** answer “no data collected” merely because the game has no account or developer backend.

Review the installed Google Mobile Ads SDK disclosure for approximate location (IP-derived), device/other identifiers, app interactions and diagnostics/performance data. Map each category to collection/sharing, purpose, required/optional processing and retention using the actual SDK configuration. Consent does not automatically make every data category optional, and non-personalized ads can still process data. Adding mediation/analytics/leaderboards requires a new review.

Local save data remains on-device; clearing app data/uninstalling removes it. No in-game accounts are created, so account-deletion flows are not currently applicable. The public policy includes the support email and links to Google's controls for data Google processes.

References checked 2026-10-06:
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developers.google.com/admob/android/privacy
- https://developers.google.com/admob/android/privacy/play-data-disclosure
- https://developer.android.com/guide/practices/page-sizes

## Current limits

No production AdMob IDs, publisher account configuration or upload key have been supplied yet. A production AAB is intentionally blocked until these exist. Code/configuration checks and a debug APK cannot establish that live UMP messages, ad serving, Play review or physical-device QA are complete. The changed policy still needs publication at its public URL.

Local verification on 2026-10-06: gameplay smoke and 15 consent/exporter checks passed; the final debug APK targets API 36, passes APK v2 signature verification and ZIP 16 KiB alignment, and both ARM64 ELF libraries pass the native check. Privacy menu/dialog were rendered and inspected at 960×540. Godot's scripted editor export reported success but emitted shutdown RID warnings and remained running; the completed exporter was stopped after independent APK verification. This is not a verified production AAB or device consent test.
