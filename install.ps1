<#
.SYNOPSIS
Installs official Microsoft PowerToys for Windows x64 from this folder, fully offline.

.DESCRIPTION
Reassembles the official x64 installer from 90 MiB chunks in windows-x64\,
checks its SHA256 against the hash published in the official GitHub release
notes, then runs the official installer. Nothing is downloaded.

Default is a per-user install (PowerToysUserSetup, no administrator rights).
Pass -MachineWide to use the machine-wide installer (requires elevation).

Silent flags are the official ones documented as Microsoft Standard Installer
options: /install /quiet /norestart, plus /log to a temp file.

.PARAMETER MachineWide
Install for all users with PowerToysSetup-*-x64.exe. Requires an elevated
PowerShell (Run as administrator).

.PARAMETER Interactive
Open the official installer UI instead of a silent install.

.EXAMPLE
powershell -NoProfile -File .\install.ps1 -WhatIf

.EXAMPLE
powershell -NoProfile -File .\install.ps1

.EXAMPLE
powershell -NoProfile -File .\install.ps1 -MachineWide
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$MachineWide,
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "tools\offline-common.ps1")

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { Fail "this installer is for Windows" }
$arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($arch -eq "ARM64") { Fail "this bundle does not include ARM64 installers; use the official PowerToys ARM64 release" }
if ($arch -ne "AMD64") { Fail "this bundle is for x64 Windows only (found $arch)" }
$build = [Environment]::OSVersion.Version.Build
if ($build -lt 19041) { Fail "needs Windows 10 version 2004 (build 19041) or newer; this is build $build" }

if ($MachineWide -and -not (Test-IsAdministrator)) {
    Fail "machine-wide install requires an elevated PowerShell (Run as administrator)"
}

$payload = Join-Path $PSScriptRoot "windows-x64"
$sums = Join-Path $PSScriptRoot "SHA256SUMS"
$official = Join-Path $payload "official-installers.sha256"
$releaseFile = Join-Path $payload "official-release.txt"

if (-not (Test-Path -LiteralPath $sums)) { Fail "SHA256SUMS not found next to install.ps1; copy the whole folder" }
if (-not (Test-Path -LiteralPath $payload)) { Fail "windows-x64 folder not found next to install.ps1; copy the whole folder" }
if (-not (Test-Path -LiteralPath $official)) { Fail "official-installers.sha256 not found; copy the whole folder" }
if (-not (Test-Path -LiteralPath $releaseFile)) { Fail "official-release.txt not found; copy the whole folder" }

$tag = Get-ReleaseField $releaseFile "tag"
$name = Get-InstallerName $releaseFile -MachineWide:$MachineWide
$kind = "per-user"
if ($MachineWide) { $kind = "machine-wide" }

Write-Host "PowerToys offline bundle $tag ($kind) x64"
Write-Host "Installer: $name"

Write-Host "Checking files against SHA256SUMS..."
$problems = Test-Sha256Sums $PSScriptRoot $sums
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  $_" }
    Fail "the bundle is incomplete or damaged; copy or clone it again"
}
Write-Host "  all files OK"

$parts = Get-PartFiles $payload $name
$expected = Get-OfficialInstallerHash $official $name

$work = $null
$failed = $true
$log = $null
try {
    $work = New-AssembleWorkDir
    $dest = Join-Path $work $name
    $log = Join-Path $work "PowerToys-setup.log"

    Write-Host "Reassembling $name from $($parts.Count) chunks..."
    Merge-InstallerParts -Destination $dest -Parts $parts
    $actual = Get-FileSha256Lower $dest
    if ($actual -ne $expected) {
        Fail "reassembled installer SHA256 $actual does not match official hash $expected"
    }
    Write-Host "  SHA256 OK (matches official release hash)"

    if ($Interactive) {
        $argList = @()
        $action = "Run official installer UI"
    } else {
        $argList = @("/install", "/quiet", "/norestart", "/log", "`"$log`"")
        $action = "Silent install (/install /quiet /norestart)"
    }

    if ($PSCmdlet.ShouldProcess($dest, $action)) {
        if (-not $Interactive) {
            Write-Host "Running official installer silently..."
            Write-Host "  log: $log"
        }
        $code = Invoke-OfficialInstaller -ExePath $dest -ArgumentList $argList -LogPath $log
        if ($code -eq 3010) {
            Write-Host "PowerToys $tag ($kind) installed, but Windows reports a reboot is required (exit 3010)."
        } else {
            Write-Host "PowerToys $tag ($kind) installed."
        }
        $failed = $false
    } else {
        Write-Host "WhatIf: would run $name ($kind); official SHA256 $expected"
        Write-Host "WhatIf: nothing was installed."
        $failed = $false
    }
} finally {
    if ($failed -and $log -and (Test-Path -LiteralPath $log)) {
        $keep = Join-Path $env:TEMP "PowerToys-windows-offline-setup.log"
        Copy-Item -Force -LiteralPath $log -Destination $keep
        Write-Host "Installer log copied to $keep"
    }
    if ($work -and (Test-Path -LiteralPath $work)) {
        Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
    }
}
