#!/usr/bin/env python3
"""Draws the textures for the plaza's fountain and cherry trees.

Each one is white on a transparent background, so Roblox can tint it with a Color, and is
saved as an SVG and rendered to a PNG with headless Chrome, like the store icons. Run it
again after changing a drawing:

    python3 art/plaza/build_textures.py

The PNGs are uploaded to Roblox and their asset ids go at the top of the builders in tools/.
"""

import pathlib
import random
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def svg(width, height, body, defs=""):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}"><defs>{defs}</defs>{body}</svg>'
    )


def water_streak():
    """Streaks of falling water for Beams. A Beam lays its texture's width along its
    length, so the streaks run left to right and wrap around, and they fade out toward
    the top and bottom edges so neighbouring Beams blend into one sheet."""
    width, height = 256, 128
    rng = random.Random(7)
    lines = []
    for _ in range(70):
        y = rng.uniform(6, height - 6)
        # Fainter near the edges of the sheet.
        edge = 1 - abs(y - height / 2) / (height / 2)
        opacity = rng.uniform(0.25, 0.9) * (0.35 + 0.65 * edge)
        stroke = rng.uniform(1.5, 4.5)
        x = rng.uniform(0, width)
        length = rng.uniform(40, 200)
        # Draw it twice, one tile apart, so a streak that runs off the right edge comes
        # back on the left.
        for shift in (0, -width):
            lines.append(
                f'<line x1="{x + shift:.1f}" y1="{y:.1f}" x2="{x + length + shift:.1f}" y2="{y:.1f}" '
                f'stroke="#FFFFFF" stroke-width="{stroke:.1f}" stroke-linecap="round" '
                f'opacity="{opacity:.2f}"/>'
            )
    defs = (
        '<linearGradient id="body" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/>'
        '<stop offset="0.3" stop-color="#FFFFFF" stop-opacity="0.35"/>'
        '<stop offset="0.7" stop-color="#FFFFFF" stop-opacity="0.35"/>'
        '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>'
        "</linearGradient>"
    )
    body = f'<rect width="{width}" height="{height}" fill="url(#body)"/>' + "".join(lines)
    return width, height, svg(width, height, body, defs)


def ripple():
    """A soft ring, for ripples spreading over the water."""
    size = 256
    defs = (
        '<radialGradient id="ring" cx="0.5" cy="0.5" r="0.5">'
        '<stop offset="0.62" stop-color="#FFFFFF" stop-opacity="0"/>'
        '<stop offset="0.8" stop-color="#FFFFFF" stop-opacity="1"/>'
        '<stop offset="0.86" stop-color="#FFFFFF" stop-opacity="0.85"/>'
        '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>'
        "</radialGradient>"
    )
    body = f'<circle cx="{size / 2}" cy="{size / 2}" r="{size / 2}" fill="url(#ring)"/>'
    return size, size, svg(size, size, body, defs)


def shimmer():
    """Bright wavy lines like sunlight on a pool, tiling in both directions. Noise that
    stitches at the edges is turned into thin bright bands where it crosses the middle."""
    size = 512
    bands = " ".join(["0"] * 9 + ["0.95"] + ["0"] * 9)
    defs = (
        '<filter id="caustic" x="0" y="0" width="512" height="512" filterUnits="userSpaceOnUse">'
        '<feTurbulence type="fractalNoise" baseFrequency="0.0078125" numOctaves="3" seed="4" '
        'stitchTiles="stitch" result="noise"/>'
        '<feColorMatrix in="noise" type="matrix" '
        'values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  1 0 0 0 0" result="white"/>'
        f'<feComponentTransfer in="white"><feFuncA type="table" tableValues="{bands}"/></feComponentTransfer>'
        '<feGaussianBlur stdDeviation="0.8"/>'
        "</filter>"
    )
    body = f'<rect width="{size}" height="{size}" fill="#FFFFFF" filter="url(#caustic)"/>'
    return size, size, svg(size, size, body, defs)


def petal():
    """One cherry blossom petal, with the notch at its tip."""
    size = 128
    defs = (
        '<radialGradient id="petal" cx="0.5" cy="0.85" r="0.8">'
        '<stop offset="0" stop-color="#E8E8E8"/>'
        '<stop offset="0.5" stop-color="#FFFFFF"/>'
        "</radialGradient>"
    )
    # From the stem at the bottom, out to two lobes either side of the notch at the top.
    path = (
        "M64 120 C42 102 32 68 37 40 C40 22 53 16 59 30 L64 40 L69 30 "
        "C75 16 88 22 91 40 C96 68 86 102 64 120 Z"
    )
    body = f'<path d="{path}" fill="url(#petal)"/>'
    return size, size, svg(size, size, body, defs)


def droplet():
    """A round drop of water with a bright centre, for splashes and jets."""
    size = 64
    defs = (
        '<radialGradient id="drop" cx="0.5" cy="0.5" r="0.5">'
        '<stop offset="0" stop-color="#FFFFFF" stop-opacity="1"/>'
        '<stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0.85"/>'
        '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>'
        "</radialGradient>"
    )
    body = f'<circle cx="{size / 2}" cy="{size / 2}" r="{size / 2}" fill="url(#drop)"/>'
    return size, size, svg(size, size, body, defs)


TEXTURES = [
    ("WaterStreak", water_streak),
    ("Ripple", ripple),
    ("Shimmer", shimmer),
    ("Petal", petal),
    ("Droplet", droplet),
]


def main():
    for name, draw in TEXTURES:
        width, height, text = draw()
        drawing = HERE / f"{name}.svg"
        png = HERE / f"{name}.png"
        drawing.write_text(text)
        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                f"--window-size={width},{height}",
                f"--screenshot={png}",
                drawing.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
        print(png.name)


if __name__ == "__main__":
    main()
