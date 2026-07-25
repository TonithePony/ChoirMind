# Start ChoirMind web app + analysis backend together (Windows)
# Usage: .\start.ps1

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Web = Join-Path $Root "web"
$Backend = Join-Path $Root "backend"

if (-not (Test-Path (Join-Path $Web "node_modules")) -or -not (Test-Path (Join-Path $Backend "venv"))) {
    Write-Host "Environment not set up yet. Run .\setup.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "Starting ChoirMind…"
Write-Host "  Web:      http://localhost:3000"
Write-Host "  Analysis: http://localhost:8000"
Write-Host "  Press Ctrl+C to stop both"
Write-Host ""

$backendJob = Start-Job -ScriptBlock {
    Set-Location $using:Backend
    & ".\venv\Scripts\Activate.ps1"
    uvicorn main:app --reload --port 8000
}

Push-Location $Web
try {
    npm run dev
} finally {
    Stop-Job $backendJob -ErrorAction SilentlyContinue
    Remove-Job $backendJob -ErrorAction SilentlyContinue
    Pop-Location
}
