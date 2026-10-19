#!/usr/bin/env python3
"""Emits ImageMagick MVG draw commands for the face glyph on the social card.

The glyph is the same head/glasses/eyebrows/eyes/mouth/teeth shapes used by
site/_includes/avatar.svg, carried through the same nested translate/scale
transforms that file applies, then placed on the card canvas. See
scripts/og-card.sh for why this indirection exists.

site/_includes/avatar.svg wraps its shapes in <g transform="translate(5 5)">, so
each shape's absolute anchor is its <use> translate plus (5, 5). The anchors
below are those absolute positions; site/~kjiwa/assets/favicon.svg's own <use>
translates match this same frame for the shapes it keeps (head, glasses,
eyebrows) but drops eyes/mouth/teeth for legibility at icon sizes. The card
has room for the full set, so it draws from avatar.svg's frame directly.

Usage: og-card-glyph.py strokes|lenses|eyes
"""

import re
import sys

# Path/shape data, unmodified from avatar.svg's <defs>.
HEAD = "M-20,-20 C-60,40 60,40 20,-20"
MOUTH = "M-30,-2.5 L-25,0 L25,0 L30,-2.5"
TOOTH = "M-5,0 L5,0 L0,5 Z"
EYEBROW = "M-5,-2.5 Q0,2.5 5,2.5"
BRIDGE = "M-3.75,0 Q0,-0.625 3.75,0"
LENS_L = (-16.25, -3.75, -3.75, 3.75)  # x1, y1, x2, y2
LENS_R = (3.75, -3.75, 16.25, 3.75)
EYE_DX = 8.75  # circles at (+-8.75, 0), r = 1
EYE_R = 1.0

# Absolute anchors in avatar.svg's frame (each <use> translate + (5, 5)).
A_HEAD = (35, 25)
A_GLASSES = (35, 27.5)
A_BROW_L = (25, 17.5)
A_BROW_R = (45, 17.5)  # also mirrored in x
A_EYES = (35, 27.8125)
A_MOUTH = (35, 35)  # local x additionally scaled by 0.75
A_TOOTH_L = (25, 35)
A_TOOTH_R = (45, 35)

# favicon.svg's group transform is translate(32,30.5) scale(0.845)
# translate(-35,-25) applied on top of avatar.svg's frame; composing the two
# leaves a plain (scale, then translate) per shape, anchored at (35, 25):
FAV_SCALE = 0.845
FAV_ORIGIN = (32, 30.5)
FAV_ANCHOR = (35, 25)

# Placement on the 1200x630 card.
SCALE = 6.0
ORIGIN = (80, 120)
K = SCALE * FAV_SCALE


def transform(point, anchor, flip=False, xscale=1.0):
    x, y = point
    x *= xscale
    if flip:
        x = -x
    ax, ay = anchor
    fx = FAV_SCALE * (x + ax - FAV_ANCHOR[0]) + FAV_ORIGIN[0]
    fy = FAV_SCALE * (y + ay - FAV_ANCHOR[1]) + FAV_ORIGIN[1]
    return (SCALE * fx + ORIGIN[0], SCALE * fy + ORIGIN[1])


def transform_path(d, anchor, flip=False, xscale=1.0):
    def repl(m):
        nx, ny = transform((float(m.group(1)), float(m.group(2))), anchor, flip, xscale)
        return f"{nx:.2f},{ny:.2f}"

    return re.sub(r"(-?\d+\.?\d*),(-?\d+\.?\d*)", repl, d)


def strokes():
    parts = [
        f"path '{transform_path(HEAD, A_HEAD)}'",
        f"path '{transform_path(MOUTH, A_MOUTH, xscale=0.75)}'",
        f"path '{transform_path(TOOTH, A_TOOTH_L)}'",
        f"path '{transform_path(TOOTH, A_TOOTH_R)}'",
        f"path '{transform_path(BRIDGE, A_GLASSES)}'",
        f"path '{transform_path(EYEBROW, A_BROW_L)}'",
        f"path '{transform_path(EYEBROW, A_BROW_R, flip=True)}'",
    ]
    print(" ".join(parts))


def lenses():
    parts = []
    radius = K * 1  # rx = ry = 1 in the source rects
    for lens in (LENS_L, LENS_R):
        x1, y1 = transform((lens[0], lens[1]), A_GLASSES)
        x2, y2 = transform((lens[2], lens[3]), A_GLASSES)
        parts.append(f"roundrectangle {x1:.2f},{y1:.2f} {x2:.2f},{y2:.2f} {radius:.2f},{radius:.2f}")
    print(" ".join(parts))


def eyes():
    radius = K * EYE_R
    parts = []
    for dx in (-EYE_DX, EYE_DX):
        cx, cy = transform((dx, 0), A_EYES)
        parts.append(f"circle {cx:.2f},{cy:.2f} {cx:.2f},{cy - radius:.2f}")
    print(" ".join(parts))


if __name__ == "__main__":
    {"strokes": strokes, "lenses": lenses, "eyes": eyes}[sys.argv[1]]()
