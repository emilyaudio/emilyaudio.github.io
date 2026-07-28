#!/usr/bin/env bash
# Render the link-preview (Open Graph) cards to image/og-*.png.
#
# Run this by hand after editing scripts/og-card.html, the portrait, or the
# logo -- the site has no build step, so the PNGs are committed artifacts.
# `make og` is the entry point.
#
# The card is authored as HTML so it uses the site's own tokens and font stack,
# then screenshotted at 2x and downscaled -- Chrome's 2x text rasterization
# survives the downsample far better than rendering straight at 1200x630.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
out="$root/image"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ ! -x "$chrome" ]]; then
    echo "Chrome not found at: $chrome" >&2
    echo "Override with: make og CHROME=/path/to/chrome" >&2
    exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick (magick) not found -- brew install imagemagick" >&2
    exit 1
fi

# The card grounds itself on a verbatim copy of index.html's .hero-wave path, so
# the two can drift. Compare them before rendering. Both greps are checked for a
# non-empty result first: a pattern that stopped matching and a genuine
# zero-match are byte-identical, and "" == "" would report the copies as
# agreeing when in fact neither was found.
wave_of() { grep -o 'd="M0 55 [^"]*"' "$1" | head -1; }
hub_wave="$(wave_of "$root/index.html")"
card_wave="$(wave_of "$root/scripts/og-card.html")"
if [[ -z "$hub_wave" || -z "$card_wave" ]]; then
    echo "hero-wave path not found (hub: ${#hub_wave} chars, card: ${#card_wave})" >&2
    echo "Did the .hero-wave markup in index.html change shape?" >&2
    exit 1
fi
if [[ "$hub_wave" != "$card_wave" ]]; then
    echo "hero-wave path differs between index.html and scripts/og-card.html" >&2
    echo "Re-copy it into the card's .band <path>, then rerun." >&2
    exit 1
fi

for v in hub vo audio; do
    # --allow-file-access-from-files is required, not optional: the brand mark
    # is a CSS mask, and Chrome blocks mask images loaded over file:// without
    # it. Its absence fails SILENTLY -- the mark's box keeps its layout space
    # and paints nothing, so the card renders looking merely underdesigned.
    "$chrome" --headless=new --disable-gpu --hide-scrollbars \
        --allow-file-access-from-files --force-device-scale-factor=2 \
        --window-size=1200,630 --screenshot="$tmp/$v.png" \
        "file://$root/scripts/og-card.html?v=$v" >/dev/null 2>&1
    magick "$tmp/$v.png" -resize 1200x630 -strip "$out/og-$v.png"
    echo "wrote image/og-$v.png  ($(magick "$out/og-$v.png" -format '%wx%h' info:))"
done
