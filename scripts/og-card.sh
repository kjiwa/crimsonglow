#!/bin/sh
# Regenerates site/~kjiwa/assets/og-card.png, the site's social share image.
# Needs ImageMagick 6 or 7, python3, and bold and regular Arial-metric fonts
# (Arial, Liberation Sans or Arimo; DejaVu Sans and Helvetica shift the text).
# OG_FONT_BOLD / OG_FONT_REGULAR override the font search.

set -eu

# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

# 2.0 SVG units (site/_sass/avatar.scss's 2px stroke in the 70-unit viewBox),
# scaled by the glyph coordinates' SCALE * FAV_SCALE.
STROKE=10.14
readonly STROKE

OUT_FILE="site/~kjiwa/assets/og-card.png"
readonly OUT_FILE

# "fc:" candidates are fontconfig patterns, the rest literal paths. fc-list, not
# fc-match, because fc-match falls back to a non-metric-compatible font.
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

font_error() {
  die "no Arial-metric $1 font found. Install Liberation Sans or set $2 to a font file."
}

main() {
  _main_dir="$(dirname "$0")/.."
  cd "$_main_dir"

  if command -v magick >/dev/null 2>&1; then
    _main_im_convert="magick"
    _main_im_identify="magick identify"
  elif command -v convert >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
    _main_im_convert="convert"
    _main_im_identify="identify"
  else
    die "ImageMagick not found"
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

  # ImageMagick's MSVG renderer drops <defs>/<use>, so avatar.svg cannot be
  # rendered directly; the glyph script emits its shapes as -draw coordinates.
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

  # Unquoted: "magick identify" must word-split.
  $_main_im_identify "$OUT_FILE"
}

main "$@"

