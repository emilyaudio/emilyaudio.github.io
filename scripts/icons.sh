#!/usr/bin/env bash
# Render the raster icons that image/favicon.svg cannot cover on its own:
#
#   favicon.ico                  32 + 16 px, transparent, for browsers that
#                                ignore SVG favicons and for the bare
#                                /favicon.ico that every browser requests
#                                whether it is linked or not -- hence repo
#                                root, not image/.
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

# Two failure modes that are invisible in the output, so check them here rather
# than discovering them in a browser tab months later:
#
#   1. image/favicon.svg must be well-formed XML. It is served as
#      image/svg+xml, so a browser rejects the whole document on any parse
#      error and silently falls back to favicon.ico. A double hyphen inside a
#      comment (writing a CSS custom property in full, or an em dash) is the
#      easy way to break it, and it shipped that way once.
#   2. The four rects are duplicated between favicon.svg and icon.html on
#      purpose (see icon.html). Nothing keeps them in step but this check.
python3 - "$root" <<'PY'
import re, sys, xml.etree.ElementTree as ET
root = sys.argv[1]
svg, html = f"{root}/image/favicon.svg", f"{root}/scripts/icon.html"

try:
    ET.parse(svg)
except ET.ParseError as e:
    sys.exit(f"image/favicon.svg is not well-formed XML: {e}\n"
             "Browsers will reject it and fall back to favicon.ico.")

def rects(path):
    out = []
    for tag in re.findall(r"<rect\b.*?/>", open(path).read(), re.S):
        attrs = dict(re.findall(r'([a-z]+)="([^"]*)"', tag))
        out.append(tuple(attrs.get(k) for k in ("x", "y", "width", "height", "rx")))
    return sorted(out)

a, b = rects(svg), rects(html)
if a != b:
    sys.exit("favicon.svg and scripts/icon.html disagree on the mark geometry:\n"
             f"  favicon.svg: {a}\n  icon.html:   {b}\n"
             "Edit both -- they are duplicated on purpose.")
print("checks passed: favicon.svg well-formed, geometry matches icon.html")
PY

# Both go through scripts/icon.html rather than rasterizing image/favicon.svg
# directly -- headless Chrome on macOS floors the layout viewport at ~485px (see
# the `shot` target's note in the Makefile), which stretches a standalone SVG
# document and clips one magnified corner into the screenshot. A sized div whose
# box matches the requested capture size is immune. Both are rendered at 4x and
# downscaled: the bars carry 2.5px corner radii at 32px, which alias badly
# rendered straight at target size.
#
# favicon.ico is transparent with a mid-grey mark (see icon.html for why that
# tone). --default-background-color takes RGBA hex, so 00000000 is the
# transparent backdrop; without it Chrome paints the page white and the icon
# ships as a white tile.
"$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=4 --window-size=32,32 \
    --default-background-color=00000000 \
    --screenshot="$tmp/mark.png" \
    "file://$root/scripts/icon.html?v=ico" >/dev/null 2>&1
magick "$tmp/mark.png" -define icon:auto-resize=32,16 "$root/favicon.ico"
echo "wrote favicon.ico (32 + 16 px)"

"$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=4 --window-size=180,180 \
    --screenshot="$tmp/touch.png" \
    "file://$root/scripts/icon.html?v=touch" >/dev/null 2>&1
magick "$tmp/touch.png" -resize 180x180 -strip \
    "$root/image/apple-touch-icon.png"
echo "wrote image/apple-touch-icon.png ($(magick "$root/image/apple-touch-icon.png" -format '%wx%h' info:))"
