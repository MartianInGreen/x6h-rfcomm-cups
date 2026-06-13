#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 BLUETOOTH_MAC [PORT]" >&2
  echo "Example: $0 B7:2C:83:E6:F8:3E 8765" >&2
  exit 2
fi

addr="$1"
port="${2:-8765}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service_dir="$HOME/.config/systemd/user"
service_path="$service_dir/x6h-rfcomm-dashboard.service"

sudo install -m 0755 "$repo_root/bin/x6h-rfcomm-dashboard" /usr/local/bin/x6h-rfcomm-dashboard

install -d -m 0755 "$service_dir"
cat > "$service_path" <<EOF
[Unit]
Description=X6H RFCOMM print dashboard
After=graphical-session.target

[Service]
ExecStart=/usr/local/bin/x6h-rfcomm-dashboard --addr $addr --host 127.0.0.1 --port $port
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable x6h-rfcomm-dashboard.service
systemctl --user restart x6h-rfcomm-dashboard.service

cat <<EOF

Dashboard service installed.

Open:
  http://127.0.0.1:$port

Status:
  systemctl --user status x6h-rfcomm-dashboard.service

EOF
