# run_and_collect.ps1
# Safe launcher for this project layout (project root = folder containing package.json).
# Usage:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\run_and_collect.ps1

param(
  [int]$MockPort = 3001,
  [int]$ApiPort  = 3000,
  [int]$StartTimeoutSec = 25
)

$ErrorActionPreference = 'Stop'

function Start-NodeBackground {
  param([string]$ScriptPath, [string]$OutLog, [string]$ErrLog, [string[]]$Args = @())
  if (-not (Test-Path $ScriptPath)) { Write-Host "Script not found: $ScriptPath" -ForegroundColor Red; return $null }
  $nodeExe = "node"
  $argList = @($ScriptPath) + $Args
  $ps = Start-Process -FilePath $nodeExe -ArgumentList $argList -RedirectStandardOutput $OutLog -RedirectStandardError $ErrLog -NoNewWindow -PassThru
  return $ps
}

try {
  Write-Host "Project root: $(Get-Location)" -ForegroundColor Cyan

  if (-not (Test-Path package.json)) {
    Write-Host "Warning: package.json not found in current directory. Ensure you are in project root." -ForegroundColor Yellow
  }

  # Install deps if node_modules missing
  if (-not (Test-Path node_modules)) {
    Write-Host "Installing dependencies (npm install --legacy-peer-deps)..." -ForegroundColor Cyan
    npm install --legacy-peer-deps 2>&1 | Tee-Object -FilePath npm-install-run.log
  } else { Write-Host "node_modules exists — skipping npm install." -ForegroundColor Green }

  New-Item -Path logs -ItemType Directory -Force | Out-Null
  New-Item -Path collected_logs -ItemType Directory -Force | Out-Null

  # Start mock (scripts folder)
  $mockCandidates = @("scripts\mock_oumi.js","scripts\mock_oumi_simple.js")
  $mockStarted = $null
  foreach ($c in $mockCandidates) { if (Test-Path $c) { Write-Host "Starting mock: $c"; $mockStarted = Start-NodeBackground -ScriptPath $c -OutLog ("logs\mock_oumi.log") -ErrLog ("logs\mock_oumi.err.log"); break } }
  if (-not $mockStarted) { Write-Host "No mock script found in /scripts. Expected: mock_oumi.js or mock_oumi_simple.js" -ForegroundColor Red } else { Write-Host "Mock started PID: $($mockStarted.Id)" }

  # Start API (api folder)
  $apiCandidates = @("api\dev_server.js","api\generate.js","api\server.js")
  $apiStarted = $null
  foreach ($c in $apiCandidates) { if (Test-Path $c) { Write-Host "Starting API: $c"; $apiStarted = Start-NodeBackground -ScriptPath $c -OutLog ("logs\api.log") -ErrLog ("logs\api.err.log"); break } }
  if (-not $apiStarted) { Write-Host "No API entry script found in /api. Expected dev_server.js or generate.js" -ForegroundColor Red } else { Write-Host "API started PID: $($apiStarted.Id)" }

  # Wait for services
  $deadline = (Get-Date).AddSeconds($StartTimeoutSec)
  while ((Get-Date) -lt $deadline) {
    $mockOk = $false; $apiOk = $false
    try { $mockOk = (Test-NetConnection -ComputerName 127.0.0.1 -Port $MockPort -WarningAction SilentlyContinue).TcpTestSucceeded } catch {}
    try { $apiOk  = (Test-NetConnection -ComputerName 127.0.0.1 -Port $ApiPort  -WarningAction SilentlyContinue).TcpTestSucceeded } catch {}
    if ((($mockStarted -eq $null) -or $mockOk) -and (($apiStarted -eq $null) -or $apiOk)) { break }
    Start-Sleep -Seconds 1
  }

  Write-Host "Mock reachable: $mockOk ; API reachable: $apiOk"

  if ($apiOk) {
    Write-Host "Invoking quick test: GET http://127.0.0.1:$ApiPort/api/generate"
    try { $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/api/generate" -Method Get -TimeoutSec 10; $resp | Select-Object -First 1 | Format-List } catch { Write-Host "Test request failed: $($_.Exception.Message)" -ForegroundColor Yellow }
  } else { Write-Host "Skipping test request because API is not reachable." -ForegroundColor Yellow }

  # copy logs
  Get-ChildItem -Path logs -File -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item -Path $_.FullName -Destination ("collected_logs\" + $_.Name) -Force }
  if (Test-Path npm-install-run.log) { Copy-Item npm-install-run.log collected_logs/ -Force }

  Write-Host "Done. Logs copied to ./collected_logs"
  if ($mockStarted) { Write-Host "Mock PID: $($mockStarted.Id) -> logs\mock_oumi.log" }
  if ($apiStarted)  { Write-Host "API PID:  $($apiStarted.Id)  -> logs\api.log" }

  Write-Host ""
  Write-Host "If the API crashes on load, capture full crash output with:"
  Write-Host "  node api\dev_server.js *> api_run_capture.log ; Get-Content api_run_capture.log -Tail 500" -ForegroundColor Cyan

} catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host $_.Exception.StackTrace
  exit 1
}
