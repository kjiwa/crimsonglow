#!/bin/sh
# Regenerates ~kjiwa/assets/og-card.png, the site's social share image.
#
# The face glyph reuses the exact path/rect definitions from
# _includes/avatar.svg (the full header logo, including eyes/mouth/teeth —
# ~kjiwa/assets/favicon.svg's reduced subset is for icon sizes, not this),
# transformed by hand (translate + uniform scale, matching avatar.svg's
# nested SVG transforms) into absolute ImageMagick "-draw" coordinates. This
# is necessary because the installed ImageMagick only has the MSVG renderer,
# which silently drops <defs>/<use> — rendering avatar.svg directly produces
# a blank glyph.
#
# Requires: ImageMagick (`magick`), and Arial / Arial Bold from
# /System/Library/Fonts/Supplemental (macOS). Edit ARIAL/ARIAL_BOLD below to
# point at equivalent fonts on other platforms.

set -eu

cd "$(dirname "$0")/.."
out="~kjiwa/assets/og-card.png"

ARIAL_BOLD="/System/Library/Fonts/Supplemental/Arial Bold.ttf"
ARIAL="/System/Library/Fonts/Supplemental/Arial.ttf"

# 2.0 SVG units (matching _sass/avatar.scss's 2px stroke in the 70-unit
# header viewBox), scaled by the same SCALE * FAV_SCALE factor the glyph
# coordinates use.
STROKE=10.14

# Absolute coordinates for the face glyph, computed by tools/og-card-glyph.py
# from the shapes in avatar.svg.
STROKES=$(python3 tools/og-card-glyph.py strokes)
LENSES=$(python3 tools/og-card-glyph.py lenses)
EYES=$(python3 tools/og-card-glyph.py eyes)

magick -size 1200x630 xc:"#000077" \
  -fill none -stroke white -strokewidth "$STROKE" \
  -draw "stroke-linecap round stroke-linejoin round $STROKES" \
  -fill "#000077" -stroke white -strokewidth "$STROKE" \
  -draw "$LENSES" \
  -fill none -stroke white -strokewidth "$STROKE" \
  -draw "$EYES" \
  -stroke none \
  -fill white -font "$ARIAL_BOLD" -pointsize 84 \
  -gravity NorthWest -annotate +520+230 "Kamil Jiwa" \
  -fill "#ccccee" -font "$ARIAL" -pointsize 34 \
  -gravity NorthWest -annotate +523+345 "crimsonglow.ca/~kjiwa" \
  -depth 8 -define png:color-type=2 \
  "$out"

magick identify "$out"
