#!/usr/bin/env bash
# Render the raster icons that image/favicon.svg cannot cover on its own:
#
#   favicon.ico                  32 + 16 px, for browsers that ignore SVG
#                                favicons and for the bare /favicon.ico that
#                                every browser requests whether it is linked
#                                or not -- hence repo root, not image/.
#   image/apple-touch-icon.png   180x180 opaque, for iOS home screens.
#
# Run by hand after editing image/favicon.svg -- the outputs are committed
# artifacts (the site has no build step). `make icons` is the entry point.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ ! -x "$chrome" ]]; then
    echo "Chrome not found at: $chrome" >&2
    echo "Override with: make icons CHROME=/path/to/chrome" >&2
    exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick (magick) not found -- brew install imagemagick" >&2
    exit 1
fi

# Both go through scripts/icon.html rather than rasterizing image/favicon.svg
# directly -- headless Chrome on macOS floors the layout viewport at ~485px (see
# the `shot` target's note in the Makefile), which stretches a standalone SVG
# document and clips one magnified corner into the screenshot. A sized div whose
# box matches the requested capture size is immune. Both are rendered at 4x and
# downscaled: the bars carry 2.5px corner radii at 32px, which alias badly
# rendered straight at target size.
#
# --default-background-color=00000000 keeps the .ico transparent; without it
# Chrome paints the page white and the icon ships with a white block behind it.
"$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=4 --window-size=32,32 \
    --default-background-color=00000000 --screenshot="$tmp/mark.png" \
    "file://$root/scripts/icon.html?v=ico" >/dev/null 2>&1
magick "$tmp/mark.png" -background none \
    -define icon:auto-resize=32,16 "$root/favicon.ico"
echo "wrote favicon.ico (32 + 16 px)"

"$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=4 --window-size=180,180 \
    --screenshot="$tmp/touch.png" \
    "file://$root/scripts/icon.html?v=touch" >/dev/null 2>&1
magick "$tmp/touch.png" -resize 180x180 -strip \
    "$root/image/apple-touch-icon.png"
echo "wrote image/apple-touch-icon.png ($(magick "$root/image/apple-touch-icon.png" -format '%wx%h' info:))"
