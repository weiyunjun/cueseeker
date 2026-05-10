[CmdletBinding(DefaultParameterSetName = "Inspect")]
param(
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Inspect")]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Play")]
    [string]$MediaPath,

    [Parameter(ParameterSetName = "Inspect")]
    [switch]$Inspect,

    [Parameter(ParameterSetName = "Play")]
    [switch]$Play,

    [Parameter(ParameterSetName = "RenderTest")]
    [switch]$RenderTest,

    [int]$SeekMs = 0,
    [int]$DurationMs = 15000,
    [ValidateSet("auto", "software", "d3d11va")]
    [string]$Decode = "auto",
    [string]$ReportPath = "",
    [string]$SubtitlePath = "",
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
$exe = Join-Path $labDir "build\$Configuration\CueSeekerWindowsPlaybackLab.exe"
$envHelpers = @(
    (Join-Path $labDir "deps\ffmpeg-release-full-shared\cueseeker-ffmpeg-env.ps1"),
    (Join-Path $labDir "deps\msys2-ucrt64-libass\cueseeker-libass-env.ps1")
)

foreach ($envHelper in $envHelpers) {
    if (Test-Path $envHelper) {
        . $envHelper
    }
}

if (-not (Test-Path $exe)) {
    throw "Playback lab executable not found. Run tools/build.ps1 first."
}

if ($RenderTest) {
    & $exe --render-test
    exit $LASTEXITCODE
}

$labArgs = @()
if (-not [string]::IsNullOrWhiteSpace($SubtitlePath)) {
    $labArgs += @("--subtitle", $SubtitlePath)
}

if ($Play) {
    $playArgs = @("--play", $MediaPath, "--decode", $Decode, "--seek-ms", $SeekMs, "--duration-ms", $DurationMs)
    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        $playArgs += @("--report-path", $ReportPath)
    }
    & $exe @playArgs @labArgs
    exit $LASTEXITCODE
}

& $exe --inspect $MediaPath @labArgs
exit $LASTEXITCODE
