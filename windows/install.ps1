[CmdletBinding()]
param(
  [string]$InstallDirectory = "$env:LOCALAPPDATA\DeepSeek Harness Terminator"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$sourceDirectories = @(
  (Resolve-Path $PSScriptRoot).Path,
  (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)
$target = [IO.Path]::GetFullPath($InstallDirectory)
if ($sourceDirectories | Where-Object { $target.TrimEnd('\') -eq $_.TrimEnd('\') }) {
  throw "InstallDirectory must not be the source directory."
}
if ($target.TrimEnd('\') -eq [IO.Path]::GetPathRoot($target).TrimEnd('\')) {
  throw "InstallDirectory must not be a drive root."
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "launch-dsh.ps1") -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "launch-dsh.cmd") -Destination $target -Force
$doctorSource = @(
  (Join-Path $PSScriptRoot "profile-doctor.mjs"),
  (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "scripts\profile-doctor.mjs")
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $doctorSource) { throw "profile-doctor.mjs is missing." }
Copy-Item -LiteralPath $doctorSource -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "uninstall.ps1") -Destination $target -Force
Get-ChildItem $PSScriptRoot -Filter "README*.md" -File | Copy-Item -Destination $target -Force
$licenseSource = Join-Path $PSScriptRoot "LICENSE"
if (-not (Test-Path $licenseSource -PathType Leaf)) {
  $licenseSource = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "LICENSE"
}
Copy-Item -LiteralPath $licenseSource -Destination $target -Force

$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\DeepSeek Harness Terminator"
New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
$shortcutPath = Join-Path $startMenu "DeepSeek Harness Terminator.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $target "launch-dsh.cmd"
$shortcut.WorkingDirectory = $target
$shortcut.Description = "Start the local DeepSeek Harness runtime with DeepSeek Harness Terminator"
$shortcut.Save()

Write-Host "Installed Windows launcher to $target"
Write-Host "Start Menu shortcut: $shortcutPath"
Write-Host "The official DSH runtime must be installed separately."
