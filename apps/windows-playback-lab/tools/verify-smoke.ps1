[CmdletBinding()]
param(
    [switch]$SkipPlay,
    [int]$SeekMs = 1000,
    [int]$DurationMs = 2500,
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
$fixtureDir = Join-Path $labDir "out\fixtures"
$reportDir = Join-Path $labDir "out\reports"
$videoPath = Join-Path $fixtureDir "windows-lab-sample.mkv"
$subtitlePath = Join-Path $fixtureDir "windows-lab-sample.ass"
$reportPath = Join-Path $reportDir "windows-lab-sample-inspect.json"
$playbackReportPath = Join-Path $reportDir "windows-lab-sample-playback.json"

New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

Write-Host "== Environment =="
& (Join-Path $scriptDir "check-env.ps1") -NoFail
if ($LASTEXITCODE -ne 0) {
    throw "Environment check failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "== Fixture =="
& (Join-Path $scriptDir "make-fixture.ps1") -OutputDir $fixtureDir
if ($LASTEXITCODE -ne 0) {
    throw "Fixture generation failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "== Build =="
& (Join-Path $scriptDir "build.ps1") -Configuration $Configuration
if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "== Inspect =="
$inspectOutput = & (Join-Path $scriptDir "run-lab.ps1") $videoPath -SubtitlePath $subtitlePath -Configuration $Configuration
if ($LASTEXITCODE -ne 0) {
    throw "Inspect failed with exit code $LASTEXITCODE."
}
$inspectOutput | Tee-Object -FilePath $reportPath
$inspectReport = ($inspectOutput | Out-String) | ConvertFrom-Json
if (-not $inspectReport.subtitles.external_ass.libass_parse_ok) {
    throw "External ASS probe did not parse successfully."
}
if ($inspectReport.subtitles.external_ass.events -lt 1) {
    throw "External ASS probe did not report any subtitle events."
}
if (@($inspectReport.subtitles.embedded_streams).Count -lt 1) {
    throw "Inspect did not report the embedded ASS subtitle stream."
}
if (@($inspectReport.subtitles.attachments).Count -lt 1) {
    throw "Inspect did not report the fixture attachment."
}
if (-not $inspectReport.hardware_decode.d3d11va.device_create_ok) {
    throw "Inspect did not create a D3D11VA hardware device."
}
if (-not @($inspectReport.hardware_decode.d3d11va.video_streams)[0].d3d11va_config_available) {
    throw "Inspect did not report D3D11VA support for the fixture video stream."
}

if (-not $SkipPlay) {
    Write-Host ""
    Write-Host "== Play =="
    & (Join-Path $scriptDir "run-lab.ps1") $videoPath -Play -SubtitlePath $subtitlePath -SeekMs $SeekMs -DurationMs $DurationMs -ReportPath $playbackReportPath -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) {
        throw "Playback smoke failed with exit code $LASTEXITCODE."
    }
    $playbackReport = Get-Content -Raw -Path $playbackReportPath | ConvertFrom-Json
    if (-not $playbackReport.playback.success) {
        throw "Playback report did not mark playback as successful."
    }
    if ($playbackReport.decode.path_requested -ne "auto") {
        throw "Playback report did not record the expected auto decode request."
    }
    if (@("software", "d3d11va") -notcontains $playbackReport.decode.path_used) {
        throw "Playback report did not record a supported decode path."
    }
    if ($playbackReport.decode.path_used -eq "d3d11va" -and $playbackReport.decode.hardware_frame_transfers -lt 1) {
        throw "Playback report selected D3D11VA but did not record transferred hardware frames."
    }
    if ($playbackReport.decode.fallback_used -and [string]::IsNullOrWhiteSpace($playbackReport.decode.fallback_reason)) {
        throw "Playback report recorded fallback without a reason."
    }
    if ($playbackReport.video.frames_rendered -lt 1) {
        throw "Playback report did not record rendered video frames."
    }
    if ($playbackReport.audio.output -ne "wasapi_shared") {
        throw "Playback report did not record WASAPI shared-mode audio output."
    }
    if ($playbackReport.subtitles.overlay -ne "external_ass") {
        throw "Playback report did not record the external ASS overlay."
    }
}

Write-Host ""
Write-Host "Smoke verification complete."
Write-Host ("  report: {0}" -f $reportPath)
if (-not $SkipPlay) {
    Write-Host ("  playback report: {0}" -f $playbackReportPath)
}
