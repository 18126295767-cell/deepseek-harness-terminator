[CmdletBinding()]
param(
  [string]$DshRuntime = "$env:USERPROFILE\dsh-runtime",
  [ValidateRange(1, 65535)][int]$Port = 3080,
  [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$Profile = "web",
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

function Resolve-NodePath {
  $node = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($null -ne $node) { return $node.Source }
  $candidate = @(
    (Join-Path $env:ProgramFiles "nodejs\node.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe")
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if ($candidate) { return $candidate }
  throw "Node.js was not found. Install Node.js 20+ and reopen PowerShell."
}

function Wait-LocalPort {
  param([int]$PortNumber, [int]$ProcessId, [int]$TimeoutSeconds = 30)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) { throw "DeepSeek Harness Terminator exited before port $PortNumber became ready." }
    $client = [Net.Sockets.TcpClient]::new()
    try {
      $task = $client.ConnectAsync("127.0.0.1", $PortNumber)
      if ($task.Wait(250) -and $client.Connected) { return }
    } finally {
      $client.Dispose()
    }
    Start-Sleep -Milliseconds 250
  }
  throw "DeepSeek Harness Terminator did not open 127.0.0.1:$PortNumber within $TimeoutSeconds seconds."
}

function Assert-LocalPortAvailable {
  param([int]$PortNumber)
  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $PortNumber)
  try {
    $listener.Start()
  } catch {
    throw "Cannot start DeepSeek Harness Terminator because 127.0.0.1:$PortNumber is already in use."
  } finally {
    $listener.Stop()
  }
}

$runtime = (Resolve-Path -LiteralPath $DshRuntime -ErrorAction Stop).Path
$dshBin = Join-Path $runtime "node_modules\@deepseek-ai\dsh\lib\bin.js"
if (-not (Test-Path -LiteralPath $dshBin -PathType Leaf)) {
  throw "Cannot find $dshBin. Install @deepseek-ai/dsh in the runtime directory first."
}

$node = Resolve-NodePath
$doctor = @(
  (Join-Path $PSScriptRoot "profile-doctor.mjs"),
  (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "scripts\profile-doctor.mjs")
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $doctor) {
  throw "The launcher is incomplete: profile-doctor.mjs is missing."
}
$dshHome = if ($env:DSH_HOME) { [IO.Path]::GetFullPath($env:DSH_HOME) } else { Join-Path $env:USERPROFILE ".dsh" }
$profileDirectory = Join-Path $dshHome "profiles\$Profile"
& $node $doctor --runtime $runtime --profile-dir $profileDirectory
if ($LASTEXITCODE -ne 0) {
  throw "DSH profile integrity check failed. Review the conflict report above; no files were deleted."
}

$logDirectory = Join-Path $env:LOCALAPPDATA "DeepSeek Harness Terminator\logs"
$stdoutLog = Join-Path $logDirectory "dsh-web-$Port.stdout.log"
$stderrLog = Join-Path $logDirectory "dsh-web-$Port.stderr.log"
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
Assert-LocalPortAvailable -PortNumber $Port

if ($Profile -eq "web") {
  $arguments = @('"' + $dshBin + '"', "web", "--port", "$Port")
} else {
  $arguments = @('"' + $dshBin + '"', "--profile", $Profile, "--port", "$Port")
}

Write-Host "Starting DeepSeek Harness Terminator profile '$Profile' on http://127.0.0.1:$Port"
Write-Host "Runtime: $runtime"
Write-Host "Logs: $logDirectory"
$process = Start-Process -FilePath $node -ArgumentList $arguments -WorkingDirectory $runtime `
  -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog `
  -WindowStyle Hidden -PassThru

try {
  Wait-LocalPort -PortNumber $Port -ProcessId $process.Id
  if (-not $NoBrowser) {
    Start-Process "http://127.0.0.1:$Port"
  }
  Write-Host "DeepSeek Harness Terminator is ready. Press Ctrl+C to stop this launcher."
  Wait-Process -Id $process.Id
} finally {
  $running = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
  if ($null -ne $running) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
}
