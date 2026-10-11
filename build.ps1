# Build the optional desktop app and package release downloads.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler not found.' }
$dist = Join-Path $PSScriptRoot 'dist'
$desktop = Join-Path $dist 'desktop'
New-Item -ItemType Directory -Path $desktop -Force | Out-Null
$script = Join-Path $PSScriptRoot 'sqlyog-no-popup.ps1'
$executable = Join-Path $desktop 'SQLyogExitPopupTool.exe'
$source = Join-Path $PSScriptRoot 'desktop\SQLyogExitPopupTool.cs'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 "/out:$executable" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll $source
if ($LASTEXITCODE -ne 0) { throw 'Desktop compilation failed.' }

foreach ($name in 'sqlyog-no-popup.ps1', 'README.md', 'LICENSE') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $desktop $name) -Force
}
$download = Join-Path $dist 'sqlyog-no-popup.ps1'
Copy-Item -LiteralPath $script -Destination $download -Force
$archive = Join-Path $dist 'SQLyogExitPopupTool.zip'
$packageFiles = @('SQLyogExitPopupTool.exe', 'sqlyog-no-popup.ps1', 'README.md', 'LICENSE') | ForEach-Object { Join-Path $desktop $_ }
Compress-Archive -LiteralPath $packageFiles -DestinationPath $archive -Force
$sums = Get-FileHash -LiteralPath $download, $archive -Algorithm SHA256 | ForEach-Object {
    $_.Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($_.Path)
}
$checksums = Join-Path $dist 'SHA256SUMS.txt'
$sums | Set-Content -LiteralPath $checksums -Encoding ASCII
Write-Output $download, $archive, $checksums
