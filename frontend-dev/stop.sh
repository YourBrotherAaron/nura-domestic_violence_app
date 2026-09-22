#!/usr/bin/env bash
# Stops any frontend started in the background by start.sh (macOS / Linux).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for name in dashboard mobile; do
  pid_file="$here/$name.pid"
  if [ -f "$pid_file" ]; then
    pid="$(cat "$pid_file")"
    if kill "$pid" >/dev/null 2>&1; then echo "Stopped $name (pid $pid)."; fi
    rm -f "$pid_file"
  fi
done
echo "Done. (Foreground apps are stopped with Ctrl+C in their own window.)"
