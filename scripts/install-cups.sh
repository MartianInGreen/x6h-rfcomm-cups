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
runtime_dir="/usr/local/lib/x6h-rfcomm-cups"
venv_dir="$runtime_dir/venv"
runtime_print="$runtime_dir/x6h-rfcomm-print"
runtime_dashboard="$runtime_dir/x6h-rfcomm-dashboard"
ppd_path="$repo_root/cups/x6h-rfcomm.ppd"

if [[ ! -f "$ppd_path" ]]; then
  echo "Missing PPD: $ppd_path" >&2
  exit 1
fi

runtime_python="$(command -v python3)"
if python3 -s -c 'import PIL, lzo' >/dev/null 2>&1; then
  echo "System Python dependencies already installed: Pillow and lzo"
else
  echo "Creating/updating private Python runtime: $venv_dir"
  sudo install -d -m 0755 "$runtime_dir"
  sudo python3 -m venv "$venv_dir"
  sudo "$venv_dir/bin/python" -m pip install --upgrade pip
  sudo "$venv_dir/bin/python" -m pip install -r "$repo_root/requirements.txt"
  runtime_python="$venv_dir/bin/python"
fi

echo "Installing runtime files: $runtime_dir"
sudo install -d -m 0755 "$runtime_dir"
sudo install -m 0755 "$repo_root/bin/x6h-rfcomm-print" "$runtime_print"
sudo install -m 0755 "$repo_root/bin/x6h-rfcomm-dashboard" "$runtime_dashboard"

echo "Installing CLI wrapper: $cli_path"
sudo tee "$cli_path" >/dev/null <<EOF
#!/usr/bin/env bash
exec "$runtime_python" "$runtime_print" "\$@"
EOF
sudo chmod 0755 "$cli_path"

echo "Installing dashboard wrapper: $dashboard_path"
sudo tee "$dashboard_path" >/dev/null <<EOF
#!/usr/bin/env bash
exec "$runtime_python" "$runtime_dashboard" "\$@"
EOF
sudo chmod 0755 "$dashboard_path"

echo "Installing CUPS backend wrapper: $backend_path"
sudo install -d -m 0755 "$backend_dir"
sudo tee "$backend_path" >/dev/null <<EOF
#!/usr/bin/env bash
export X6H_CUPS_BACKEND=1
exec "$runtime_python" "$runtime_print" "\$@"
EOF
sudo chmod 0755 "$backend_path"

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
