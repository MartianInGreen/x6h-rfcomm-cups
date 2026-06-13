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

echo "Installing Python dependency: Pillow"
python3 -m pip install --user Pillow

echo "Installing CLI: $cli_path"
sudo install -m 0755 "$repo_root/bin/x6h-rfcomm-print" "$cli_path"

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

echo "Creating raw CUPS queue: $printer_name -> $uri"
sudo lpadmin -p "$printer_name" -E -v "$uri" -m raw -o printer-is-shared=false
sudo lpoptions -d "$printer_name"

cat <<EOF

Installed.

Test CLI:
  x6h-rfcomm-print --addr ${addr//-/:} "Hello from CLI"

Test CUPS:
  lp -d "$printer_name" -o x6h-darkness=9500 -o x6h-font-size=32 README.md

EOF
