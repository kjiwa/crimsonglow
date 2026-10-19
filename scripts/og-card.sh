#!/bin/sh
# Regenerates site/~kjiwa/assets/og-card.png, the site's social share image.
#
# The face glyph can't be rendered from site/_includes/avatar.svg directly: the
# installed ImageMagick only has the MSVG renderer, which silently drops
# <defs>/<use> and produces a blank glyph. Instead scripts/og-card-glyph.py
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

# 2.0 SVG units (matching site/_sass/avatar.scss's 2px stroke in the 70-unit
# header viewBox), scaled by the same SCALE * FAV_SCALE factor the glyph
# coordinates use.
STROKE=10.14
readonly STROKE

OUT_FILE="site/~kjiwa/assets/og-card.png"
readonly OUT_FILE

# Tries each candidate in order, printing the first that resolves. "fc:"
# entries are fontconfig patterns; plain entries are literal paths. fc-list is
# used rather than fc-match because fc-match always falls back to *some* font,
# which would silently substitute a non-metric-compatible face.
resolve_font() {
  for _resolve_font_candidate in "$@"; do
    case "$_resolve_font_candidate" in
      fc:*)
        command -v fc-list >/dev/null 2>&1 || continue
        _resolve_font_match=$(fc-list -f '%{file}\n' "${_resolve_font_candidate#fc:}" file 2>/dev/null | head -n 1)
        [ -n "$_resolve_font_match" ] && { printf '%s\n' "$_resolve_font_match"; return 0; }
        ;;
      *)
        [ -f "$_resolve_font_candidate" ] && { printf '%s\n' "$_resolve_font_candidate"; return 0; }
        ;;
    esac
  done
  return 1
}

# $1 = weight label for the message, $2 = override variable to suggest.
font_error() {
  _font_error_weight="$1"
  _font_error_override="$2"

  echo "og-card: no Arial-metric $_font_error_weight font found. Install Liberation Sans" >&2
  echo "  (apt install fonts-liberation / dnf install liberation-sans-fonts /" >&2
  echo "   pacman -S ttf-liberation) or set $_font_error_override to a font file." >&2
  exit 1
}

main() {
  _main_dir="$(dirname "$0")/.."
  cd "$_main_dir"

  # ImageMagick 7 ships `magick`; ImageMagick 6 -- still the default on Debian 12
  # and Ubuntu 22.04/24.04 -- ships only `convert`/`identify`. The MVG `-draw`
  # syntax and `png:` define used below are identical across both.
  if command -v magick >/dev/null 2>&1; then
    _main_im_convert="magick"
    _main_im_identify="magick identify"
  elif command -v convert >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
    _main_im_convert="convert"
    _main_im_identify="identify"
  else
    echo "og-card: ImageMagick not found. Install it (apt install imagemagick /" >&2
    echo "  dnf install ImageMagick / pacman -S imagemagick / brew install imagemagick)." >&2
    return 1
  fi

  _main_font_bold="${OG_FONT_BOLD:-}"
  if [ -z "$_main_font_bold" ] && ! _main_font_bold=$(resolve_font \
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf" \
    "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf" \
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" \
    "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf" \
    "/usr/share/fonts/TTF/LiberationSans-Bold.ttf" \
    "fc:Arial:style=Bold" \
    "fc:Liberation Sans:style=Bold" \
    "fc:Arimo:style=Bold"); then
    font_error bold OG_FONT_BOLD
  fi

  _main_font_regular="${OG_FONT_REGULAR:-}"
  if [ -z "$_main_font_regular" ] && ! _main_font_regular=$(resolve_font \
    "/System/Library/Fonts/Supplemental/Arial.ttf" \
    "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf" \
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf" \
    "/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf" \
    "/usr/share/fonts/TTF/LiberationSans-Regular.ttf" \
    "fc:Arial:style=Regular" \
    "fc:Liberation Sans:style=Regular" \
    "fc:Arimo:style=Regular"); then
    font_error regular OG_FONT_REGULAR
  fi

  echo "og-card: bold font:    $_main_font_bold" >&2
  echo "og-card: regular font: $_main_font_regular" >&2

  # Absolute coordinates for the face glyph, computed by scripts/og-card-glyph.py
  # from the shapes in avatar.svg.
  _main_strokes=$(python3 scripts/og-card-glyph.py strokes)
  _main_lenses=$(python3 scripts/og-card-glyph.py lenses)
  _main_eyes=$(python3 scripts/og-card-glyph.py eyes)

  $_main_im_convert -size 1200x630 xc:"#000077" \
    -fill none -stroke white -strokewidth "$STROKE" \
    -draw "stroke-linecap round stroke-linejoin round $_main_strokes" \
    -fill "#000077" -stroke white -strokewidth "$STROKE" \
    -draw "$_main_lenses" \
    -fill none -stroke white -strokewidth "$STROKE" \
    -draw "$_main_eyes" \
    -stroke none \
    -fill white -font "$_main_font_bold" -pointsize 84 \
    -gravity NorthWest -annotate +520+230 "Kamil Jiwa" \
    -fill "#ccccee" -font "$_main_font_regular" -pointsize 34 \
    -gravity NorthWest -annotate +523+345 "crimsonglow.ca/~kjiwa" \
    -colors 128 -define png:color-type=3 \
    "$OUT_FILE"

  # Deliberately unquoted: on ImageMagick 7, _main_im_identify is "magick identify"
  # and must word-split into two arguments.
  $_main_im_identify "$OUT_FILE"
}

main "$@"

