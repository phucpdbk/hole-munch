# Records the ad clips (scripts/ad_capture.gd) as portrait AVI videos plus key-frame
# PNGs in test-output/ads/. The project window is landscape, so a temporary
# override.cfg switches it to portrait for the run and is always removed after.
# With ffmpeg on PATH each clip is also converted to an H.264 MP4.
#   tools/make-ads.ps1                                  # every preset, default cities
#   tools/make-ads.ps1 -Presets conquer -Levels 24 -Lang es
param(
    [string]$Godot = "Godot_v4.7.1-stable_win64_console.exe",
    [string[]]$Presets = @("conquer", "cling", "growth", "rushhour", "gates", "boss"),
    # 0-based cities: Paris, New York (Liberty), Sydney, all with animated guardians.
    [int[]]$Levels = @(8, 24, 40),
    [string]$Lang = "en",
    [int]$Width = 720,
    [int]$Height = 1280,
    [int]$Fps = 30
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outDir = Join-Path $projectRoot 'test-output/ads'
$override = Join-Path $projectRoot 'override.cfg'
New-Item -ItemType Directory -Force $outDir | Out-Null
if (Test-Path -LiteralPath $override) { throw "override.cfg already exists in $projectRoot; remove it first." }
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
@"
[display]
window/size/viewport_width=$($Width/2)
window/size/viewport_height=$($Height/2)
window/size/window_width_override=$Width
window/size/window_height_override=$Height
"@ | Set-Content -LiteralPath $override -Encoding ascii
try {
    foreach ($level in $Levels) {
        foreach ($preset in $Presets) {
            $name = "{0}-{1:D2}-{2}" -f $preset, ($level + 1), $Lang
            $movie = Join-Path $outDir "$name.avi"
            & $Godot --path $projectRoot --write-movie $movie --fixed-fps $Fps -- --capture --ad-capture "--ad=$preset" "--levels=$level" "--lang=$Lang"
            if ($LASTEXITCODE -ne 0) { throw "Recording $name failed." }
            if ($ffmpeg) {
                & $ffmpeg.Source -y -loglevel error -i $movie -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac (Join-Path $outDir "$name.mp4")
                if ($LASTEXITCODE -ne 0) { throw "Converting $name failed." }
            }
            Write-Output "Recorded $movie"
        }
    }
}
finally {
    Remove-Item -LiteralPath $override -Force
}
