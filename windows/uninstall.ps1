[CmdletBinding()]
param(
  [string]$InstallDirectory = "$env:LOCALAPPDATA\DeepSeek Harness Terminator"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$target = [IO.Path]::GetFullPath($InstallDirectory)
$root = [IO.Path]::GetPathRoot($target)
if ($target.TrimEnd('\') -eq $root.TrimEnd('\')) {
  throw "InstallDirectory must not be a drive root."
}
if ($target.TrimEnd('\') -eq [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')) {
  throw "InstallDirectory must not be the user profile directory."
}
$shortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\DeepSeek Harness Terminator\DeepSeek Harness Terminator.lnk"
if (Test-Path $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force }
$shortcutDirectory = Split-Path $shortcutPath -Parent
if (Test-Path $shortcutDirectory) { Remove-Item -LiteralPath $shortcutDirectory -Force }
if (Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force }
Write-Host "Removed the Windows launcher. The DSH runtime and profile were not deleted."
