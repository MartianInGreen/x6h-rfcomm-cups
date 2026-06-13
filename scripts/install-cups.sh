#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 BLUETOOTH_MAC [PRINTER_NAME]" >&2
  echo "Example: $0 B7:2C:83:E6:F8:3E X6h-2CB7" >&2
  exit 2
fi

addr="${1//:/-}"
printer_name="${2:-X6h-RFCOMM}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v cups-config >/dev/null 2>&1; then
  cups_serverbin="$(cups-config --serverbin)"
else
  cups_serverbin="/usr/lib/cups"
fi

backend_dir="$cups_serverbin/backend"
backend_path="$backend_dir/x6h-rfcomm"
cli_path="/usr/local/bin/x6h-rfcomm-print"
dashboard_path="/usr/local/bin/x6h-rfcomm-dashboard"
ppd_path="$repo_root/cups/x6h-rfcomm.ppd"

if [[ ! -f "$ppd_path" ]]; then
  echo "Missing PPD: $ppd_path" >&2
  exit 1
fi

if ! python3 -s -c 'import PIL' >/dev/null 2>&1; then
  echo "Installing Python dependency: Pillow"
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed python-pillow
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y python3-pil
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3-pillow
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y python3-Pillow
  else
    echo "Could not find a supported package manager." >&2
    echo "Install Pillow for the system Python, then rerun this script." >&2
    exit 1
  fi
else
  echo "Python dependency already installed: Pillow"
fi

echo "Installing CLI: $cli_path"
sudo install -m 0755 "$repo_root/bin/x6h-rfcomm-print" "$cli_path"

echo "Installing dashboard: $dashboard_path"
sudo install -m 0755 "$repo_root/bin/x6h-rfcomm-dashboard" "$dashboard_path"

echo "Installing CUPS backend: $backend_path"
sudo install -d -m 0755 "$backend_dir"
sudo install -m 0755 "$repo_root/bin/x6h-rfcomm-print" "$backend_path"

echo "Restarting CUPS"
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl restart cups || sudo systemctl restart org.cups.cupsd
else
  sudo service cups restart
fi

uri="x6h-rfcomm://$addr?channel=1"

echo "Creating CUPS queue: $printer_name -> $uri"
sudo lpadmin \
  -p "$printer_name" \
  -E \
  -v "$uri" \
  -P "$ppd_path" \
  -o printer-is-shared=false \
  -o media=Roll58x50 \
  -o PageSize=Roll58x50
sudo lpoptions -d "$printer_name"

cat <<EOF

Installed.

Test CLI:
  x6h-rfcomm-print --addr ${addr//-/:} "Hello from CLI"

Test dashboard:
  x6h-rfcomm-dashboard --addr ${addr//-/:}

Test CUPS:
  lp -d "$printer_name" -o x6h-darkness=9500 -o x6h-font-size=32 README.md

EOF
