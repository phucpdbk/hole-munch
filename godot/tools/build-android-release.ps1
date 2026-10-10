param(
    [string]$Godot = 'Godot_v4.7.1-stable_win64_console.exe',
    [string]$AndroidSdk = 'C:/android',
    [string]$JavaSdk = 'C:/Program Files/Android/Android Studio/jbr',
    [string]$Settings = '',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$Settings) { $Settings = Join-Path $projectRoot 'builds/release-settings.json' }
if (!(Test-Path -LiteralPath $Settings)) {
    throw 'Create godot/builds/release-settings.json from tools/release-settings.example.json and fill in your AdMob IDs. See ANDROID-RELEASE.md.'
}
$releaseConfig = Get-Content -LiteralPath $Settings -Raw | ConvertFrom-Json
if ($releaseConfig.package_id -notmatch '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' -or $releaseConfig.package_id -match 'prototype|example') { throw 'Choose a permanent reverse-DNS package_id (no prototype/example).' }
if (!$releaseConfig.app_name -or $releaseConfig.app_name.Length -gt 30) { throw 'app_name must have 1–30 characters.' }
if ($releaseConfig.version_code -isnot [long] -and $releaseConfig.version_code -isnot [int]) { throw 'version_code must be an integer.' }
if ($releaseConfig.version_code -lt 13 -or $releaseConfig.version_code -gt 2100000000) { throw 'version_code must be 13–2100000000, and greater than your last uploaded build.' }
if ($releaseConfig.version_name -notmatch '^\d+\.\d+\.\d+$') { throw 'version_name must be a release version such as 1.0.0.' }
if ($releaseConfig.audience -ne 'general_not_child_directed') { throw 'This release pipeline supports a general audience, not a child-directed or mixed-audience release. Review audience settings first.' }
foreach ($field in @('admob_app_id', 'rewarded_unit', 'interstitial_unit')) {
    $pattern = if ($field -eq 'admob_app_id') { '^ca-app-pub-\d{16}~\d{10}$' } else { '^ca-app-pub-\d{16}/\d{10}$' }
    if ($releaseConfig.$field -notmatch $pattern -or $releaseConfig.$field -match '3940256099942544') { throw "$field must be your own production AdMob ID, not a placeholder/test ID." }
}
if ($releaseConfig.rewarded_unit -eq $releaseConfig.interstitial_unit) { throw 'Rewarded and interstitial require different ad units.' }
foreach ($kind in @('ads', 'core')) {
    $library = Join-Path $projectRoot "addons/admob/android/bin/ads/libs/poing-godot-admob-$kind-release.aar"
    if (!(Test-Path -LiteralPath $library)) { throw "Missing AdMob release library: $library. Install Android libraries through AdMob Manager." }
}
foreach ($file in @((Join-Path $AndroidSdk 'platforms/android-36/android.jar'), (Join-Path $JavaSdk 'bin/keytool.exe'), (Join-Path $projectRoot 'android/build/build.gradle'))) {
    if (!(Test-Path -LiteralPath $file)) { throw "Missing build dependency: $file" }
}
foreach ($name in @('HOLE_ANDROID_KEYSTORE', 'HOLE_ANDROID_KEY_ALIAS', 'HOLE_ANDROID_KEYSTORE_PASSWORD')) {
    if (![Environment]::GetEnvironmentVariable($name)) { throw "Set $name in this shell (do not put signing credentials in the settings JSON)." }
}
if (!(Test-Path -LiteralPath $env:HOLE_ANDROID_KEYSTORE -PathType Leaf)) { throw 'Upload keystore does not exist.' }
if ($env:HOLE_ANDROID_KEY_ALIAS -eq 'androiddebugkey' -or [IO.Path]::GetFileName($env:HOLE_ANDROID_KEYSTORE) -eq 'debug.keystore') { throw 'A debug keystore cannot sign a production release.' }
# Password stays in the environment, never in a command-line argument or log.
& (Join-Path $JavaSdk 'bin/keytool.exe') -list -keystore $env:HOLE_ANDROID_KEYSTORE -alias $env:HOLE_ANDROID_KEY_ALIAS -storepass:env HOLE_ANDROID_KEYSTORE_PASSWORD *> $null
if ($LASTEXITCODE -ne 0) { throw 'Cannot unlock keystore/alias. Check credentials locally.' }
$names = @('HOLE_ANDROID_SDK', 'HOLE_JAVA_SDK', 'HOLE_RELEASE_SETTINGS')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
    $env:HOLE_ANDROID_SDK = $AndroidSdk
    $env:HOLE_JAVA_SDK = $JavaSdk
    $env:HOLE_RELEASE_SETTINGS = [IO.Path]::GetFullPath($Settings)
    & $Godot --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    $exportArgs = @('--headless', '--path', $projectRoot, '--editor', '--script', 'res://tools/export_android_release.gd')
    if ($CheckOnly) { $exportArgs += @('--', '--check') }
    & $Godot @exportArgs
    if ($LASTEXITCODE -ne 0) { throw 'Android release validation/export failed.' }
    if (!$CheckOnly) {
        $aab = Join-Path $projectRoot 'builds/hole-munch-release.aab'
        & (Join-Path $JavaSdk 'bin/jarsigner.exe') -verify $aab
        if ($LASTEXITCODE -ne 0) { throw 'AAB signature verification failed.' }
        Get-FileHash -LiteralPath $aab -Algorithm SHA256
        Write-Output "Built $aab. Upload first to Play internal testing; complete device/consent QA before production."
    }
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name]) }
}
