[CmdletBinding()]
param(
    [string]$InstallRoot = "",
    [string]$RepoUrl = "https://repo.msys2.org/mingw/ucrt64",
    [string]$PackageName = "mingw-w64-ucrt-x86_64-libass",
    [switch]$SkipDownload
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = Resolve-Path (Join-Path $scriptDir "..")
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $labDir "deps\msys2-ucrt64-libass"
}

$repoBase = $RepoUrl.TrimEnd("/")
$downloadDir = Join-Path $labDir "deps\downloads\msys2-ucrt64"
$dbPath = Join-Path $downloadDir "ucrt64.db"
$stagingRoot = Join-Path $InstallRoot "staging"
$sdkRoot = Join-Path $InstallRoot "sdk"
$envPath = Join-Path $InstallRoot "cueseeker-libass-env.ps1"

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

function Find-Tar {
    $command = Get-Command tar -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "tar.exe was not found. Windows bsdtar with zstd support is required."
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

function Expand-TarArchive {
    param(
        [Parameter(Mandatory = $true)][string]$Tar,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    & $Tar -xf $ArchivePath -C $Destination
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed for $ArchivePath with exit code $LASTEXITCODE." }
}

function Get-FieldValues {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Fields,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($Fields.ContainsKey($Name)) {
        return @($Fields[$Name].ToArray())
    }
    return @()
}

function Get-FirstFieldValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Fields,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $values = @(Get-FieldValues -Fields $Fields -Name $Name)
    if ($values.Count -gt 0) {
        return [string]$values[0]
    }
    return ""
}

function Read-PackageDesc {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fields = @{}
    $currentField = $null
    foreach ($line in Get-Content -Path $Path) {
        if ($line -match "^%(.+)%$") {
            $currentField = $matches[1]
            if (-not $fields.ContainsKey($currentField)) {
                $fields[$currentField] = New-Object System.Collections.Generic.List[string]
            }
            continue
        }
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($currentField) {
            $fields[$currentField].Add($line)
        }
    }

    [PSCustomObject]@{
        Name = Get-FirstFieldValue -Fields $fields -Name "NAME"
        Filename = Get-FirstFieldValue -Fields $fields -Name "FILENAME"
        Version = Get-FirstFieldValue -Fields $fields -Name "VERSION"
        Sha256 = Get-FirstFieldValue -Fields $fields -Name "SHA256SUM"
        Depends = Get-FieldValues -Fields $fields -Name "DEPENDS"
        Provides = Get-FieldValues -Fields $fields -Name "PROVIDES"
    }
}

function Normalize-DependencyName {
    param([Parameter(Mandatory = $true)][string]$Dependency)
    return (($Dependency.Trim() -replace "[<>=].*$", "") -replace ":.*$", "")
}

function Read-PackageDatabase {
    param(
        [Parameter(Mandatory = $true)][string]$DbArchivePath,
        [Parameter(Mandatory = $true)][string]$Tar
    )

    $dbHash = (Get-FileHash -Algorithm SHA256 $DbArchivePath).Hash.Substring(0, 12).ToLowerInvariant()
    $dbExtractRoot = Join-Path $InstallRoot "db-$dbHash"
    if (-not (Test-Path $dbExtractRoot)) {
        Expand-TarArchive -Tar $Tar -ArchivePath $DbArchivePath -Destination $dbExtractRoot
    }

    $byName = @{}
    $byProvide = @{}
    foreach ($desc in Get-ChildItem $dbExtractRoot -Filter desc -Recurse) {
        $package = Read-PackageDesc -Path $desc.FullName
        if ([string]::IsNullOrWhiteSpace($package.Name) -or [string]::IsNullOrWhiteSpace($package.Filename)) {
            continue
        }
        $byName[$package.Name] = $package
        foreach ($provided in $package.Provides) {
            $name = Normalize-DependencyName -Dependency $provided
            if (-not [string]::IsNullOrWhiteSpace($name) -and -not $byProvide.ContainsKey($name)) {
                $byProvide[$name] = $package.Name
            }
        }
    }

    [PSCustomObject]@{
        ByName = $byName
        ByProvide = $byProvide
    }
}

function Resolve-PackageClosure {
    param(
        [Parameter(Mandatory = $true)][object]$Database,
        [Parameter(Mandatory = $true)][string]$RootPackageName
    )

    $resolved = [ordered]@{}
    $queue = New-Object System.Collections.Generic.Queue[string]
    $queue.Enqueue($RootPackageName)

    while ($queue.Count -gt 0) {
        $requestedName = Normalize-DependencyName -Dependency $queue.Dequeue()
        if ([string]::IsNullOrWhiteSpace($requestedName) -or $resolved.Contains($requestedName)) {
            continue
        }

        $packageName = $requestedName
        if (-not $Database.ByName.ContainsKey($packageName)) {
            if ($Database.ByProvide.ContainsKey($packageName)) {
                $packageName = $Database.ByProvide[$packageName]
            } else {
                throw "Package dependency was not found in the MSYS2 repository database: $requestedName"
            }
        }
        if ($resolved.Contains($packageName)) {
            continue
        }

        $package = $Database.ByName[$packageName]
        $resolved[$packageName] = $package
        foreach ($dependency in $package.Depends) {
            $queue.Enqueue($dependency)
        }
    }

    return @($resolved.Values)
}

function Save-Package {
    param(
        [Parameter(Mandatory = $true)][object]$Package
    )

    $packagePath = Join-Path $downloadDir $Package.Filename
    $needsDownload = -not (Test-Path $packagePath)
    if (-not $needsDownload -and -not [string]::IsNullOrWhiteSpace($Package.Sha256)) {
        $actual = (Get-FileHash -Algorithm SHA256 $packagePath).Hash.ToLowerInvariant()
        $needsDownload = $actual -ne $Package.Sha256.ToLowerInvariant()
    }

    if ($needsDownload) {
        if ($SkipDownload) {
            throw "Package archive not found or hash mismatch while -SkipDownload is set: $packagePath"
        }
        $url = "$repoBase/$($Package.Filename)"
        Write-Host ("Downloading {0}" -f $Package.Filename)
        Invoke-WebRequest -Uri $url -OutFile $packagePath -UseBasicParsing
    }

    if (-not [string]::IsNullOrWhiteSpace($Package.Sha256)) {
        $actual = (Get-FileHash -Algorithm SHA256 $packagePath).Hash.ToLowerInvariant()
        if ($actual -ne $Package.Sha256.ToLowerInvariant()) {
            throw "SHA-256 mismatch for $($Package.Filename). Expected $($Package.Sha256) but got $actual."
        }
    }

    return $packagePath
}

New-Item -ItemType Directory -Force -Path $downloadDir, $InstallRoot, $stagingRoot, $sdkRoot | Out-Null

if (-not $SkipDownload) {
    Write-Host "Downloading MSYS2 repository database..."
    Invoke-WebRequest -Uri "$repoBase/ucrt64.db" -OutFile $dbPath -UseBasicParsing
}
if (-not (Test-Path $dbPath)) { throw "MSYS2 repository database not found: $dbPath" }

$tar = Find-Tar
$database = Read-PackageDatabase -DbArchivePath $dbPath -Tar $tar
$packages = Resolve-PackageClosure -Database $database -RootPackageName $PackageName

Write-Host ("Resolved {0} MSYS2 packages for {1}:" -f $packages.Count, $PackageName)
foreach ($package in $packages) {
    Write-Host ("  - {0} {1}" -f $package.Name, $package.Version)
}

foreach ($package in $packages) {
    $packagePath = Save-Package -Package $package
    Expand-TarArchive -Tar $tar -ArchivePath $packagePath -Destination $stagingRoot
}

$stagedPrefix = Join-Path $stagingRoot "ucrt64"
$includeSource = Join-Path $stagedPrefix "include\ass"
$binSource = Join-Path $stagedPrefix "bin"
if (-not (Test-Path (Join-Path $includeSource "ass.h"))) {
    throw "Extracted libass headers were not found under $includeSource."
}

$sdkInclude = Join-Path $sdkRoot "include\ass"
$sdkBin = Join-Path $sdkRoot "bin"
$sdkLib = Join-Path $sdkRoot "msvc-lib"
New-Item -ItemType Directory -Force -Path $sdkInclude, $sdkBin, $sdkLib | Out-Null

Copy-Item -Path (Join-Path $includeSource "*") -Destination $sdkInclude -Recurse -Force
Copy-Item -Path (Join-Path $binSource "*.dll") -Destination $sdkBin -Force

$vsInstall = Find-VsInstall
$toolset = Find-VsToolsetRoot -VsInstall $vsInstall
$msvcBin = Join-Path $toolset "bin\Hostx64\x64"
$dumpbin = Join-Path $msvcBin "dumpbin.exe"
$libExe = Join-Path $msvcBin "lib.exe"
if (-not (Test-Path $dumpbin)) { throw "dumpbin.exe was not found: $dumpbin" }
if (-not (Test-Path $libExe)) { throw "lib.exe was not found: $libExe" }

$libassDll = Get-ChildItem $sdkBin -Filter "libass-*.dll" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    Select-Object -First 1
if ($null -eq $libassDll) {
    throw "libass DLL was not found under $sdkBin."
}
New-ImportLibrary -DllPath $libassDll.FullName -OutputLib (Join-Path $sdkLib "ass.lib") -Dumpbin $dumpbin -LibExe $libExe

$manifestPath = Join-Path $InstallRoot "packages.txt"
$manifest = $packages | ForEach-Object { "{0} {1} {2}" -f $_.Name, $_.Version, $_.Filename }
Set-Content -Path $manifestPath -Value $manifest -Encoding ASCII

$envLines = @(
    "`$env:LIBASS_ROOT = `"$sdkRoot`"",
    "`$env:PATH = `"$sdkBin;`" + `$env:PATH"
)
Set-Content -Path $envPath -Value $envLines -Encoding ASCII

Write-Host ""
Write-Host "libass MSYS2 SDK is ready."
Write-Host ("  LIBASS_ROOT: {0}" -f $sdkRoot)
Write-Host ("  Runtime DLLs: {0}" -f $sdkBin)
Write-Host ("  MSVC import lib: {0}" -f (Join-Path $sdkLib "ass.lib"))
Write-Host ("  Package manifest: {0}" -f $manifestPath)
Write-Host ("  Environment helper: {0}" -f $envPath)
