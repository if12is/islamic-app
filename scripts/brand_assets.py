#!/usr/bin/env python3
"""Render the Al-Fajr symbol to every raster the app needs.

The mark is a circle and a six-point polygon on a 120-unit square, so it is
drawn here from those numbers rather than shipped as opaque PNGs nobody can
regenerate. Change a coordinate below, run this, and every icon in the project
follows — which is the whole point of keeping the geometry in code.

The geometry is taken verbatim from the approved design (construction "1A —
the valley"):

    sun   circle  cx 60  cy 58  r 26
    book  polygon 12,60 → 60,74 → 108,60 → 108,78 → 60,92 → 12,78

The book is drawn over the sun, so the disc is cut by the book's dipped top
edge: the book is the horizon and the sun is clearing it. Lifting the disc
free of the band destroys the idea, which is why the design sheet lists it as
a wrong use.

In one flat colour the two shapes would merge into an unreadable blob, so the
monochrome variants subtract an 8-unit kerf along the book's top edge. That
kerf is what makes the 24 px status-bar icon still read as two shapes.

Usage:  python3 scripts/brand_assets.py
Needs:  Pillow
"""

from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------- geometry

UNITS = 120.0

SUN_CENTRE = (60.0, 58.0)
SUN_RADIUS = 26.0

BOOK = [
    (12.0, 60.0),
    (60.0, 74.0),
    (108.0, 60.0),
    (108.0, 78.0),
    (60.0, 92.0),
    (12.0, 78.0),
]

# The polyline the kerf follows: the book's top edge.
BOOK_TOP = [(12.0, 60.0), (60.0, 74.0), (108.0, 60.0)]
KERF_WIDTH = 8.0

# ------------------------------------------------------------------ colour

CREAM = "#F6F0E4"
NIGHT = "#0B1411"
GREEN = "#0F6B4F"
GREEN_BRIGHT = "#10B981"
GOLD = "#B07C21"
GOLD_BRIGHT = "#E0AE4A"
INK = "#12261F"

TRANSPARENT = (0, 0, 0, 0)

# Everything is drawn at eight times the target and resampled down. Pillow's
# polygon and ellipse fills have hard edges, and a mark that is nothing but a
# circle and four straight lines shows every jagged step at icon sizes.
SUPERSAMPLE = 8


def _scaled(points, size: float):
    factor = size / UNITS
    return [(x * factor, y * factor) for x, y in points]


def _draw_mark(size: int, book: str, sun: str, kerf: bool) -> Image.Image:
    """The symbol alone, on transparency, filling a `size` square."""
    big = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (big, big), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)

    factor = big / UNITS
    cx, cy = SUN_CENTRE
    r = SUN_RADIUS

    draw.ellipse(
        [
            (cx - r) * factor,
            (cy - r) * factor,
            (cx + r) * factor,
            (cy + r) * factor,
        ],
        fill=sun,
    )

    if kerf:
        # Cut the gap before the band goes down, so the disc keeps its own
        # edge rather than the band eating into it.
        draw.line(
            _scaled(BOOK_TOP, big),
            fill=TRANSPARENT,
            width=int(round(KERF_WIDTH * factor)),
            joint="curve",
        )
        # `joint="curve"` rounds the elbow; the design specifies a miter, and
        # at the gutter the two segments meet shallowly enough that the
        # difference is invisible — but the elbow must be filled or the kerf
        # shows a notch there.
        elbow = _scaled([BOOK_TOP[1]], big)[0]
        half = KERF_WIDTH * factor / 2
        draw.ellipse(
            [elbow[0] - half, elbow[1] - half, elbow[0] + half, elbow[1] + half],
            fill=TRANSPARENT,
        )

    draw.polygon(_scaled(BOOK, big), fill=book)

    return canvas.resize((size, size), Image.LANCZOS)


def _on_ground(size: int, ground: str, mark: Image.Image, scale: float) -> Image.Image:
    """Centre the mark on a filled square at `scale` of its width.

    Centred on the ink, not on the 120-unit box. The drawing occupies y 32–92
    of that box, so its middle sits at 62 while the box's sits at 60 — centre
    the box and the mark hangs two units low, which is small on a page and
    obvious in a launcher grid.
    """
    canvas = Image.new("RGBA", (size, size), ground)
    inner = max(1, int(round(size * scale)))
    resized = mark.resize((inner, inner), Image.LANCZOS)

    bbox = resized.getchannel("A").getbbox()
    if bbox is None:
        return canvas
    ink_centre_x = (bbox[0] + bbox[2]) / 2
    ink_centre_y = (bbox[1] + bbox[3]) / 2

    canvas.alpha_composite(
        resized,
        (
            int(round(size / 2 - ink_centre_x)),
            int(round(size / 2 - ink_centre_y)),
        ),
    )
    return canvas


# ------------------------------------------------- the notification icon

# Android strips every colour from a status-bar icon and redraws it as a flat
# white stencil, so it is emitted as a vector rather than a PNG: crisp at any
# density, and the kerf holds at 24 dp where a downscaled bitmap would smear
# the sun into the book.
#
# The kerf's upper boundary is the book's top edge offset perpendicularly by
# half the kerf width. The edge runs (12,60) → (60,74), so its slope is
# 14/48 and a perpendicular offset of 4 units is a vertical one of
# 4 x sqrt(1 + (14/48)^2) = 4.1667. That line, extended to both margins and
# scaled to a 24-unit viewport, is the clip below which the sun is not drawn.

