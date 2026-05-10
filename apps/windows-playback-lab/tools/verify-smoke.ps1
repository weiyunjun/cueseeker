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
$reportPath = Join-Path $reportDir "windows-lab-sample-inspect.json"

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
$inspectOutput = & (Join-Path $scriptDir "run-lab.ps1") $videoPath -Configuration $Configuration
if ($LASTEXITCODE -ne 0) {
    throw "Inspect failed with exit code $LASTEXITCODE."
}
$inspectOutput | Tee-Object -FilePath $reportPath

if (-not $SkipPlay) {
    Write-Host ""
    Write-Host "== Play =="
    & (Join-Path $scriptDir "run-lab.ps1") $videoPath -Play -SeekMs $SeekMs -DurationMs $DurationMs -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) {
        throw "Playback smoke failed with exit code $LASTEXITCODE."
    }
}

Write-Host ""
Write-Host "Smoke verification complete."
Write-Host ("  report: {0}" -f $reportPath)

