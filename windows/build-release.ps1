[CmdletBinding()]
param(
  [string]$Version = "0.1.1",
  [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw "This release script must run on Windows."
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "Version must use numeric major.minor.patch format."
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$output = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $repo "releases" }
$stage = Join-Path $output "DeepSeek-Harness-Windows-x64"
New-Item -ItemType Directory -Force -Path $output | Out-Null
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Copy-Item (Join-Path $PSScriptRoot "launch-dsh.ps1") $stage -Force
Copy-Item (Join-Path $PSScriptRoot "launch-dsh.cmd") $stage -Force
Copy-Item (Join-Path $repo "scripts\profile-doctor.mjs") $stage -Force
Copy-Item (Join-Path $PSScriptRoot "install.ps1") $stage -Force
Copy-Item (Join-Path $PSScriptRoot "uninstall.ps1") $stage -Force
Get-ChildItem $PSScriptRoot -Filter "README*.md" -File | Copy-Item -Destination $stage -Force
Copy-Item (Join-Path $PSScriptRoot "bootstrap-build-environment.ps1") $stage -Force
Copy-Item (Join-Path $repo "LICENSE") $stage -Force

$zip = Join-Path $output "DeepSeek-Harness-Windows-x64-v$Version.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -CompressionLevel Optimal

$zipTestDirectory = Join-Path $output ".zip-test-$Version"
if (Test-Path $zipTestDirectory) { Remove-Item -LiteralPath $zipTestDirectory -Recurse -Force }
try {
  Expand-Archive -LiteralPath $zip -DestinationPath $zipTestDirectory
  foreach ($required in @(
    "launch-dsh.ps1",
    "launch-dsh.cmd",
    "profile-doctor.mjs",
    "install.ps1",
    "uninstall.ps1",
    "README.md",
    "README.zh-CN.md",
    "bootstrap-build-environment.ps1",
    "LICENSE"
  )) {
    if (-not (Test-Path (Join-Path $zipTestDirectory $required) -PathType Leaf)) {
      throw "Portable ZIP is missing $required."
    }
  }
  $guideCount = @(Get-ChildItem $zipTestDirectory -Filter "README*.md" -File).Count
  if ($guideCount -lt 12) { throw "Portable ZIP contains only $guideCount language guides; expected at least 12." }
} finally {
  if (Test-Path $zipTestDirectory) { Remove-Item -LiteralPath $zipTestDirectory -Recurse -Force }
}

$makensis = Get-Command makensis.exe -ErrorAction SilentlyContinue
if ($null -eq $makensis) {
  $candidate = @(
    (Join-Path ${env:ProgramFiles(x86)} "NSIS\makensis.exe"),
    (Join-Path $env:ProgramFiles "NSIS\makensis.exe")
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if ($candidate) { $makensis = Get-Command $candidate }
}
if ($null -eq $makensis) { throw "NSIS is required to build the installer. Install NSIS or build only the portable ZIP." }

$installer = Join-Path $output "DeepSeek-Harness-Setup-v$Version-x64.exe"
if (Test-Path $installer) { Remove-Item -LiteralPath $installer -Force }
& $makensis.Source "/DVERSION=$Version" "/DSTAGE_DIR=$stage" "/DOUT_FILE=$installer" (Join-Path $PSScriptRoot "installer.nsi")
if (-not (Test-Path $installer)) { throw "NSIS installer was not produced." }
$installerHeader = [IO.File]::ReadAllBytes($installer)[0..1]
if ($installerHeader[0] -ne 0x4d -or $installerHeader[1] -ne 0x5a) {
  throw "NSIS installer does not have a valid Windows MZ executable header."
}

$hashFile = Join-Path $output "DeepSeek-Harness-Windows-x64-v$Version.sha256"
@($zip, $installer) | ForEach-Object {
  "{0}  {1}" -f (Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash.ToLowerInvariant(), ([IO.Path]::GetFileName($_))
} | Set-Content -LiteralPath $hashFile -Encoding ascii

$manifestEntries = @{}
foreach ($line in Get-Content -LiteralPath $hashFile) {
  if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { throw "Invalid SHA-256 manifest line: $line" }
  $manifestEntries[$Matches[2]] = $Matches[1]
}
foreach ($artifact in @($zip, $installer)) {
  $name = [IO.Path]::GetFileName($artifact)
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifact).Hash.ToLowerInvariant()
  if ($manifestEntries[$name] -ne $actual) { throw "SHA-256 verification failed for $name." }
}

Remove-Item -LiteralPath $stage -Recurse -Force

Write-Host "Built Windows artifacts:"
Write-Host "  $zip"
Write-Host "  $installer"
Write-Host "  $hashFile"
