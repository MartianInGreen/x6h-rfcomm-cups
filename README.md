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
- `bin/x6h-rfcomm-dashboard`: local image-printing web UI.
- CUPS backend mode: install the same executable as
  `/usr/lib/cups/backend/x6h-rfcomm`.
- `cups/x6h-rfcomm.ppd`: CUPS model with 58 mm receipt paper presets.
- `scripts/install-cups.sh`: installs the backend and creates a CUPS queue.
- `scripts/install-dashboard-service.sh`: optional user service for the web UI.

The printer uses 384-pixel-wide, 1-bit thermal bitmap lines sent over Bluetooth
RFCOMM/SPP. No `/dev/rfcomm0` binding is required.

## Requirements

- Linux with BlueZ
- Python 3
- CUPS, if you want printer integration
- `pdftoppm` from Poppler for PDF jobs
- Ghostscript for PostScript jobs

On Arch Linux:

```bash
sudo pacman -S --needed cups bluez bluez-utils python-pillow poppler ghostscript
sudo systemctl enable --now bluetooth cups
```

The installer creates a private Python runtime under
`/usr/local/lib/x6h-rfcomm-cups` when the system Python cannot import both
Pillow and `lzo`. This is required for grayscale printing on distributions
that do not package the Python LZO module.

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
  --dither none \
  --dither-strength 1.0 \
  --brightness 1.0 \
  --contrast 1.0 \
  --gamma 1.0 \
  --font-size 32 \
  --feed-lines 80 \
  --orientation auto \
  "Hello"
```

## Image Dashboard

Run the dashboard:

```bash
bin/x6h-rfcomm-dashboard --addr B7:2C:83:E6:F8:3E
```

Open:

```text
http://127.0.0.1:8765
```

The dashboard prints directly over RFCOMM and does not use CUPS page sizes. It
has file upload and clipboard paste, fixed-label and auto-length modes, live
bitmap preview, edge cropping, margin trimming, orientation control, tone
controls, darkness/speed/feed controls, and raster methods:

- No dither (threshold)
- Threshold only
- Floyd-Steinberg
- Ordered dither
- Atkinson

Dashboard-only image controls include crop-left/right/top/bottom, brightness,
contrast, gamma, invert, error-diffusion strength, ordered dither matrix size,
and serpentine diffusion.

Install it as a user service:

```bash
scripts/install-dashboard-service.sh B7:2C:83:E6:F8:3E 8765
```

The service installer always restarts `x6h-rfcomm-dashboard.service` so an
updated dashboard executable is used immediately.

## Install As A CUPS Printer

One-command install/update for the known `X6h-2CB7` printer:

```bash
./install.sh
```

That defaults to:

- Bluetooth address: `B7:2C:83:E6:F8:3E`
- CUPS printer name: `X6h-2CB7`
- Dashboard: `http://127.0.0.1:8765`

Override values if needed:

```bash
./install.sh B7:2C:83:E6:F8:3E X6h-2CB7 8765
```

From the repository root:

```bash
chmod +x scripts/install-cups.sh bin/x6h-rfcomm-print
scripts/install-cups.sh B7:2C:83:E6:F8:3E X6h-2CB7
```

The installer:

1. Installs or updates the shared runtime in `/usr/local/lib/x6h-rfcomm-cups`.
2. Creates wrappers for `/usr/local/bin/x6h-rfcomm-print` and
   `/usr/local/bin/x6h-rfcomm-dashboard`.
3. Creates a CUPS backend wrapper named `x6h-rfcomm`.
4. Restarts CUPS.
5. Creates a PPD-backed queue named `X6h-2CB7`.

Manual equivalent:

```bash
sudo install -m 0755 bin/x6h-rfcomm-print "$(cups-config --serverbin)/backend/x6h-rfcomm"
sudo systemctl restart cups
sudo lpadmin -p X6h-2CB7 -E \
  -v 'x6h-rfcomm://B7-2C-83-E6-F8-3E?channel=1' \
  -P cups/x6h-rfcomm.ppd \
  -o media=Roll58x50 \
  -o PageSize=Roll58x50
```

Test it:

```bash
lp -d X6h-2CB7 README.md
echo "Hello from CUPS" | lp -d X6h-2CB7
```

## CUPS Print Options

The included PPD exposes these receipt paper sizes in print dialogs:

- `58 mm x 20 mm tiny label`
- `58 mm x 30 mm tiny label`
- `58 mm x 40 mm short label`
- `58 mm x 50 mm short label`
- `58 mm x 60 mm short receipt`
- `58 mm x 75 mm receipt`
- `58 mm x 100 mm receipt`
- `58 mm x 150 mm receipt`
- `58 mm x 200 mm receipt`
- `58 mm x 297 mm long receipt`
- `58 mm x 500 mm long receipt`

From the command line, select them with `media` or `PageSize`:

```bash
lp -d X6h-2CB7 -o media=Roll58x50 README.md
```

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
- `x6h-dither`: `None`/no dither, `Threshold`, `Floyd-Steinberg`, `Ordered`,
  or `Atkinson`. The printer is 1-bit, so `None` still applies the selected
  threshold cutoff; it only disables patterned/error-diffusion dithering.
- `x6h-font-size`: default `32`
- `x6h-feed-lines`: default `80`
- `x6h-align`: `left`, `center`, or `right`
- `x6h-scale`: `fit-width` or `native`
- `x6h-channel`: default `1`
- `x6h-image-orientation`: `Auto`, `AsIs`, `RotateCW`, or `RotateCCW`
- `x6h-trim`: `True` or `False`
- PPD dialogs may show these as `Darkness`, `Speed`, `Threshold`, `FontSize`,
  `FeedLines`, `ImageOrientation`, and `Trim`.

You can also put stable settings in the device URI:

```bash
sudo lpadmin -p X6h-2CB7 -v 'x6h-rfcomm://B7-2C-83-E6-F8-3E?channel=1&darkness=10000'
```

## Notes

- The MAC address is written with dashes in the CUPS URI because colons are
  awkward in URI host parsing. The backend converts dashes back to colons.
- The CUPS queue uses a small PPD so desktop print dialogs show 58 mm receipt
  paper sizes. The backend accepts text, common image formats, PDF, and
  PostScript directly.
- Images are trimmed and auto-oriented by default because desktop print dialogs
  often add page margins or rotate content on very short receipt sizes. Disable
  that with `-o Trim=False -o ImageOrientation=AsIs`, or force it with
  `-o ImageOrientation=RotateCW`.
- PDF support requires `pdftoppm`; PostScript support requires `gs`.
- If another phone app is connected to the printer, disconnect it before
  printing from Linux.

## License

MIT
