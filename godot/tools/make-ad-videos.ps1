# Records the scripted ad clips (ADS-SCRIPTS.md) and cuts finished 1080x1920 MP4
# ads into test-output/ads/final/: each ad is its clips plus the end card, and
# daily-montage strings 2.5 s of every daily game (recorded without captions)
# under each game's name. Clips are recorded with Godot's movie maker in a
# borderless portrait window (it may be taller than the screen; a temporary
# override.cfg, always removed after); a clip that
# is already there is reused unless -Fresh is given. Needs ffmpeg on PATH.
#   tools/make-ad-videos.ps1                      # every ad
#   tools/make-ad-videos.ps1 -Ads eat-paris,daily-findcow -Fresh
param(
    [string]$Godot = "Godot_v4.7.1-stable_win64_console.exe",
    [string[]]$Ads = @(),
    [string]$Lang = "en",
    [switch]$Fresh,
    [int]$Fps = 30
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$clipDir = Join-Path $projectRoot 'test-output/ads'
$finalDir = Join-Path $clipDir 'final'
$override = Join-Path $projectRoot 'override.cfg'
New-Item -ItemType Directory -Force $finalDir | Out-Null
$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue)
if (-not $ffmpeg) {
    $ffmpeg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ffmpeg) { throw "ffmpeg not found: winget install Gyan.FFmpeg" }
    $ffmpeg = $ffmpeg.FullName
} else { $ffmpeg = $ffmpeg.Source }

$dailies = 'findcow', 'redlight', 'skyhop', 'slide', 'snake', 'mole', 'siege', 'beam', 'stampede', 'coinrain', 'goldrush'
# The montage opens on a colourful game; the cow hunt starts with its card up.
$montage = 'redlight', 'skyhop', 'slide', 'snake', 'mole', 'siege', 'beam', 'findcow', 'stampede', 'coinrain', 'goldrush'
$dailyNames = @{ findcow = 'FIND THE COW'; redlight = 'RED LIGHT, GREEN LIGHT'; skyhop = 'SKY HOP'; slide = 'SLIDE MUNCH';
    snake = 'SAUCER SNAKE'; mole = 'MOLE MUNCH'; siege = 'SKY SIEGE'; beam = 'BEAM & DROP'; stampede = 'DUCK FAMILIES';
    coinrain = 'COIN RAIN'; goldrush = 'GOLD RUSH' }
# Ad -> its clips in order, each "preset:city" (0-based city) or a daily preset.
$plan = [ordered]@{
    'eat-paris'     = @('growth:8')
    'boss-fight'    = @('boss:24', 'cling:24')
    'liberty'       = @('conquer:24')
    'wrong-gate'    = @('gates:40')
    'rush-hour'     = @('rushhour:8')
    'sydney-growth' = @('growth:40')
}
foreach ($d in $dailies) { $plan["daily-$d"] = @("daily-$($d):0") }
$plan['daily-montage'] = @()
if ($Ads.Count -gt 0) { $Ads = $Ads | ForEach-Object { $_ -split ',' } | Where-Object { $_ } }
else { $Ads = @($plan.Keys) }

function Record([string]$preset, [int]$level, [switch]$Clean) {
    $name = "{0}-{1:D2}{2}-{3}" -f $preset, ($level + 1), $(if ($Clean) { '-clean' } else { '' }), $Lang
    $movie = Join-Path $clipDir "$name.avi"
    if ((Test-Path -LiteralPath $movie) -and -not $Fresh) { return $movie }
    $cmd = @('--path', $projectRoot, '--write-movie', $movie, '--fixed-fps', $Fps, '--', '--capture', '--ad-capture', "--ad=$preset", "--levels=$level", "--lang=$Lang")
    if ($Clean) { $cmd += '--ad-clean' }
    # Godot logs warnings on stderr; Windows PowerShell 5.1 would stop on them.
    $ErrorActionPreference = 'Continue'
    & $Godot @cmd 2>&1 | ForEach-Object { "$_" } | Out-Host
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $movie)) { throw "Recording $name failed." }
    Write-Output $movie
}

