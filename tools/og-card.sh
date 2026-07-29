#!/bin/sh
# Regenerates ~kjiwa/assets/og-card.png, the site's social share image.
#
# The face glyph reuses the exact path/rect definitions from
# _includes/avatar.svg and ~kjiwa/assets/favicon.svg, transformed by hand
# (translate + uniform scale, matching those files' nested SVG transforms)
# into absolute ImageMagick "-draw" coordinates. This is necessary because
# the installed ImageMagick only has the MSVG renderer, which silently drops
# <defs>/<use> — rendering favicon.svg directly produces a blank icon.
#
# Requires: ImageMagick (`magick`), and Arial / Arial Bold from
# /System/Library/Fonts/Supplemental (macOS). Edit ARIAL/ARIAL_BOLD below to
# point at equivalent fonts on other platforms.

set -eu

cd "$(dirname "$0")/.."
out="~kjiwa/assets/og-card.png"

ARIAL_BOLD="/System/Library/Fonts/Supplemental/Arial Bold.ttf"
ARIAL="/System/Library/Fonts/Supplemental/Arial.ttf"

# Absolute coordinates for the face glyph, computed by tools/og-card-glyph.py
# from the shapes in avatar.svg/favicon.svg.
STROKES=$(python3 tools/og-card-glyph.py strokes)
LENSES=$(python3 tools/og-card-glyph.py lenses)

magick -size 1200x630 xc:"#000077" \
  -fill none -stroke white -strokewidth 12 \
  -draw "stroke-linecap round stroke-linejoin round $STROKES" \
  -fill "#000077" -stroke white -strokewidth 12 \
  -draw "$LENSES" \
  -stroke none \
  -fill white -font "$ARIAL_BOLD" -pointsize 84 \
  -gravity NorthWest -annotate +520+230 "Kamil Jiwa" \
  -fill "#ccccee" -font "$ARIAL" -pointsize 34 \
  -gravity NorthWest -annotate +523+345 "crimsonglow.ca/~kjiwa" \
  "$out"

magick identify "$out"
