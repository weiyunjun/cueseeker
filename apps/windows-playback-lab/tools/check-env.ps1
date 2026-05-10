[CmdletBinding()]
param(
    [switch]$NoFail
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
$envHelper = Join-Path $labDir "deps\ffmpeg-release-full-shared\cueseeker-ffmpeg-env.ps1"

if (Test-Path $envHelper) {
    . $envHelper
}

function Normalize-ProcessPathEnvironment {
    $variables = [System.Environment]::GetEnvironmentVariables("Process")
    $pathKeys = @($variables.Keys | Where-Object { $_ -ieq "PATH" })
    if ($pathKeys.Count -le 1) {
        return
    }

    $value = [System.Environment]::GetEnvironmentVariable("Path", "Process")
    if ([string]::IsNullOrEmpty($value)) {
        $value = [System.Environment]::GetEnvironmentVariable("PATH", "Process")
    }

    foreach ($key in $pathKeys) {
        [System.Environment]::SetEnvironmentVariable([string]$key, $null, "Process")
    }

    if (-not [string]::IsNullOrEmpty($value)) {
        [System.Environment]::SetEnvironmentVariable("Path", $value, "Process")
    }
}

function Find-CommandPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }

    return $command.Source
}

function Find-VsWhere {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Find-VsInstall {
    $vswhere = Find-VsWhere
    if (-not $vswhere) {
        return $null
    }

    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ([string]::IsNullOrWhiteSpace($path)) {
        return $null
    }

    return $path.Trim()
}

function Find-VsCl {
    param([Parameter(Mandatory = $true)][string]$VsInstall)

    $toolRoot = Join-Path $VsInstall "VC\Tools\MSVC"
    if (-not (Test-Path $toolRoot)) {
        return $null
    }

    $toolset = Get-ChildItem $toolRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $toolset) {
        return $null
    }

    $candidate = Join-Path $toolset.FullName "bin\Hostx64\x64\cl.exe"
    if (Test-Path $candidate) {
        return $candidate
    }

    return $null
}

function Find-VsMSBuild {
    param([Parameter(Mandatory = $true)][string]$VsInstall)

    $candidates = @(
        (Join-Path $VsInstall "MSBuild\Current\Bin\amd64\MSBuild.exe"),
        (Join-Path $VsInstall "MSBuild\Current\Bin\MSBuild.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Test-File {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.File]::Exists($Path)
}

function Test-AnyFile {
    param([Parameter(Mandatory = $true)][string[]]$Paths)

    foreach ($path in $Paths) {
        if (Test-File $path) {
            return $true
        }
    }

    return $false
}

function Write-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [Parameter(Mandatory = $true)][string]$Detail
    )

    $status = if ($Ok) { "OK" } else { "MISSING" }
    Write-Host ("[{0}] {1}: {2}" -f $status, $Name, $Detail)
}

Normalize-ProcessPathEnvironment

$failures = New-Object System.Collections.Generic.List[string]
$vsInstall = Find-VsInstall

Write-Host "CueSeeker Windows Playback Lab environment check"
Write-Host ""

$cmake = Find-CommandPath "cmake"
$vsCmake = if ($vsInstall) { Join-Path $vsInstall "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" } else { $null }
if ($null -eq $cmake -and $vsCmake -and (Test-Path $vsCmake)) {
    $cmake = $vsCmake
}
Write-Check "CMake" ($null -ne $cmake) ($(if ($cmake) { $cmake } else { "not found in PATH" }))
if ($null -eq $cmake) { $failures.Add("Install CMake or add it to PATH.") }

$cl = Find-CommandPath "cl"
$msbuild = Find-CommandPath "msbuild"
$vsCl = if ($vsInstall) { Find-VsCl -VsInstall $vsInstall } else { $null }
$vsMsbuild = if ($vsInstall) { Find-VsMSBuild -VsInstall $vsInstall } else { $null }
if ($null -eq $cl -and $vsCl) {
    $cl = $vsCl
}
if ($null -eq $msbuild -and $vsMsbuild) {
    $msbuild = $vsMsbuild
}
Write-Check "MSVC cl.exe" ($null -ne $cl) ($(if ($cl) { $cl } else { "not found in PATH" }))
Write-Check "MSBuild" ($null -ne $msbuild) ($(if ($msbuild) { $msbuild } else { "not found in PATH" }))
if ($null -eq $cl -and $null -eq $msbuild) {
    $failures.Add("Install Visual Studio Build Tools with Desktop development with C++.")
}