NOTIFICATION_VECTOR = """<?xml version="1.0" encoding="utf-8"?>
<!--
  Generated by scripts/brand_assets.py — edit the geometry there, not here.

  The Al-Fajr mark as a status-bar stencil. Android throws away the colours
  and fills the whole thing white, so the sun and the book are held apart by
  an 8-unit kerf (1.6 at this scale) cut along the book's top edge. Without
  it the two shapes merge and the icon reads as one lump at 24 dp.
-->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <group>
        <clip-path android:pathData="M0,0 L24,0 L24,{clip_edge:.3f} L12,{clip_mid:.3f} L0,{clip_edge:.3f} Z" />
        <path
            android:fillColor="#FFFFFFFF"
            android:pathData="M{sun_cx:.2f},{sun_top:.2f} A{sun_r:.2f},{sun_r:.2f} 0 1,1 {sun_cx_eps:.2f},{sun_top:.2f} Z" />
    </group>
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M{bx0:.2f},{by0:.2f} L{bx1:.2f},{by1:.2f} L{bx2:.2f},{by2:.2f} L{bx3:.2f},{by3:.2f} L{bx4:.2f},{by4:.2f} L{bx5:.2f},{by5:.2f} Z" />
</vector>
"""


def _notification_vector() -> str:
    scale = 24.0 / UNITS

    # The book's top edge, and the line the kerf cuts along.
    (x0, y0), (x1, y1), _ = BOOK_TOP
    slope = (y1 - y0) / (x1 - x0)
    lift = (KERF_WIDTH / 2) * math.sqrt(1 + slope * slope)

    def edge_at(x: float) -> float:
        return (y0 + slope * (x - x0) - lift) * scale

    book = [(x * scale, y * scale) for x, y in BOOK]

    return NOTIFICATION_VECTOR.format(
        clip_edge=edge_at(0.0),
        clip_mid=edge_at(UNITS / 2),
        sun_cx=SUN_CENTRE[0] * scale,
        # An arc cannot start and end on the same point, so the circle is drawn
        # as one sweep between two points a hair apart.
        sun_cx_eps=SUN_CENTRE[0] * scale + 0.01,
        sun_top=(SUN_CENTRE[1] - SUN_RADIUS) * scale,
        sun_r=SUN_RADIUS * scale,
        bx0=book[0][0], by0=book[0][1],
        bx1=book[1][0], by1=book[1][1],
        bx2=book[2][0], by2=book[2][1],
        bx3=book[3][0], by3=book[3][1],
        bx4=book[4][0], by4=book[4][1],
        bx5=book[5][0], by5=book[5][1],
    )


def _write(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG")
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}×{image.size[1]}")


# ------------------------------------------------------------------ outputs

# flutter_launcher_icons reads these three and fans them out to every density,
# to iOS, and to web — so this script writes the sources, not the fan-out.
SOURCES = ROOT / "assets" / "brand"

# The launcher icon's artwork sits at 68% of the tile, matching the design
# sheet.
LAUNCHER_SCALE = 0.68

# The adaptive foreground has to account for three separate shrinkings, and
# getting it wrong by ignoring any one of them leaves a mark swimming in an
# empty circle. In order:
#
#   1. flutter_launcher_icons wraps the drawable in `<inset android:inset=
#      "16%">`, so the artwork occupies 68% of the 108dp canvas. Fighting that
#      by hand-editing the generated XML only means the next person to run the
#      tool loses the fix, so it is compensated for here instead.
#   2. The mark's own ink is 80% of its square wide and 50% tall — the book
#      spans x 12–108 and the drawing spans y 32–92 of the 120-unit box.
#   3. Launchers mask the 108dp canvas down to about 72dp of visible area.
#
# Target: ink 48dp wide on the 108dp canvas, which is 67% of the visible 72dp
# — the same proportion the design sheet gives the legacy icon.
#
#   scale = 0.44 target / (0.68 inset x 0.80 ink) = 0.81
ADAPTIVE_SCALE = 0.81


def main() -> None:
    print("Al-Fajr brand assets")

    mark_light = _draw_mark(1024, book=GREEN, sun=GOLD, kerf=False)
    mark_night = _draw_mark(1024, book=GREEN_BRIGHT, sun=GOLD_BRIGHT, kerf=False)
    mark_ink = _draw_mark(1024, book=INK, sun=INK, kerf=True)
    mark_white = _draw_mark(1024, book="#FFFFFF", sun="#FFFFFF", kerf=True)

    # The symbol on transparency, for anything that places it itself.
    _write(mark_light, SOURCES / "mark-light.png")
    _write(mark_night, SOURCES / "mark-night.png")
    _write(mark_ink, SOURCES / "mark-ink.png")
    _write(mark_white, SOURCES / "mark-white.png")

    # The launcher icon: the mark on cream, which is the app's own ground.
    _write(
        _on_ground(1024, CREAM, mark_light, LAUNCHER_SCALE),
        ROOT / "icon.png",
    )
    _write(
        _on_ground(1024, NIGHT, mark_night, LAUNCHER_SCALE),
        SOURCES / "icon-night.png",
    )

    # Adaptive foreground: transparent, artwork well inside the safe circle.
    _write(
        _on_ground(1024, TRANSPARENT, mark_light, ADAPTIVE_SCALE),
        SOURCES / "icon-foreground.png",
    )

    # Android 13 themed icons take a single-colour silhouette and recolour it
    # to the user's wallpaper palette, so this one must carry the kerf.
    _write(
        _on_ground(1024, TRANSPARENT, mark_ink, ADAPTIVE_SCALE),
        SOURCES / "icon-monochrome.png",
    )

    notification = (
        ROOT
        / "android"
        / "app"
        / "src"
        / "main"
        / "res"
        / "drawable"
        / "ic_stat_fajr.xml"
    )
    notification.parent.mkdir(parents=True, exist_ok=True)
    notification.write_text(_notification_vector(), encoding="utf-8")
    print(f"  {notification.relative_to(ROOT)}  vector")

    print("\nNow run:  dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
