<#
.SYNOPSIS
Uninstalls PowerToys that was installed from this offline bundle, fully offline.

.DESCRIPTION
Reassembles the official x64 installer, verifies its SHA256, then runs it with
/uninstall /quiet /norestart. Use -MachineWide if the original install used
that option. No files from this bundle folder itself are deleted.

.PARAMETER MachineWide
Uninstall a machine-wide installation. Requires an elevated PowerShell.

.PARAMETER Interactive
Open the official uninstaller UI instead of a silent uninstall.

.EXAMPLE
powershell -NoProfile -File .\uninstall.ps1 -WhatIf

.EXAMPLE
powershell -NoProfile -File .\uninstall.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$MachineWide,
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "tools\offline-common.ps1")

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { Fail "this uninstaller is for Windows" }
$arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($arch -ne "AMD64") { Fail "this bundle is for x64 Windows only (found $arch)" }

if ($MachineWide -and -not (Test-IsAdministrator)) {
    Fail "machine-wide uninstall requires an elevated PowerShell (Run as administrator)"
}

$payload = Join-Path $PSScriptRoot "windows-x64"
$sums = Join-Path $PSScriptRoot "SHA256SUMS"
$official = Join-Path $payload "official-installers.sha256"
$releaseFile = Join-Path $payload "official-release.txt"

if (-not (Test-Path -LiteralPath $sums)) { Fail "SHA256SUMS not found next to uninstall.ps1; copy the whole folder" }

$tag = Get-ReleaseField $releaseFile "tag"
$name = Get-InstallerName $releaseFile -MachineWide:$MachineWide
$kind = "per-user"
if ($MachineWide) { $kind = "machine-wide" }

Write-Host "PowerToys offline bundle $tag ($kind) x64 uninstall"
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
    $log = Join-Path $work "PowerToys-uninstall.log"

    Write-Host "Reassembling $name from $($parts.Count) chunks..."
    Merge-InstallerParts -Destination $dest -Parts $parts
    $actual = Get-FileSha256Lower $dest
    if ($actual -ne $expected) {
        Fail "reassembled installer SHA256 $actual does not match official hash $expected"
    }
    Write-Host "  SHA256 OK (matches official release hash)"

    if ($Interactive) {
        $argList = @("/uninstall")
        $action = "Run official uninstaller UI"
    } else {
        $argList = @("/uninstall", "/quiet", "/norestart", "/log", "`"$log`"")
        $action = "Silent uninstall (/uninstall /quiet /norestart)"
    }

    if ($PSCmdlet.ShouldProcess($dest, $action)) {
        if (-not $Interactive) {
            Write-Host "Running official uninstaller silently..."
            Write-Host "  log: $log"
        }
        $code = Invoke-OfficialInstaller -ExePath $dest -ArgumentList $argList -LogPath $log
        if ($code -eq 3010) {
            Write-Host "PowerToys $tag ($kind) uninstalled, but Windows reports a reboot is required (exit 3010)."
        } else {
            Write-Host "PowerToys $tag ($kind) uninstalled."
        }
        $failed = $false
    } else {
        Write-Host "WhatIf: would uninstall with $name ($kind); official SHA256 $expected"
        Write-Host "WhatIf: nothing was uninstalled."
        $failed = $false
    }
} finally {
    if ($failed -and $log -and (Test-Path -LiteralPath $log)) {
        $keep = Join-Path $env:TEMP "PowerToys-windows-offline-uninstall.log"
        Copy-Item -Force -LiteralPath $log -Destination $keep
        Write-Host "Installer log copied to $keep"
    }
    if ($work -and (Test-Path -LiteralPath $work)) {
        Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
    }
}
