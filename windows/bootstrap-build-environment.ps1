[CmdletBinding()]
param(
  [string]$DshRuntime = "$env:USERPROFILE\dsh-runtime",
  [switch]$SkipDshRuntime
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw "This bootstrap script must run on Windows 10 or Windows 11."
}
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
  throw "winget is required. Install App Installer from the Microsoft Store first."
}

function Install-WingetPackage {
  param([Parameter(Mandatory = $true)][string]$Id)
  $installed = winget list --id $Id --exact --accept-source-agreements 2>$null
  if (-not ($installed | Select-String -SimpleMatch $Id)) {
    winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget failed to install $Id with exit code $LASTEXITCODE." }
  }
}

Install-WingetPackage "Git.Git"
Install-WingetPackage "OpenJS.NodeJS.LTS"
Install-WingetPackage "NSIS.NSIS"

$nsisCandidate = @(
  (Join-Path ${env:ProgramFiles(x86)} "NSIS\makensis.exe"),
  (Join-Path $env:ProgramFiles "NSIS\makensis.exe")
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $nsisCandidate) { throw "NSIS installation did not provide makensis.exe." }

$env:Path = "$(Split-Path $nsisCandidate);$env:Path"
$nodeDirectory = Join-Path $env:ProgramFiles "nodejs"
$gitDirectory = Join-Path $env:ProgramFiles "Git\cmd"
foreach ($directory in @($nodeDirectory, $gitDirectory)) {
  if (Test-Path $directory) { $env:Path = "$directory;$env:Path" }
}
if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
  throw "Node.js was installed but is not visible in this PowerShell session. Reopen PowerShell and rerun."
}
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
  throw "Git was installed but is not visible in this PowerShell session. Reopen PowerShell and rerun."
}
if (-not (Get-Command makensis.exe -ErrorAction SilentlyContinue)) {
  throw "NSIS was installed but is not visible in this PowerShell session. Reopen PowerShell and rerun."
}

if (-not $SkipDshRuntime) {
  New-Item -ItemType Directory -Force -Path $DshRuntime | Out-Null
  Push-Location $DshRuntime
  try {
    if (-not (Test-Path "package.json")) { npm init -y | Out-Host }
    npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7 | Out-Host
  } finally {
    Pop-Location
  }
  if (-not (Test-Path (Join-Path $DshRuntime "node_modules\@deepseek-ai\dsh\lib\bin.js"))) {
    throw "The official DSH runtime was not installed at $DshRuntime."
  }
}

Write-Host "Windows build environment is ready."
Write-Host "Node: $((Get-Command node.exe).Source)"
Write-Host "NSIS: $nsisCandidate"
if (-not $SkipDshRuntime) { Write-Host "DSH runtime: $DshRuntime" }
