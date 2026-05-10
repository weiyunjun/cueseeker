[CmdletBinding()]
param(
    [string]$OutputDir = "",
    [int]$DurationSeconds = 6
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $labDir "out\fixtures"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) { throw "ffmpeg CLI was not found in PATH." }

$assPath = Join-Path $OutputDir "windows-lab-sample.ass"
$videoPath = Join-Path $OutputDir "windows-lab-sample.mkv"

$ass = @"
[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,54,&H00FFFFFF,&H000000FF,&H00101010,&H80000000,0,0,0,0,100,100,0,0,1,3,1,2,40,40,52,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.50,0:00:02.50,Default,,0,0,0,,CueSeeker Windows playback lab
Dialogue: 0,0:00:03.00,0:00:05.50,Default,,0,0,0,,ASS overlay fixture line
"@
Set-Content -Path $assPath -Value $ass -Encoding UTF8

& $ffmpeg.Source `
    -hide_banner `
    -y `
    -f lavfi `
    -i "testsrc2=size=1280x720:rate=30" `
    -f lavfi `
    -i "sine=frequency=880:sample_rate=48000" `
    -t $DurationSeconds `
    -c:v libx264 `
    -pix_fmt yuv420p `
    -c:a aac `
    -metadata title="CueSeeker Windows playback lab fixture" `
    $videoPath

if ($LASTEXITCODE -ne 0) { throw "ffmpeg fixture generation failed with exit code $LASTEXITCODE." }

Write-Host "Fixture media:"
Write-Host "  video: $videoPath"
Write-Host "  subtitle: $assPath"

