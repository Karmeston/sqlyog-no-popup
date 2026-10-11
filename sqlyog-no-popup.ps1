# Verified official SQLyog Community x64 builds. apply / restore / status.
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('apply', 'restore', 'status')][string]$Action = 'status',
    [string]$Path
)
$ErrorActionPreference = 'Stop'

# Version | file size | function offset (hex) | original SHA-256.
# A patched file is validated by temporarily normalizing its one changed byte.
# These verified builds share an offset whenever they share a file size.
$offsets = @{}
$versions = @{}
@'
13.1.6|7325696|39770|F7B7BD428A2370264C5CBAEB6674319820B56D84BD0A08A2C58194AC3F0154D4
13.1.7|7332864|39710|C284F633FCF0342A05887050571A14867D9B60F3BB77B2ED6194994A25D6F2E8
13.1.8|7332352|39570|4A4A5CB81E449B29DEB6C07AFE5335891DC990A7645E14FD29695889428C4F5E
13.1.9|7336448|397F0|F4703CA218B7B418A462A4896E22713489976A65AD9262B51596F445BBB8AACE
13.2.0|7336960|39A00|A38D7C462D28AB9C5AC0DEFF314EB1C68EDD6FAC5FD7CAE9FA31E4BD628EAE5F
13.2.1|7337472|398C0|939B74AFDE27F4B69B6AC586200D6DE242E01AF0C471A5D1FAA070B33AEE7BE6
13.3.0|7336448|397F0|54F09A576372F26F80F5E78A3D476D64CCC11F3BCE595AB86EB76A56985DBE1D
13.3.1|7364608|398F0|6B50072FBD7783D47F1FDF06894FF5A8C684CF82EA1B7465FF40F7D94BA582FD
'@ -split '\r?\n' | ForEach-Object {
    $version, $size, $offset, $hash = $_ -split '\|'
    $position = [Convert]::ToInt32($offset, 16)
    if ($offsets.ContainsKey([long]$size) -and $offsets[[long]$size] -ne $position) { throw 'Conflicting build offsets in support table.' }
    $offsets[[long]$size] = $position
    $versions[$hash] = $version
}

function Get-Sha256([byte[]]$Bytes) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($algorithm.ComputeHash($Bytes)).Replace('-', '') }
    finally { $algorithm.Dispose() }
}

function Find-SQLyog {
    $found = @(
        foreach ($hive in 'CurrentUser', 'LocalMachine') {
            foreach ($view in 'Registry64', 'Registry32') {
                $root = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
                try { $key = $root.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall') }
                finally { $root.Dispose() }
                if (-not $key) { continue }
                try {
                    foreach ($name in $key.GetSubKeyNames()) {
                        $entry = $key.OpenSubKey($name)
                        if (-not $entry) { continue }
                        try {
                            if ($entry.GetValue('DisplayName') -notlike '*SQLyog Community*') { continue }
                            $folder = $entry.GetValue('InstallLocation')
                            if (-not $folder) { continue }
                            $candidate = [IO.Path]::Combine($folder, 'SQLyogCommunity.exe')
                            if ([IO.File]::Exists($candidate)) { $candidate }
                        } finally { $entry.Dispose() }
                    }
                } finally { $key.Dispose() }
            }
        }
    )
    $candidates = @($found | Select-Object -Unique)
    if ($candidates.Count -ne 1) { throw 'Specify the intended SQLyogCommunity.exe with -Path.' }
    $candidates[0]
}

try {
    if (-not $Path) { $Path = Find-SQLyog }
    $Path = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($Path)) { throw "File not found: $Path" }
    if ($Action -ne 'status' -and (Get-Process -Name SQLyogCommunity -ErrorAction SilentlyContinue)) {
        throw 'Close SQLyog before applying or restoring the patch.'
    }
    $access = if ($Action -eq 'status') { [IO.FileAccess]::Read } else { [IO.FileAccess]::ReadWrite }
    $share = if ($Action -eq 'status') { [IO.FileShare]::Read } else { [IO.FileShare]::None }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, $access, $share)
    try {
        if (-not $offsets.ContainsKey($stream.Length)) { throw 'Unsupported file. Nothing was changed.' }
        $offset = $offsets[$stream.Length]
        $bytes = New-Object byte[] $stream.Length
        $read = 0
        while ($read -lt $bytes.Length) {
            $count = $stream.Read($bytes, $read, $bytes.Length - $read)
            if ($count -eq 0) { throw 'Could not read the complete file.' }
            $read += $count
        }
        $originalByte = $bytes[$offset]
        if ($originalByte -notin 0x48, 0xC3) { throw 'Unsupported file. Nothing was changed.' }
        $bytes[$offset] = 0x48
        $hash = Get-Sha256 $bytes
        $version = $versions[$hash]
        if (-not $version) { throw 'Unsupported file. Nothing was changed.' }
        $state = if ($originalByte -eq 0xC3) { 'patched' } else { 'original' }
        Write-Output "SQLyog: $Path"
        Write-Output "Version: $version x64"
        Write-Output "Status: $state"
        if ($Action -eq 'status') { exit 0 }
        [byte]$targetByte = if ($Action -eq 'apply') { 0xC3 } else { 0x48 }
        if ($originalByte -eq $targetByte) { Write-Output "Already $state. Nothing to do."; exit 0 }

        if ($Action -eq 'apply') {
            $backupPath = $Path + '.exit-popup-backup-' + $version
            if ([IO.File]::Exists($backupPath)) {
                if ((Get-Item -LiteralPath $backupPath).Length -ne $bytes.Length -or
                    (Get-Sha256 ([IO.File]::ReadAllBytes($backupPath))) -ne $hash) {
                    throw "Existing backup does not match; nothing was changed. Backup: $backupPath"
                }
            } else {
                $backup = [IO.File]::Open($backupPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try { $backup.Write($bytes, 0, $bytes.Length); $backup.Flush($true) }
                finally { $backup.Dispose() }
            }
        }
        try {
            $stream.Position = $offset
            $stream.WriteByte($targetByte)
            $stream.Flush($true)
            $stream.Position = $offset
            if ($stream.ReadByte() -ne $targetByte) { throw 'Written byte verification failed.' }
        } catch {
            $writeFailure = $_.Exception.Message
            try {
                $stream.Position = $offset
                $stream.WriteByte($originalByte)
                $stream.Flush($true)
                $stream.Position = $offset
                if ($stream.ReadByte() -ne $originalByte) { throw 'Rollback verification failed.' }
            } catch { throw "Write and rollback failed. Preserve the backup and inspect the EXE. $writeFailure / $($_.Exception.Message)" }
            throw "Operation failed; previous file state restored. $writeFailure"
        }
        if ($Action -eq 'apply') { Write-Output "Applied. Exit promotion dialog disabled. Backup: $backupPath" }
        else { Write-Output 'Restored to the verified original.' }
    } finally { $stream.Dispose() }
    exit 0
} catch {
    [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message)
    exit 1
}
