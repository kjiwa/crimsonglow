#!/usr/bin/env python3
"""Emits ImageMagick MVG draw commands for the face glyph on the social card.

The glyph is the same head/glasses/eyebrows shapes used by
_includes/avatar.svg and ~kjiwa/assets/favicon.svg, just carried through the
same nested translate/scale transforms those files apply, then placed on the
card canvas. See tools/og-card.sh for why this indirection exists.

Usage: og-card-glyph.py strokes|lenses
"""

import re
import sys

# Path data, unmodified from favicon.svg's <defs>.
HEAD = "M-20,-20 C-60,40 60,40 20,-20"
EYEBROW = "M-5,-2.5 Q0,2.5 5,2.5"
BRIDGE = "M-3.75,0 Q0,-0.625 3.75,0"
LENS_L = (-16.25, -3.75, -3.75, 3.75)  # x1, y1, x2, y2
LENS_R = (3.75, -3.75, 16.25, 3.75)

# favicon.svg's group transform is translate(32,30.5) scale(0.845)
# translate(-35,-25); each <use> adds its own translate before that, and the
# two translates cancel except for the difference between them. Composing
# the two leaves a plain (scale, then translate) per shape:
FAV_SCALE = 0.845
T_HEAD = (32, 30.5)
T_GLASSES = (32, 32.6125)
T_BROW_L = (23.55, 24.1625)
T_BROW_R = (40.45, 24.1625)  # the right eyebrow is also mirrored in x

# Placement on the 1200x630 card.
SCALE = 6.0
ORIGIN = (80, 120)
K = SCALE * FAV_SCALE


def transform(point, base, flip=False):
    x, y = point
    if flip:
        x = -x
    return (K * x + SCALE * base[0] + ORIGIN[0], K * y + SCALE * base[1] + ORIGIN[1])


def transform_path(d, base, flip=False):
    def repl(m):
        nx, ny = transform((float(m.group(1)), float(m.group(2))), base, flip)
        return f"{nx:.2f},{ny:.2f}"

    return re.sub(r"(-?\d+\.?\d*),(-?\d+\.?\d*)", repl, d)


def strokes():
    parts = [
        f"path '{transform_path(HEAD, T_HEAD)}'",
        f"path '{transform_path(BRIDGE, T_GLASSES)}'",
        f"path '{transform_path(EYEBROW, T_BROW_L)}'",
        f"path '{transform_path(EYEBROW, T_BROW_R, flip=True)}'",
    ]
    print(" ".join(parts))


def lenses():
    parts = []
    radius = K * 1  # rx = ry = 1 in the source rects
    for lens in (LENS_L, LENS_R):
        x1, y1 = transform((lens[0], lens[1]), T_GLASSES)
        x2, y2 = transform((lens[2], lens[3]), T_GLASSES)
        parts.append(f"roundrectangle {x1:.2f},{y1:.2f} {x2:.2f},{y2:.2f} {radius:.2f},{radius:.2f}")
    print(" ".join(parts))


if __name__ == "__main__":
    {"strokes": strokes, "lenses": lenses}[sys.argv[1]]()
