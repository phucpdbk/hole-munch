param(
    [string]$Godot = "Godot_v4.7.1-stable_win64_console.exe",
    [string]$AndroidSdk = "C:/android",
    [string]$JavaSdk = "C:/Program Files/Android/Android Studio/jbr"
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = Join-Path $projectRoot 'builds'
$template = Join-Path $buildRoot 'templates/android_debug.apk'
if (!(Test-Path -LiteralPath $template)) { throw 'Run tools/fetch_android_template.py first.' }
foreach ($file in @((Join-Path $AndroidSdk 'platform-tools/adb.exe'), (Join-Path $JavaSdk 'bin/keytool.exe'))) {
    if (!(Test-Path -LiteralPath $file)) { throw "Missing build dependency: $file" }
}
New-Item -ItemType Directory -Force $buildRoot | Out-Null
$keystore = Join-Path $buildRoot 'debug.keystore'
if (!(Test-Path -LiteralPath $keystore)) {
    & (Join-Path $JavaSdk 'bin/keytool.exe') -genkeypair -keystore $keystore -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
    if ($LASTEXITCODE -ne 0) { throw 'Debug keystore generation failed.' }
}
$env:HOLE_ANDROID_SDK = $AndroidSdk
$env:HOLE_JAVA_SDK = $JavaSdk
& $Godot --headless --path $projectRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $Godot --headless --path $projectRoot --editor --script res://tools/export_android.gd
if ($LASTEXITCODE -ne 0) { throw 'Android export failed.' }
Write-Output "Built $buildRoot/hole-munch-prototype.apk"
