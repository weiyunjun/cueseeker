[CmdletBinding()]
param(
    [string]$InstallRoot = "",
    [string]$ArchiveUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full-shared.7z",
    [string]$Sha256Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full-shared.7z.sha256",
    [switch]$SkipDownload
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $labDir "deps\ffmpeg-release-full-shared"
}

$downloadDir = Join-Path $labDir "deps\downloads"
$archivePath = Join-Path $downloadDir "ffmpeg-release-full-shared.7z"
$extractRoot = Join-Path $InstallRoot "extracted"
$envPath = Join-Path $InstallRoot "cueseeker-ffmpeg-env.ps1"

function Find-VsWhere {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

function Find-VsInstall {
    $vswhere = Find-VsWhere
    if (-not $vswhere) { throw "vswhere.exe was not found. Install Visual Studio Build Tools first." }
    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ([string]::IsNullOrWhiteSpace($path)) { throw "Visual Studio C++ tools were not found." }
    return $path.Trim()
}

function Find-VsToolsetRoot {
    param([Parameter(Mandatory = $true)][string]$VsInstall)
    $toolRoot = Join-Path $VsInstall "VC\Tools\MSVC"
    $toolset = Get-ChildItem $toolRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $toolset) { throw "MSVC toolset was not found under $toolRoot." }
    return $toolset.FullName
}

function Find-7Zip {
    $command = Get-Command 7z -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:ProgramFiles\NVIDIA Corporation\NVIDIA GeForce Experience\7z.exe",
        "D:\Software\Rime\weasel-0.17.4\7z.exe",
        "D:\Software\Cognizer\node_modules\electron-winstaller\vendor\7z.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    throw "7z.exe was not found. Install 7-Zip or put 7z.exe in PATH."
}

function Get-ExpectedSha256 {
    param([Parameter(Mandatory = $true)][string]$Url)
    $text = (Invoke-WebRequest -Uri $Url -UseBasicParsing).Content.Trim()
    $match = [regex]::Match($text, "([A-Fa-f0-9]{64})")
    if (-not $match.Success) { throw "Could not parse SHA-256 from $Url." }
    return $match.Groups[1].Value.ToLowerInvariant()
}

function Find-ExtractedFfmpegRoot {
    param([Parameter(Mandatory = $true)][string]$Root)
    $match = Get-ChildItem $Root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "include\libavformat\avformat.h") } |
        Select-Object -First 1
    if ($null -eq $match) { throw "Extracted FFmpeg development headers were not found under $Root." }
    return $match.FullName
}

function Write-DefFromDumpbin {
    param(
        [Parameter(Mandatory = $true)][string]$Dumpbin,
        [Parameter(Mandatory = $true)][string]$DllPath,
        [Parameter(Mandatory = $true)][string]$DefPath,
        [Parameter(Mandatory = $true)][string]$LibraryName
    )

    $exports = & $Dumpbin /nologo /exports $DllPath
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($line in $exports) {
        if ($line -match "^\s*\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+([A-Za-z_][A-Za-z0-9_@?$\.-]*)\s*$") {
            $name = $matches[1]
            if ($name -notmatch "^\?") { $names.Add($name) }
        }
    }
    if ($names.Count -eq 0) { throw "No C exports were found in $DllPath." }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("LIBRARY $LibraryName")
    $lines.Add("EXPORTS")
    foreach ($name in ($names | Sort-Object -Unique)) { $lines.Add("  $name") }
    Set-Content -Path $DefPath -Value $lines -Encoding ASCII
}

function New-ImportLibrary {
    param(
        [Parameter(Mandatory = $true)][string]$DllPath,
        [Parameter(Mandatory = $true)][string]$OutputLib,
        [Parameter(Mandatory = $true)][string]$Dumpbin,
        [Parameter(Mandatory = $true)][string]$LibExe
    )

    $defPath = [System.IO.Path]::ChangeExtension($OutputLib, ".def")
    Write-DefFromDumpbin -Dumpbin $Dumpbin -DllPath $DllPath -DefPath $defPath -LibraryName ([System.IO.Path]::GetFileName($DllPath))
    & $LibExe /nologo /machine:x64 /def:$defPath /out:$OutputLib | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "lib.exe failed while creating $OutputLib." }
    Write-Host ("Created {0}" -f $OutputLib)
}

New-Item -ItemType Directory -Force -Path $downloadDir, $InstallRoot, $extractRoot | Out-Null

if (-not $SkipDownload) {
    Write-Host "Downloading FFmpeg shared package..."
    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $archivePath -UseBasicParsing

    Write-Host "Verifying SHA-256..."
    $expected = Get-ExpectedSha256 -Url $Sha256Url
    $actual = (Get-FileHash -Algorithm SHA256 $archivePath).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "SHA-256 mismatch. Expected $expected but got $actual." }
}

if (-not (Test-Path $archivePath)) { throw "Archive not found: $archivePath" }

if ((Get-ChildItem $extractRoot -Force -ErrorAction SilentlyContinue | Select-Object -First 1) -eq $null) {
    $sevenZip = Find-7Zip
    Write-Host "Extracting FFmpeg shared package with $sevenZip..."
    & $sevenZip x "-o$extractRoot" -y $archivePath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "7z extraction failed with exit code $LASTEXITCODE." }
}

$ffmpegRoot = Find-ExtractedFfmpegRoot -Root $extractRoot
$msvcLibDir = Join-Path $ffmpegRoot "msvc-lib"
New-Item -ItemType Directory -Force -Path $msvcLibDir | Out-Null

$vsInstall = Find-VsInstall
$toolset = Find-VsToolsetRoot -VsInstall $vsInstall
$msvcBin = Join-Path $toolset "bin\Hostx64\x64"
$dumpbin = Join-Path $msvcBin "dumpbin.exe"
$libExe = Join-Path $msvcBin "lib.exe"
if (-not (Test-Path $dumpbin)) { throw "dumpbin.exe was not found: $dumpbin" }
if (-not (Test-Path $libExe)) { throw "lib.exe was not found: $libExe" }

foreach ($name in @("avformat", "avcodec", "avutil", "swscale", "swresample")) {
    $dll = Get-ChildItem (Join-Path $ffmpegRoot "bin") -Filter "$name-*.dll" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $dll) { throw "Could not find $name DLL under $ffmpegRoot\bin." }
    New-ImportLibrary -DllPath $dll.FullName -OutputLib (Join-Path $msvcLibDir "$name.lib") -Dumpbin $dumpbin -LibExe $libExe
}

$libassDll = Get-ChildItem (Join-Path $ffmpegRoot "bin") -Filter "libass-*.dll" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    Select-Object -First 1
if ($libassDll) {
    New-ImportLibrary -DllPath $libassDll.FullName -OutputLib (Join-Path $msvcLibDir "ass.lib") -Dumpbin $dumpbin -LibExe $libExe
}

$envLines = @(
    "`$env:FFMPEG_ROOT = `"$ffmpegRoot`"",
    "`$env:LIBASS_ROOT = `"$ffmpegRoot`"",
    "`$env:PATH = `"$($ffmpegRoot)\bin;`" + `$env:PATH"
)
Set-Content -Path $envPath -Value $envLines -Encoding ASCII

Write-Host ""
Write-Host "FFmpeg shared SDK is ready."
Write-Host ("  FFMPEG_ROOT: {0}" -f $ffmpegRoot)
Write-Host ("  LIBASS_ROOT: {0}" -f $ffmpegRoot)
Write-Host ("  MSVC import libs: {0}" -f $msvcLibDir)
Write-Host ("  Environment helper: {0}" -f $envPath)
