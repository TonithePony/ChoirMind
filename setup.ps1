# ChoirMind one-shot environment setup (Windows PowerShell)
# Usage: .\setup.ps1
# Optional: $env:OPENAI_API_KEY = "sk-..."; .\setup.ps1

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Web = Join-Path $Root "web"
$Backend = Join-Path $Root "backend"

function Write-Step($msg) { Write-Host "→ $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "! $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "✗ $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "╔══════════════════════════════════════╗"
Write-Host "║     ChoirMind Environment Setup      ║"
Write-Host "╚══════════════════════════════════════╝"
Write-Host ""

# ── Prerequisites ──────────────────────────────────────────────
Write-Step "Checking prerequisites…"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Fail "Node.js is required. Install from https://nodejs.org (18+)."
}
$nodeVersion = (node -p "process.versions.node")
if ([version]$nodeVersion -lt [version]"18.0.0") {
    Write-Fail "Node.js 18+ required (found $nodeVersion)."
}
Write-Ok "Node.js $nodeVersion"

$python = $null
foreach ($candidate in @("python3.13", "python3.12", "python3.11", "python3.10", "python", "py")) {
    if ($candidate -eq "py") {
        if (Get-Command py -ErrorAction SilentlyContinue) {
            try {
                $ver = py -3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
                $parts = $ver.Split(".")
                if ([int]$parts[0] -ge 3 -and [int]$parts[1] -ge 10) {
                    $python = "py -3"
                    break
                }
            } catch { continue }
        }
    } elseif (Get-Command $candidate -ErrorAction SilentlyContinue) {
        try {
            $ver = Invoke-Expression "$candidate -c `"import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')`""
            $parts = $ver.Split(".")
            if ([int]$parts[0] -ge 3 -and [int]$parts[1] -ge 10) {
                $python = $candidate
                break
            }
        } catch { continue }
    }
}

if ($python) {
    $pyVersion = Invoke-Expression "$python -c `"import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')`""
    Write-Ok "Python $pyVersion ($python)"
} else {
    Write-Warn "Python 3.10+ not found — skipping analysis backend (web app will still work)"
}

# ── Environment files ──────────────────────────────────────────
Write-Step "Setting up environment files…"

$envExample = Join-Path $Web ".env.example"
if (-not (Test-Path $envExample)) {
    Write-Fail "Missing $envExample"
}

foreach ($name in @(".env", ".env.local")) {
    $dest = Join-Path $Web $name
    if (Test-Path $dest) {
        Write-Warn "Keeping existing $name"
    } else {
        Copy-Item $envExample $dest
        Write-Ok "Created $name"
    }
}

if (-not $env:OPENAI_API_KEY) {
    $key = Read-Host "OpenAI API key (optional — press Enter to skip)"
    if ($key) { $env:OPENAI_API_KEY = $key }
}

if ($env:OPENAI_API_KEY) {
    foreach ($name in @(".env", ".env.local")) {
        $file = Join-Path $Web $name
        $content = Get-Content $file -Raw
        $content = $content -replace "OPENAI_API_KEY=.*", "OPENAI_API_KEY=$($env:OPENAI_API_KEY)"
        Set-Content $file $content -NoNewline
    }
    Write-Ok "OpenAI API key saved to .env files"
} else {
    Write-Warn "No OpenAI API key — AI coach will use built-in rule-based feedback"
}

# ── Web app ────────────────────────────────────────────────────
Write-Step "Installing web dependencies…"
Push-Location $Web
npm install
Write-Ok "npm packages installed"

Write-Step "Initializing database…"
npx prisma generate
npx prisma db push
Write-Ok "Database schema applied"

Write-Step "Seeding demo data…"
npm run db:seed
Write-Ok "Demo choir data seeded"
Pop-Location

# ── Python backend ─────────────────────────────────────────────
if ($python) {
    Write-Step "Setting up Python analysis backend…"

    $venv = Join-Path $Backend "venv"
    if (-not (Test-Path $venv)) {
        Invoke-Expression "$python -m venv `"$venv`""
        Write-Ok "Created Python virtual environment"
    } else {
        Write-Warn "Reusing existing backend\venv"
    }

    $pip = Join-Path $venv "Scripts\pip.exe"
    & $pip install --upgrade pip --quiet
    & $pip install -r (Join-Path $Backend "requirements.txt") --quiet
    Write-Ok "Python dependencies installed"
} else {
    Write-Warn "Install Python 3.10+ and re-run .\setup.ps1 to enable the analysis backend"
}

# ── Done ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Start the app:"
Write-Host ""
Write-Host "  Web (required):"
Write-Host "    cd web; npm run dev"
Write-Host "    → http://localhost:3000"
Write-Host ""
Write-Host "  Analysis backend (optional):"
Write-Host "    cd backend; .\venv\Scripts\Activate.ps1; uvicorn main:app --reload --port 8000"
Write-Host ""
Write-Host "Or run both at once:"
Write-Host "    .\start.ps1"
Write-Host ""
