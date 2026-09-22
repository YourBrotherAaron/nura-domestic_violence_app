#!/usr/bin/env bash
# ============================================================================
# Nura / EviSafe — local frontend launcher (macOS / Linux)
# ============================================================================
# For designers/developers working on the UI. Installs dependencies and starts
# the legal dashboard and/or the mobile app, pointed at the EduCloud backend.
#
# First time only:  chmod +x start.sh
# Then run:         ./start.sh
# ============================================================================
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
dashboard="$root/legal-dashboard-frontend"
mobile="$root/mobile-app-frontend/domestic-violence-app"
url_file="$here/backend-url.txt"
log_dir="$here/logs"
mkdir -p "$log_dir"

fail() { printf "\n  ERROR: %s\n" "$1" >&2; exit 1; }

echo "=================================================="
echo "  Nura / EviSafe - local frontend launcher"
echo "=================================================="
echo

# --- Prerequisite: Node.js -------------------------------------------------
command -v node >/dev/null 2>&1 || fail "Node.js is not installed. Install the LTS version from https://nodejs.org then re-run this."
echo "Node.js $(node --version) detected."
echo

# --- Backend URL (asked once, remembered) ----------------------------------
backend_url=""
[ -f "$url_file" ] && backend_url="$(tr -d '[:space:]' < "$url_file")"
if [ -z "$backend_url" ]; then
  echo "Enter the EduCloud backend address (the VM's IP and port 8000)."
  echo "Example: http://145.28.10.42:8000"
  echo
  read -r -p "Backend URL: " backend_url
  [ -z "$backend_url" ] && fail "No backend URL entered."
  case "$backend_url" in http://*|https://*) ;; *) backend_url="http://$backend_url" ;; esac
  printf "%s" "$backend_url" > "$url_file"
fi
echo "Using backend: $backend_url"
echo "(To change it later, delete backend-url.txt in this folder.)"
echo

# --- Menu ------------------------------------------------------------------
echo "What would you like to run?"
echo "  [1] Legal dashboard (browser)"
echo "  [2] Mobile app (Expo)"
echo "  [3] Both"
echo
read -r -p "Choice (1/2/3): " choice

ensure_deps() { # dir, name
  if [ ! -d "$1/node_modules" ]; then
    echo
    echo "Installing $2 dependencies (first run only, may take a few minutes)..."
    ( cd "$1" && npm install ) || fail "npm install failed for $2."
  fi
}

start_dashboard() {
  [ -d "$dashboard" ] || fail "Dashboard folder not found: $dashboard"
  # Gitignored env override: proxy /api to EduCloud + demo auto-login. No
  # existing files are modified.
  # VITE_WHISPER_URL is blanked so transcription routes through the backend
  # (which reaches Whisper internally) instead of a browser->Whisper call.
  cat > "$dashboard/.env.development.local" <<EOF
API_PROXY_TARGET=$backend_url
VITE_API_URL=/api
VITE_DASHBOARD_AUTO_LOGIN=true
VITE_DASHBOARD_EMAIL=demo@example.com
VITE_DASHBOARD_PASSWORD=DemoPass123!
VITE_WHISPER_URL=
EOF
  ensure_deps "$dashboard" "dashboard"
}

start_mobile() {
  [ -d "$mobile" ] || fail "Mobile app folder not found: $mobile"
  echo "EXPO_PUBLIC_API_URL=$backend_url" > "$mobile/.env"
  ensure_deps "$mobile" "mobile app"
}

run_bg() { # dir, cmd, logname  -> runs in background with a log file
  ( cd "$1" && nohup bash -c "$2" > "$log_dir/$3.log" 2>&1 & echo $! > "$here/$3.pid" )
  echo "  -> $3 starting; logs: frontend-dev/logs/$3.log"
}

case "$choice" in
  1)
    start_dashboard
    echo; echo "Starting dashboard in the foreground. Open http://localhost:5173"
    echo "Press Ctrl+C to stop."; echo
    ( cd "$dashboard" && npm run dev )
    ;;
  2)
    start_mobile
    echo; echo "Starting Expo in the foreground. Press 'w' for web, or scan the QR with Expo Go."
    echo "Press Ctrl+C to stop."; echo
    ( cd "$mobile" && npx expo start )
    ;;
  3)
    start_dashboard
    start_mobile
    echo
    run_bg "$dashboard" "npm run dev" "dashboard"
    echo; echo "Dashboard running in the background (http://localhost:5173)."
    echo "Starting Expo in the foreground now. Press Ctrl+C to stop Expo;"
    echo "then run ./stop.sh to stop the dashboard."; echo
    ( cd "$mobile" && npx expo start )
    ;;
  *)
    fail "Invalid choice: $choice"
    ;;
esac
