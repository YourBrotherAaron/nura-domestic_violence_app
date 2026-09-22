# ============================================================================
# Nura / EviSafe — local frontend launcher (Windows)
# ============================================================================
# For designers/developers working on the UI. Installs dependencies and starts
# the legal dashboard and/or the mobile app, pointed at the EduCloud backend.
#
# Just double-click start.bat (which runs this), or run:  ./start.ps1
# ============================================================================

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$dashboard = Join-Path $root "legal-dashboard-frontend"
$mobile = Join-Path $root "mobile-app-frontend\domestic-violence-app"
$urlFile = Join-Path $here "backend-url.txt"

function Fail($msg) { Write-Host "`n  ERROR: $msg" -ForegroundColor Red; Read-Host "`nPress Enter to close"; exit 1 }

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Nura / EviSafe - local frontend launcher" -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan

# --- Prerequisite: Node.js -------------------------------------------------
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Fail "Node.js is not installed. Install the LTS version from https://nodejs.org then re-run this."
}
Write-Host ("Node.js " + (node --version) + " detected.`n") -ForegroundColor Green

# --- Backend URL (asked once, remembered) ----------------------------------
$backendUrl = $null
if (Test-Path $urlFile) { $backendUrl = (Get-Content $urlFile -Raw).Trim() }
if ([string]::IsNullOrWhiteSpace($backendUrl)) {
    Write-Host "Enter the EduCloud backend address (the VM's IP and port 8000)." -ForegroundColor Yellow
    Write-Host "Example: http://145.28.10.42:8000`n" -ForegroundColor DarkGray
    $backendUrl = (Read-Host "Backend URL").Trim()
    if ([string]::IsNullOrWhiteSpace($backendUrl)) { Fail "No backend URL entered." }
    if ($backendUrl -notmatch "^https?://") { $backendUrl = "http://$backendUrl" }
    Set-Content -Path $urlFile -Value $backendUrl -Encoding UTF8
}
Write-Host "Using backend: $backendUrl" -ForegroundColor Green
Write-Host "(To change it later, delete backend-url.txt in this folder.)`n" -ForegroundColor DarkGray

# --- Menu ------------------------------------------------------------------
Write-Host "What would you like to run?"
Write-Host "  [1] Legal dashboard (browser)"
Write-Host "  [2] Mobile app (Expo)"
Write-Host "  [3] Both"
$choice = (Read-Host "`nChoice (1/2/3)").Trim()

function Ensure-Deps($dir, $name) {
    if (-not (Test-Path (Join-Path $dir "node_modules"))) {
        Write-Host "`nInstalling $name dependencies (first run only, may take a few minutes)..." -ForegroundColor Yellow
        Push-Location $dir
        npm install
        if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "npm install failed for $name." }
        Pop-Location
    }
}

function Start-Dashboard {
    if (-not (Test-Path $dashboard)) { Fail "Dashboard folder not found: $dashboard" }
    # Write a gitignored env override so the dashboard proxies /api to EduCloud
    # and auto-logs in with the demo account. No existing files are modified.
    # VITE_WHISPER_URL is blanked so transcription routes through the backend
    # (which reaches Whisper internally) instead of a browser->Whisper call.
    $env_content = @"
API_PROXY_TARGET=$backendUrl
VITE_API_URL=/api
VITE_DASHBOARD_AUTO_LOGIN=true
VITE_DASHBOARD_EMAIL=demo@example.com
VITE_DASHBOARD_PASSWORD=DemoPass123!
VITE_WHISPER_URL=
"@
    Set-Content -Path (Join-Path $dashboard ".env.development.local") -Value $env_content -Encoding UTF8
    Ensure-Deps $dashboard "dashboard"
    Write-Host "`nStarting the legal dashboard... a new window will open." -ForegroundColor Green
    Write-Host "Open http://localhost:5173 in your browser once it says 'ready'." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd '$dashboard'; npm run dev"
}

function Start-Mobile {
    if (-not (Test-Path $mobile)) { Fail "Mobile app folder not found: $mobile" }
    # Public VM IP works for phone, emulator, and web alike.
    Set-Content -Path (Join-Path $mobile ".env") -Value "EXPO_PUBLIC_API_URL=$backendUrl" -Encoding UTF8
    Ensure-Deps $mobile "mobile app"
    Write-Host "`nStarting the mobile app (Expo)... a new window will open." -ForegroundColor Green
    Write-Host "Press 'w' for web, or scan the QR code with Expo Go on your phone." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit","-Command","cd '$mobile'; npx expo start"
}

switch ($choice) {
    "1" { Start-Dashboard }
    "2" { Start-Mobile }
    "3" { Start-Dashboard; Start-Mobile }
    default { Fail "Invalid choice: $choice" }
}

Write-Host "`nDone. The app(s) are starting in their own window(s)." -ForegroundColor Cyan
Write-Host "Close those windows to stop them.`n"
Read-Host "Press Enter to close this launcher"
