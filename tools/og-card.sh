#!/bin/sh
# Regenerates ~kjiwa/assets/og-card.png, the site's social share image.
#
# The face glyph can't be rendered from _includes/avatar.svg directly: the
# installed ImageMagick only has the MSVG renderer, which silently drops
# <defs>/<use> and produces a blank glyph. Instead tools/og-card-glyph.py
# transforms avatar.svg's shapes by hand into the absolute "-draw" coordinates
# used below (see that file for the coordinate math).
#
# Requires: ImageMagick 6 or 7 (`convert`/`identify`, or `magick`), python3,
# and a bold + regular Arial-metric-compatible font (Arial itself, or
# Liberation Sans / Arimo, which share Arial's advance widths -- DejaVu Sans
# and Helvetica do not, and will shift the text). resolve_font() below
# searches common install locations and finally fontconfig; set OG_FONT_BOLD
# / OG_FONT_REGULAR to override.

set -eu

cd "$(dirname "$0")/.."
out="~kjiwa/assets/og-card.png"

# ImageMagick 7 ships `magick`; ImageMagick 6 -- still the default on Debian 12
# and Ubuntu 22.04/24.04 -- ships only `convert`/`identify`. The MVG `-draw`
# syntax and `png:` define used below are identical across both.
if command -v magick >/dev/null 2>&1; then
  IM_CONVERT=magick
  IM_IDENTIFY="magick identify"
elif command -v convert >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
  IM_CONVERT=convert
  IM_IDENTIFY=identify
else
  echo "og-card: ImageMagick not found. Install it (apt install imagemagick /" >&2
  echo "  dnf install ImageMagick / pacman -S imagemagick / brew install imagemagick)." >&2
  exit 1
fi

# Tries each candidate in order, printing the first that resolves. "fc:"
# entries are fontconfig patterns; plain entries are literal paths. fc-list is
# used rather than fc-match because fc-match always falls back to *some* font,
# which would silently substitute a non-metric-compatible face.
resolve_font() {
  for c in "$@"; do
    case $c in
      fc:*)
        command -v fc-list >/dev/null 2>&1 || continue
        m=$(fc-list -f '%{file}\n' "${c#fc:}" file 2>/dev/null | head -n 1)
        [ -n "$m" ] && { printf '%s\n' "$m"; return 0; }
        ;;
      *)
        [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }
        ;;
    esac
  done
  return 1
}

FONT_BOLD=${OG_FONT_BOLD:-}
if [ -z "$FONT_BOLD" ] && ! FONT_BOLD=$(resolve_font \
  "/System/Library/Fonts/Supplemental/Arial Bold.ttf" \
  "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf" \
  "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" \
  "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf" \
  "/usr/share/fonts/TTF/LiberationSans-Bold.ttf" \
  "fc:Arial:style=Bold" \
  "fc:Liberation Sans:style=Bold" \
  "fc:Arimo:style=Bold"); then
  echo "og-card: no Arial-metric bold font found. Install Liberation Sans" >&2
  echo "  (apt install fonts-liberation / dnf install liberation-sans-fonts /" >&2
  echo "   pacman -S ttf-liberation) or set OG_FONT_BOLD to a font file." >&2
  exit 1
fi

FONT_REGULAR=${OG_FONT_REGULAR:-}
if [ -z "$FONT_REGULAR" ] && ! FONT_REGULAR=$(resolve_font \
  "/System/Library/Fonts/Supplemental/Arial.ttf" \
  "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf" \
  "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf" \
  "/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf" \
  "/usr/share/fonts/TTF/LiberationSans-Regular.ttf" \
  "fc:Arial:style=Regular" \
  "fc:Liberation Sans:style=Regular" \
  "fc:Arimo:style=Regular"); then
  echo "og-card: no Arial-metric regular font found. Install Liberation Sans" >&2
  echo "  (apt install fonts-liberation / dnf install liberation-sans-fonts /" >&2
  echo "   pacman -S ttf-liberation) or set OG_FONT_REGULAR to a font file." >&2
  exit 1
fi

echo "og-card: bold font:    $FONT_BOLD" >&2
echo "og-card: regular font: $FONT_REGULAR" >&2

# 2.0 SVG units (matching _sass/avatar.scss's 2px stroke in the 70-unit
# header viewBox), scaled by the same SCALE * FAV_SCALE factor the glyph
# coordinates use.
STROKE=10.14

# Absolute coordinates for the face glyph, computed by tools/og-card-glyph.py
# from the shapes in avatar.svg.
STROKES=$(python3 tools/og-card-glyph.py strokes)
LENSES=$(python3 tools/og-card-glyph.py lenses)
EYES=$(python3 tools/og-card-glyph.py eyes)

$IM_CONVERT -size 1200x630 xc:"#000077" \
  -fill none -stroke white -strokewidth "$STROKE" \
  -draw "stroke-linecap round stroke-linejoin round $STROKES" \
  -fill "#000077" -stroke white -strokewidth "$STROKE" \
  -draw "$LENSES" \
  -fill none -stroke white -strokewidth "$STROKE" \
  -draw "$EYES" \
  -stroke none \
  -fill white -font "$FONT_BOLD" -pointsize 84 \
  -gravity NorthWest -annotate +520+230 "Kamil Jiwa" \
  -fill "#ccccee" -font "$FONT_REGULAR" -pointsize 34 \
  -gravity NorthWest -annotate +523+345 "crimsonglow.ca/~kjiwa" \
  -depth 8 -define png:color-type=2 \
  "$out"

# Deliberately unquoted: on ImageMagick 7, IM_IDENTIFY is "magick identify"
# and must word-split into two arguments.
$IM_IDENTIFY "$out"
