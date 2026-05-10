[CmdletBinding()]
param(
    [string]$Generator = "",
    [string]$Platform = "x64",
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
$buildDir = Join-Path $labDir "build"
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

function Find-CMake {
    $command = Get-Command cmake -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $vsInstall = Find-VsInstall
    if ($vsInstall) {
        $candidate = Join-Path $vsInstall "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Select-DefaultGenerator {
    param([Parameter(Mandatory = $true)][string]$CMakePath)

    $help = & $CMakePath --help
    if ($help -match "Visual Studio 18 2026") {
        return "Visual Studio 18 2026"
    }
    if ($help -match "Visual Studio 17 2022") {
        return "Visual Studio 17 2022"
    }

    return $null
}

$cmake = Find-CMake
if (-not $cmake) {
    throw "CMake was not found. Run tools/check-env.ps1 for setup details."
}

Normalize-ProcessPathEnvironment

if ([string]::IsNullOrWhiteSpace($Generator)) {
    $Generator = Select-DefaultGenerator -CMakePath $cmake
}

$configureArgs = @("-S", $labDir, "-B", $buildDir)
if (-not [string]::IsNullOrWhiteSpace($Generator)) {
    $configureArgs += @("-G", $Generator)
}
if (-not [string]::IsNullOrWhiteSpace($Platform) -and $Generator -match "Visual Studio") {
    $configureArgs += @("-A", $Platform)
}
if (-not [string]::IsNullOrWhiteSpace($env:FFMPEG_ROOT)) {
    $configureArgs += @("-DFFMPEG_ROOT=$env:FFMPEG_ROOT")
}
if (-not [string]::IsNullOrWhiteSpace($env:LIBASS_ROOT)) {
    $configureArgs += @("-DLIBASS_ROOT=$env:LIBASS_ROOT")
}

& $cmake @configureArgs
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed with exit code $LASTEXITCODE."
}

& $cmake --build $buildDir --config $Configuration
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE."
}