# Scales every input to 1080x1920 at $Fps and joins them, sound included.
function Join-Clips([string[]]$inputs, [string]$out, [string[]]$extraFilters = @()) {
    $cmd = @('-y', '-loglevel', 'error')
    foreach ($i in $inputs) { $cmd += @("-i", $i) }
    $chains = @()
    $joined = ''
    for ($k = 0; $k -lt $inputs.Count; $k++) {
        $chains += "[$($k):v]scale=1080:1920:flags=lanczos,setsar=1,fps=$Fps$(if ($extraFilters.Count -gt $k -and $extraFilters[$k]) { ',' + $extraFilters[$k] })[v$k]"
        $chains += "[$($k):a]aresample=48000,aformat=channel_layouts=stereo[a$k]"
        $joined += "[v$k][a$k]"
    }
    $graph = ($chains -join ';') + ";$($joined)concat=n=$($inputs.Count):v=1:a=1[v][a]"
    $cmd += @('-filter_complex', $graph, '-map', '[v]', '-map', '[a]', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
        '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', $out)
    & $ffmpeg @cmd
    if ($LASTEXITCODE -ne 0) { throw "Cutting $out failed." }
}

if (Test-Path -LiteralPath $override) { throw "override.cfg already exists in $projectRoot; remove it first." }
@"
[display]
window/size/viewport_width=360
window/size/viewport_height=640
window/size/window_width_override=1080
window/size/window_height_override=1920
window/size/borderless=true
"@ | Set-Content -LiteralPath $override -Encoding ascii
try {
    $card = Record 'endcard' 8
    foreach ($ad in $Ads) {
        if (-not $plan.Contains($ad)) { throw "Unknown ad '$ad'. Known: $($plan.Keys -join ', ')" }
        $out = Join-Path $finalDir "$ad-$Lang.mp4"
        if ($ad -eq 'daily-montage') {
            # Clean clips, 2.5 s from 3 s in, each under its game's name; the
            # hook and the question ride on the first and last segment.
            $font = Join-Path $finalDir 'Baloo2.ttf'
            Copy-Item (Join-Path $projectRoot 'assets/fonts/Baloo2.ttf') $font -Force
            $parts = @()
            $filters = @()
            for ($k = 0; $k -lt $montage.Count; $k++) {
                $d = $montage[$k]
                $clip = Record "daily-$d" 0 -Clean
                $part = Join-Path $finalDir "part-$d.mp4"
                $label = "drawtext=fontfile=Baloo2.ttf:text='$($dailyNames[$d])':fontsize=78:fontcolor=0xf6cb70:borderw=8:bordercolor=0x172939:x=(w-tw)/2:y=h*0.80"
                if ($k -eq 0) { $label += ",drawtext=fontfile=Baloo2.ttf:text='A NEW GAME':fontsize=104:fontcolor=white:borderw=10:bordercolor=0x172939:box=1:boxcolor=0x172939@0.55:boxborderw=24:x=(w-tw)/2:y=h*0.36,drawtext=fontfile=Baloo2.ttf:text='EVERY DAY':fontsize=104:fontcolor=0xf6cb70:borderw=10:bordercolor=0x172939:box=1:boxcolor=0x172939@0.55:boxborderw=24:x=(w-tw)/2:y=h*0.36+120" }
                if ($k -eq $montage.Count - 1) { $label += ",drawtext=fontfile=Baloo2.ttf:text='Which one is':fontsize=92:fontcolor=white:borderw=10:bordercolor=0x172939:box=1:boxcolor=0x172939@0.55:boxborderw=24:x=(w-tw)/2:y=h*0.36,drawtext=fontfile=Baloo2.ttf:text='YOUR favourite?':fontsize=92:fontcolor=0xf6cb70:borderw=10:bordercolor=0x172939:box=1:boxcolor=0x172939@0.55:boxborderw=24:x=(w-tw)/2:y=h*0.36+110" }
                Push-Location $finalDir
                try {
                    & $ffmpeg -y -loglevel error -ss $(if ($d -eq 'findcow') { 10 } else { 3 }) -t 2.5 -i $clip -vf "scale=1080:1920:flags=lanczos,setsar=1,fps=$Fps,$label" -af 'aresample=48000,aformat=channel_layouts=stereo' -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac $part
                    if ($LASTEXITCODE -ne 0) { throw "Cutting the $d segment failed." }
                }
                finally { Pop-Location }
                $parts += $part
            }
            Join-Clips ($parts + $card) $out
            $parts | ForEach-Object { Remove-Item -LiteralPath $_ }
            Remove-Item -LiteralPath $font
        }
        else {
            $clips = foreach ($entry in $plan[$ad]) {
                $preset, $level = $entry -split ':'
                Record $preset ([int]$level)
            }
            Join-Clips (@($clips) + $card) $out
        }
        Write-Output "Ad ready: $out"
    }
}
finally {
    Remove-Item -LiteralPath $override -Force
}
