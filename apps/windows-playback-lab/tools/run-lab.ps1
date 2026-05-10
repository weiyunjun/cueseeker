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
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
$exe = Join-Path $labDir "build\$Configuration\CueSeekerWindowsPlaybackLab.exe"
$envHelper = Join-Path $labDir "deps\ffmpeg-release-full-shared\cueseeker-ffmpeg-env.ps1"

if (Test-Path $envHelper) {
    . $envHelper
}

if (-not (Test-Path $exe)) {
    throw "Playback lab executable not found. Run tools/build.ps1 first."
}

if ($RenderTest) {
    & $exe --render-test
    exit $LASTEXITCODE
}

if ($Play) {
    & $exe --play $MediaPath --seek-ms $SeekMs --duration-ms $DurationMs
    exit $LASTEXITCODE
}

& $exe --inspect $MediaPath
exit $LASTEXITCODE
