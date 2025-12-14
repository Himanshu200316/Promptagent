# run_all.ps1 - launches mock + api in new PowerShell windows, waits, then runs a test request
$cwd = (Get-Location).Path
$startMock = Join-Path $cwd "scripts\start_mock.ps1"
$startApi   = Join-Path $cwd "scripts\start_api.ps1"

# Launch mock in new window
Start-Process -FilePath "powershell" -ArgumentList "-NoExit","-File",$startMock

# Launch API in new window
Start-Process -FilePath "powershell" -ArgumentList "-NoExit","-File",$startApi

Start-Sleep -Seconds 5

# Run a test request (shadow mode)
try {
  $payload = @{ product_name = 'Nimbus Camera'; tagline = 'Capture the sky'; shadow = $true } | ConvertTo-Json -Compress
  Write-Host "Sending test request to http://localhost:3000/api/generate ..."
  $resp = Invoke-RestMethod -Uri 'http://localhost:3000/api/generate' -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 30
  Write-Host "Response:"
  $resp | ConvertTo-Json -Depth 5 | Write-Host
} catch {
  Write-Error "Test request failed: $($_.Exception.Message)"
  Write-Host "Check logs: $cwd\mock_oumi.log and $cwd\api.log"
}