$ffmpeg = Find-CommandPath "ffmpeg"
$ffprobe = Find-CommandPath "ffprobe"
$ffplay = Find-CommandPath "ffplay"
Write-Check "ffmpeg CLI" ($null -ne $ffmpeg) ($(if ($ffmpeg) { $ffmpeg } else { "not found in PATH" }))
Write-Check "ffprobe CLI" ($null -ne $ffprobe) ($(if ($ffprobe) { $ffprobe } else { "not found in PATH" }))
Write-Check "ffplay CLI" ($null -ne $ffplay) ($(if ($ffplay) { $ffplay } else { "not found in PATH; useful only as a comparison reference" }))

if ($ffmpeg) {
    Write-Host ""
    Write-Host "FFmpeg version:"
    & $ffmpeg -hide_banner -version | Select-Object -First 1
    Write-Host ""
    Write-Host "FFmpeg hardware acceleration methods:"
    & $ffmpeg -hide_banner -hwaccels
}

$ffmpegRoot = $env:FFMPEG_ROOT
if ([string]::IsNullOrWhiteSpace($ffmpegRoot) -and $ffmpeg) {
    $ffmpegRoot = Split-Path -Parent (Split-Path -Parent $ffmpeg)
}

$ffmpegHeader = if ($ffmpegRoot) { Join-Path $ffmpegRoot "include\libavformat\avformat.h" } else { "" }
$ffmpegAvformatCandidates = if ($ffmpegRoot) {
    @(
        (Join-Path $ffmpegRoot "msvc-lib\avformat.lib"),
        (Join-Path $ffmpegRoot "lib\avformat.lib"),
        (Join-Path $ffmpegRoot "lib\libavformat.lib")
    )
} else {
    @()
}
$ffmpegAvcodecCandidates = if ($ffmpegRoot) {
    @(
        (Join-Path $ffmpegRoot "msvc-lib\avcodec.lib"),
        (Join-Path $ffmpegRoot "lib\avcodec.lib"),
        (Join-Path $ffmpegRoot "lib\libavcodec.lib")
    )
} else {
    @()
}
$ffmpegDevOk = $ffmpegRoot -and (Test-File $ffmpegHeader) -and (Test-AnyFile $ffmpegAvformatCandidates) -and (Test-AnyFile $ffmpegAvcodecCandidates)
Write-Host ""
Write-Check "FFmpeg development package" $ffmpegDevOk ($(if ($ffmpegRoot) { $ffmpegRoot } else { "FFMPEG_ROOT is not set" }))
if (-not $ffmpegDevOk) {
    $failures.Add("Set FFMPEG_ROOT to a FFmpeg development package containing include/lib.")
}

$libassRoot = $env:LIBASS_ROOT
$libassHeader = if ($libassRoot) { Join-Path $libassRoot "include\ass\ass.h" } else { "" }
$libassLibCandidates = if ($libassRoot) {
    @(
        (Join-Path $libassRoot "msvc-lib\ass.lib"),
        (Join-Path $libassRoot "lib\ass.lib"),
        (Join-Path $libassRoot "lib\libass.lib")
    )
} else {
    @()
}
$libassDevOk = $libassRoot -and (Test-File $libassHeader) -and (Test-AnyFile $libassLibCandidates)
Write-Check "libass development package" $libassDevOk ($(if ($libassRoot) { $libassRoot } else { "LIBASS_ROOT is not set" }))
if (-not $libassDevOk) {
    $failures.Add("Set LIBASS_ROOT to a libass development package containing include/lib.")
}

Write-Host ""
Write-Host "Windows compatibility facts:"
try {
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host ("  OS: {0} build {1}" -f $os.Version, $os.BuildNumber)
} catch {
    Write-Host ("  OS: unavailable ({0})" -f $_.Exception.Message)
}

try {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    Write-Host ("  CPU: {0}" -f $cpu.Name)
} catch {
    Write-Host ("  CPU: unavailable ({0})" -f $_.Exception.Message)
}

try {
    $gpus = Get-CimInstance Win32_VideoController
    foreach ($gpu in $gpus) {
        Write-Host ("  GPU: {0}; driver {1}; {2}" -f $gpu.Name, $gpu.DriverVersion, $gpu.VideoModeDescription)
    }
} catch {
    Write-Host ("  GPU: unavailable ({0})" -f $_.Exception.Message)
}

Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "Environment is ready for the C++ playback lab build."
    exit 0
}

Write-Host "Next required actions:"
foreach ($failure in $failures) {
    Write-Host ("  - {0}" -f $failure)
}

if ($NoFail) {
    exit 0
}

exit 1
