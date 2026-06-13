#!/usr/bin/env bash
set -euo pipefail

addr="${1:-${X6H_ADDR:-B7:2C:83:E6:F8:3E}}"
printer_name="${2:-${X6H_PRINTER_NAME:-X6h-2CB7}}"
dashboard_port="${3:-${X6H_DASHBOARD_PORT:-8765}}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing X6H RFCOMM support"
echo "  Printer:   $printer_name"
echo "  Bluetooth: $addr"
echo "  Dashboard: http://127.0.0.1:$dashboard_port"
echo

"$repo_root/scripts/install-cups.sh" "$addr" "$printer_name"
"$repo_root/scripts/install-dashboard-service.sh" "$addr" "$dashboard_port"

cat <<EOF

Done.

Dashboard:
  http://127.0.0.1:$dashboard_port

CUPS test:
  echo "Hello from X6H" | lp -d "$printer_name"

Dashboard service:
  systemctl --user status x6h-rfcomm-dashboard.service

EOF
