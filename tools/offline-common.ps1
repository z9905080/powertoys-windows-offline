# Shared helpers for install.ps1 and uninstall.ps1.
# Compatible with Windows PowerShell 5.1 and PowerShell 7. ASCII only.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Fail {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "ERROR: $Message"
    exit 1
}

function Get-FileSha256Lower {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ReleaseField {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Key
    )
    $prefix = "${Key}:"
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ($line.StartsWith($prefix)) {
            return $line.Substring($prefix.Length).Trim()
        }
    }
    Fail "field '$Key' is missing from $Path"
}

function Get-InstallerName {
    param(
        [Parameter(Mandatory = $true)][string]$ReleasePath,
        [switch]$MachineWide
    )
    if ($MachineWide) {
        return (Get-ReleaseField $ReleasePath "machine-wide-x64")
    }
    return (Get-ReleaseField $ReleasePath "per-user-x64")
}

function Test-Sha256Sums {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$SumsPath
    )
    $problems = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Get-Content -LiteralPath $SumsPath)) {
        if ($null -eq $line) { continue }
        $trim = $line.Trim()
        if ($trim -eq "" -or $trim.StartsWith("#")) { continue }
        if ($line -notmatch "^([0-9a-fA-F]{64})  (.+)$") {
            [void]$problems.Add("bad SHA256SUMS line: $line")
            continue
        }
        $expected = $Matches[1].ToLowerInvariant()
        $rel = $Matches[2]
        if ($rel.Contains("..") -or [IO.Path]::IsPathRooted($rel)) {
            [void]$problems.Add("unsafe path in SHA256SUMS: $rel")
            continue
        }
        $path = Join-Path $Root $rel
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            [void]$problems.Add("missing: $rel")
            continue
        }
        $actual = Get-FileSha256Lower $path
        if ($actual -ne $expected) {
            [void]$problems.Add("hash mismatch: $rel")
        }
    }
    return $problems
}

function Get-OfficialInstallerHash {
    param(
        [Parameter(Mandatory = $true)][string]$HashesPath,
        [Parameter(Mandatory = $true)][string]$InstallerName
    )
    foreach ($line in (Get-Content -LiteralPath $HashesPath)) {
        if ($line -match "^([0-9a-fA-F]{64})  (.+)$" -and $Matches[2] -eq $InstallerName) {
            return $Matches[1].ToLowerInvariant()
        }
    }
    Fail "official SHA256 for $InstallerName not found in $HashesPath"
}

function Get-PartFiles {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$InstallerName
    )
    $pattern = $InstallerName + ".part??"
    $files = @(Get-ChildItem -LiteralPath $Dir -File | Where-Object { $_.Name -like $pattern } | Sort-Object Name)
    if ($files.Count -lt 1) {
        Fail "no chunks found for $InstallerName; copy the whole folder"
    }
    $i = 1
    foreach ($f in $files) {
        $expected = "{0}.part{1:d2}" -f $InstallerName, $i
        if ($f.Name -ne $expected) {
            Fail "unexpected chunk name '$($f.Name)'; expected '$expected'"
        }
        $i += 1
    }
    return , @($files | ForEach-Object { $_.FullName })
}

function Merge-InstallerParts {
    param(
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string[]]$Parts
    )
    $outDir = Split-Path -Parent $Destination
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Force
    }
    $out = [System.IO.File]::Open(
        $Destination,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        foreach ($part in $Parts) {
            Write-Host "  adding $(Split-Path -Leaf $part)"
            $in = [System.IO.File]::Open(
                $part,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read
            )
            try {
                $in.CopyTo($out)
            } finally {
                $in.Dispose()
            }
        }
    } finally {
        $out.Dispose()
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-AssembleWorkDir {
    $root = Join-Path $env:TEMP "powertoys-windows-offline"
    $dir = Join-Path $root ("work-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}

function Invoke-OfficialInstaller {
    param(
        [Parameter(Mandatory = $true)][string]$ExePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [string]$LogPath
    )
    if ($ArgumentList.Count -gt 0) {
        $proc = Start-Process -FilePath $ExePath -ArgumentList $ArgumentList -Wait -PassThru
    } else {
        $proc = Start-Process -FilePath $ExePath -Wait -PassThru
    }
    $code = $proc.ExitCode
    if ($code -eq 0) { return 0 }
    if ($code -eq 3010) { return 3010 }
    if ($LogPath -and (Test-Path -LiteralPath $LogPath)) {
        Write-Host "Installer log: $LogPath"
    }
    Fail "official installer exited with code $code"
}
