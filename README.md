# x6h-rfcomm-cups

Minimal Linux printer support for X6H-style thermal printers that expose a
Bluetooth Serial Port / RFCOMM channel instead of the BLE `AE01` GATT endpoint.

Tested with:

- `X6h-2CB7`
- Bluetooth address `B7:2C:83:E6:F8:3E`
- RFCOMM channel `1`

This is intended for the X6H units where BLE tools can scan the device but fail
to print with a BlueZ error like:

```text
org.bluez.Error.BREDR.ProfileUnavailable
```

## What It Provides

- `bin/x6h-rfcomm-print`: direct CLI printer script.
- CUPS backend mode: install the same executable as
  `/usr/lib/cups/backend/x6h-rfcomm`.
- `scripts/install-cups.sh`: installs the backend and creates a raw CUPS queue.

The printer uses 384-pixel-wide, 1-bit thermal bitmap lines sent over Bluetooth
RFCOMM/SPP. No `/dev/rfcomm0` binding is required.

## Requirements

- Linux with BlueZ
- Python 3
- Pillow
- CUPS, if you want printer integration
- `pdftoppm` from Poppler for PDF jobs
- Ghostscript for PostScript jobs

On Arch Linux:

```bash
sudo pacman -S --needed cups bluez bluez-utils python-pillow poppler ghostscript
sudo systemctl enable --now bluetooth cups
```

On Debian/Ubuntu:

```bash
sudo apt install cups bluez python3-pil poppler-utils ghostscript
sudo systemctl enable --now bluetooth cups
```

## Direct CLI Use

```bash
bin/x6h-rfcomm-print --addr B7:2C:83:E6:F8:3E "Hello from RFCOMM"
```

Print a file:

```bash
bin/x6h-rfcomm-print --addr B7:2C:83:E6:F8:3E --file receipt.pdf
bin/x6h-rfcomm-print --addr B7:2C:83:E6:F8:3E --file image.png
bin/x6h-rfcomm-print --addr B7:2C:83:E6:F8:3E --file notes.txt
```

Useful options:

```bash
bin/x6h-rfcomm-print \
  --addr B7:2C:83:E6:F8:3E \
  --darkness 9500 \
  --speed 10 \
  --quality 3 \
  --threshold 180 \
  --font-size 32 \
  --feed-lines 80 \
  "Hello"
```

## Install As A CUPS Printer

From the repository root:

```bash
chmod +x scripts/install-cups.sh bin/x6h-rfcomm-print
scripts/install-cups.sh B7:2C:83:E6:F8:3E X6h-2CB7
```

The installer:

1. Copies the CLI to `/usr/local/bin/x6h-rfcomm-print`.
2. Copies the same executable to the CUPS backend directory as `x6h-rfcomm`.
3. Installs Pillow through the system package manager if it is missing.
4. Restarts CUPS.
5. Creates a raw queue named `X6h-2CB7`.

Manual equivalent:

```bash
sudo install -m 0755 bin/x6h-rfcomm-print "$(cups-config --serverbin)/backend/x6h-rfcomm"
sudo systemctl restart cups
sudo lpadmin -p X6h-2CB7 -E -v 'x6h-rfcomm://B7-2C-83-E6-F8-3E?channel=1' -m raw
```

Test it:

```bash
lp -d X6h-2CB7 README.md
echo "Hello from CUPS" | lp -d X6h-2CB7
```

## CUPS Print Options

Pass options with `lp -o`:

```bash
lp -d X6h-2CB7 \
  -o x6h-darkness=9500 \
  -o x6h-speed=10 \
  -o x6h-quality=3 \
  -o x6h-threshold=180 \
  -o x6h-font-size=32 \
  -o x6h-feed-lines=80 \
  README.md
```

Supported option names:

- `x6h-darkness` or `x6h-energy`: default `9500`
- `x6h-speed`: default `10`
- `x6h-quality`: default `3`
- `x6h-threshold`: default `180`
- `x6h-font-size`: default `32`
- `x6h-feed-lines`: default `80`
- `x6h-align`: `left`, `center`, or `right`
- `x6h-scale`: `fit-width` or `native`
- `x6h-channel`: default `1`

You can also put stable settings in the device URI:

```bash
sudo lpadmin -p X6h-2CB7 -v 'x6h-rfcomm://B7-2C-83-E6-F8-3E?channel=1&darkness=10000'
```

## Notes

- The MAC address is written with dashes in the CUPS URI because colons are
  awkward in URI host parsing. The backend converts dashes back to colons.
- The CUPS queue is raw on purpose. The backend accepts text, common image
  formats, PDF, and PostScript directly.
- PDF support requires `pdftoppm`; PostScript support requires `gs`.
- If another phone app is connected to the printer, disconnect it before
  printing from Linux.

## License

MIT
