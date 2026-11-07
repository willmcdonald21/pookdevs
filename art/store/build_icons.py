#!/usr/bin/env python3
"""Draws the icons for Sweetopia's game passes and developer products.

Each icon is a 512 x 512 round badge with a pink frosting rim, saved as an SVG and
rendered to a PNG with headless Chrome. Roblox shows these icons in a circle, so
everything stays inside it. Run it again after changing a drawing:

    python3 art/store/build_icons.py
"""

import math
import pathlib
import random
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BROWN = "#5A3C46"
CREAM = "#FFFAF0"
FONT = "Arial Rounded MT Bold, Arial, sans-serif"

# Top and bottom colours of the gradients the drawings share.
GRADIENTS = {
    "gold": ("#FFEA8C", "#F2B238"),
    "goldDark": ("#E39C2C", "#B8741C"),
    "pink": ("#FFC2D3", "#EF86A6"),
    "red": ("#F47A7A", "#C83E4C"),
    "wood": ("#CF9563", "#9A6038"),
    "woodDark": ("#9B6440", "#6E4128"),
    "green": ("#86DB93", "#3E9E5A"),
    "sack": ("#EDCB98", "#C59158"),
    "stone": ("#F6EADB", "#D6BEA6"),
    "flame": ("#FFE76E", "#FF8A3D"),
    "snow": ("#FFFFFF", "#DCEBFA"),
    "ginger": ("#D99A5F", "#A86534"),
    "purple": ("#D9C2FF", "#A47FE6"),
}

# The frosting ring: its middle radius and width, and the drips hanging from its top
# half as (degrees from the top, length).
RIM = 228
RIM_WIDTH = 36
DRIPS = [(-48, 50), (-28, 70), (-9, 42), (12, 62), (31, 40), (50, 56)]
SPRINKLES = ["#FFE15C", "#7FD3F7", "#8EE08E", "#FFFFFF", "#C99BFF", "#FF8C8C"]


def outline(width=8):
    return f'stroke="{BROWN}" stroke-width="{width:g}" stroke-linejoin="round" stroke-linecap="round"'


O = outline()


def arc(x, y, r, start, end):
    """An arc path, with angles in degrees clockwise from the right."""
    a0, a1 = math.radians(start), math.radians(end)
    x0, y0 = x + r * math.cos(a0), y + r * math.sin(a0)
    x1, y1 = x + r * math.cos(a1), y + r * math.sin(a1)
    large = 1 if end - start > 180 else 0
    return f"M{x0:.1f},{y0:.1f} A{r:g},{r:g} 0 {large} 1 {x1:.1f},{y1:.1f}"


def shine(x, y, r, start=200, end=245, width=None, opacity=0.85):
    width = width or max(3, r * 0.12)
    return (
        f'<path d="{arc(x, y, r, start, end)}" fill="none" stroke="#FFFFFF" '
        f'stroke-width="{width:.1f}" stroke-linecap="round" opacity="{opacity}"/>'
    )


def sparkle(x, y, r, color="#FFFFFF", opacity=0.9):
    d = f"M{x},{y - r} Q{x},{y} {x + r},{y} Q{x},{y} {x},{y + r} Q{x},{y} {x - r},{y} Q{x},{y} {x},{y - r} Z"
    return f'<path d="{d}" fill="{color}" opacity="{opacity}"/>'


def text(x, y, words, size):
    common = f'x="{x}" font-family="{FONT}" font-weight="bold" font-size="{size}" text-anchor="middle"'
    stroke = f'stroke="{BROWN}" stroke-width="{size * 0.13:.0f}" stroke-linejoin="round"'
    return (
        f'<text {common} y="{y + size * 0.06:.0f}" fill="{BROWN}" {stroke}>{words}</text>'
        f'<text {common} y="{y}" fill="{CREAM}" {stroke} paint-order="stroke">{words}</text>'
    )


def coin(x, y, r):
    """A gold coin facing the viewer, with its edge showing underneath."""
    return (
        f'<circle cx="{x}" cy="{y + r * 0.14:.1f}" r="{r}" fill="url(#goldDark)" {O}/>'
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#gold)" {O}/>'
        f'<circle cx="{x}" cy="{y}" r="{r * 0.68:.1f}" fill="none" stroke="#E2A032" stroke-width="{r * 0.09:.1f}"/>'
        f'<circle cx="{x}" cy="{y}" r="{r * 0.4:.1f}" fill="#F6C24A" stroke="#E2A032" stroke-width="{r * 0.06:.1f}"/>'
        + shine(x, y, r * 0.84)
    )


def flat_coin(x, y, rx):
    """A gold coin lying flat, seen from a little above."""
    ry, t = rx * 0.45, rx * 0.26
    side = f"M{x - rx},{y} L{x - rx},{y + t:.1f} A{rx},{ry:.1f} 0 0 0 {x + rx},{y + t:.1f} L{x + rx},{y} Z"
    width = min(8, max(4, rx * 0.2))
    return (
        f'<path d="{side}" fill="url(#goldDark)" {outline(width)}/>'
        f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry:.1f}" fill="url(#gold)" {outline(width)}/>'
        f'<ellipse cx="{x}" cy="{y}" rx="{rx * 0.62:.1f}" ry="{ry * 0.62:.1f}" fill="none" stroke="#E2A032" stroke-width="{rx * 0.08:.1f}"/>'
    )


def star(x, y, r, rot=0, fill="url(#gold)", ratio=0.52):
    """A chubby five-pointed Sugar Star."""
    points = []
    for i in range(10):
        a = math.radians(rot - 90 + i * 36)
        reach = r if i % 2 == 0 else r * ratio
        points.append(f"{x + reach * math.cos(a):.1f},{y + reach * math.sin(a):.1f}")
    return (
        f'<polygon points="{" ".join(points)}" fill="{fill}" {outline(min(8, max(4, r * 0.16)))}/>'
        f'<ellipse cx="{x - r * 0.2:.1f}" cy="{y - r * 0.16:.1f}" rx="{r * 0.1:.1f}" ry="{r * 0.2:.1f}" '
        f'fill="#FFFFFF" opacity="0.8" transform="rotate(30 {x - r * 0.2:.1f} {y - r * 0.16:.1f})"/>'
    )


def gem(x, y, r, color):
    return (
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}" {outline(6)}/>'
        f'<circle cx="{x - r * 0.3:.1f}" cy="{y - r * 0.3:.1f}" r="{r * 0.28:.1f}" fill="#FFFFFF" opacity="0.85"/>'
    )


def frosting():
    inner = RIM - RIM_WIDTH / 2

    def layer(color, extra):
        parts = [f'<circle cx="256" cy="256" r="{RIM}" fill="none" stroke="{color}" stroke-width="{RIM_WIDTH + extra}"/>']
        for angle, length in DRIPS:
            x = 256 + inner * math.sin(math.radians(angle))
            y = 256 - inner * math.cos(math.radians(angle))
            parts.append(
                f'<line x1="{x:.1f}" y1="{y - 16:.1f}" x2="{x:.1f}" y2="{y + length:.1f}" '
                f'stroke="{color}" stroke-width="{26 + extra}" stroke-linecap="round"/>'
            )
            parts.append(f'<circle cx="{x:.1f}" cy="{y + length:.1f}" r="{16 + extra / 2:g}" fill="{color}"/>')
        return "".join(parts)

    parts = [layer(BROWN, 16), layer("#F7A1BC", 0)]
    parts.append(
        f'<path d="{arc(256, 256, RIM + 8, 205, 255)}" fill="none" stroke="#FFD9E5" stroke-width="7" stroke-linecap="round"/>'
    )
    for angle, length in DRIPS:
        x = 256 + inner * math.sin(math.radians(angle))
        y = 256 - inner * math.cos(math.radians(angle)) + length
        parts.append(f'<circle cx="{x - 5:.1f}" cy="{y - 5:.1f}" r="4.5" fill="#FFFFFF" opacity="0.8"/>')
    rng = random.Random(7)
    for i in range(22):
        a = math.radians(i * 360 / 22 + rng.uniform(-5, 5))
        r = RIM + rng.uniform(-9, 9)
        x, y = 256 + r * math.cos(a), 256 + r * math.sin(a)
        turn = math.radians(rng.uniform(0, 180))
        dx, dy = 7 * math.cos(turn), 7 * math.sin(turn)
        parts.append(
            f'<line x1="{x - dx:.1f}" y1="{y - dy:.1f}" x2="{x + dx:.1f}" y2="{y + dy:.1f}" '
            f'stroke="{SPRINKLES[i % len(SPRINKLES)]}" stroke-width="6" stroke-linecap="round"/>'
        )
    return "".join(parts)


def badge(background, body):
    defs = [
        f'<radialGradient id="bg" cx="0.5" cy="0.4" r="0.6">'
        f'<stop offset="0" stop-color="{background[0]}"/><stop offset="1" stop-color="{background[1]}"/></radialGradient>',
        '<clipPath id="inner"><circle cx="256" cy="256" r="212"/></clipPath>',
    ]
    for name, (top, bottom) in GRADIENTS.items():
        defs.append(
            f'<linearGradient id="{name}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
        )
    glints = "".join(sparkle(x, y, r, opacity=0.6) for x, y, r in [(118, 236, 14), (398, 300, 12), (150, 392, 10), (372, 160, 10)])
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
        f'<defs>{"".join(defs)}</defs>'
        '<circle cx="256" cy="256" r="212" fill="url(#bg)"/>'
        f'<g clip-path="url(#inner)">{glints}{body}</g>'
        f"{frosting()}</svg>"
    )


# Passes


def double_coins():
    return (
        coin(302, 206, 80)
        + coin(214, 258, 96)
        + sparkle(352, 300, 16)
        + sparkle(128, 168, 13)
        + text(256, 428, "2x", 116)
    )


def vip():
    carpet = (
        '<polygon points="170,480 342,480 288,300 224,300" fill="url(#red)" ' + O + "/>"
        '<line x1="186" y1="480" x2="232" y2="304" stroke="#F2C14E" stroke-width="7"/>'
        '<line x1="326" y1="480" x2="280" y2="304" stroke="#F2C14E" stroke-width="7"/>'
    )
    crown = (
        f'<path d="M150,262 L134,150 L200,204 L256,116 L312,204 L378,150 L362,262 Z" fill="url(#gold)" {O}/>'
        f'<rect x="144" y="244" width="224" height="46" rx="14" fill="url(#gold)" {O}/>'
        + shine(256, 330, 150, 236, 262, width=7, opacity=0.6)
        + gem(134, 150, 15, "#F58FB0")
        + gem(256, 116, 17, "#F58FB0")
        + gem(378, 150, 15, "#F58FB0")
        + gem(196, 267, 12, "#7FC8F5")
        + gem(256, 267, 15, "#E8506A")
        + gem(316, 267, 12, "#8EE08E")
    )
    return carpet + crown + sparkle(110, 210, 14) + sparkle(404, 228, 14) + text(256, 410, "VIP", 104)


def bunting(y_end, y_mid, colours):
    p0, p1, p2 = (92, y_end), (256, y_mid * 2 - y_end), (420, y_end)
    parts = [f'<path d="M{p0[0]},{p0[1]} Q{p1[0]},{p1[1]} {p2[0]},{p2[1]}" fill="none" stroke="{BROWN}" stroke-width="5"/>']
    count = len(colours)
    for i, colour in enumerate(colours):
        t = (i + 0.5) / count
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1]
        parts.append(
            f'<polygon points="{x - 17:.1f},{y:.1f} {x + 17:.1f},{y:.1f} {x:.1f},{y + 38:.1f}" fill="{colour}" {outline(5)}/>'
        )
    return "".join(parts)


def starter_pack():
    box = (
        f'<rect x="166" y="336" width="180" height="106" rx="10" fill="url(#pink)" {O}/>'
        + "".join(
            f'<circle cx="{x}" cy="{y}" r="7" fill="#FFFFFF" opacity="0.85"/>'
            for x, y in [(194, 366), (214, 418), (298, 362), (322, 412), (188, 428), (300, 430)]
        )
        + f'<rect x="242" y="336" width="28" height="106" fill="url(#gold)" {outline(6)}/>'
        + f'<rect x="152" y="318" width="208" height="34" rx="8" fill="url(#pink)" {O}/>'
        + f'<rect x="242" y="318" width="28" height="34" fill="url(#gold)" {outline(6)}/>'
    )
    popping = coin(184, 304, 30) + coin(330, 300, 32) + star(256, 278, 56, rot=-8)
    return (
        bunting(214, 250, ["#F58FB0", "#FFD45C", "#7FC8F5", "#8EE08E", "#C99BFF", "#FF9F6B", "#F58FB0"])
        + popping
        + box
        + sparkle(160, 248, 13)
        + sparkle(354, 238, 15)
    )


def cozy_pack():
    floor = f'<ellipse cx="256" cy="430" rx="190" ry="40" fill="#F4A3B8" {O}/>'
    floor += f'<ellipse cx="256" cy="430" rx="150" ry="26" fill="none" stroke="#FFD1DE" stroke-width="6"/>'
    books = ""
    for i, (colour, height) in enumerate(
        [("#E8506A", 46), ("#7FC8F5", 40), ("#8EE08E", 48), ("#FFD45C", 38), ("#C99BFF", 44), ("#F58FB0", 42), ("#FF9F6B", 46)]
    ):
        x = 108 + (i % 4) * 13
        y = 254 if i < 4 else 322
        books += f'<rect x="{x}" y="{y + 50 - height}" width="12" height="{height}" rx="2" fill="{colour}" {outline(4)}/>'
    bookshelf = (
        f'<rect x="96" y="200" width="76" height="190" rx="6" fill="url(#wood)" {O}/>'
        f'<rect x="104" y="214" width="60" height="164" fill="#6E4128"/>'
        f'<rect x="104" y="230" width="60" height="7" fill="url(#wood)"/>'
        f'<rect x="104" y="304" width="60" height="7" fill="url(#wood)"/>'
        + books
    )
    fireplace = (
        f'<rect x="170" y="196" width="172" height="216" rx="10" fill="url(#stone)" {O}/>'
        + "".join(
            f'<rect x="{x}" y="{y}" width="34" height="16" rx="5" fill="#E8D6C2"/>'
            for x, y in [(182, 222), (296, 236), (186, 330), (300, 360), (192, 380)]
        )
        + f'<path d="M206,412 L206,292 Q206,252 256,252 Q306,252 306,292 L306,412 Z" fill="#4A2C32" {O}/>'
        + f'<rect x="216" y="384" width="80" height="16" rx="8" fill="url(#woodDark)" {outline(5)}/>'
        + f'<path d="M256,300 C230,330 222,352 232,374 C238,388 274,388 280,374 C290,352 282,330 256,300 Z" fill="url(#flame)" {outline(5)}/>'
        + '<path d="M256,334 C246,350 244,362 248,372 C252,380 260,380 264,372 C268,362 266,350 256,334 Z" fill="#FFF3B0"/>'
        + f'<rect x="156" y="182" width="200" height="24" rx="8" fill="url(#wood)" {O}/>'
        + f'<rect x="226" y="154" width="14" height="30" rx="4" fill="#FFFAF0" {outline(5)}/>'
        + '<path d="M233,140 C228,148 228,152 233,155 C238,152 238,148 233,140 Z" fill="#FFB347"/>'
        + f'<circle cx="300" cy="166" r="18" fill="#8EE08E" {outline(5)}/>'
        + f'<rect x="290" y="168" width="20" height="16" rx="3" fill="#F58FB0" {outline(5)}/>'
    )
    armchair = (
        f'<path d="M306,392 L306,300 Q306,268 350,268 Q394,268 394,300 L394,392 Z" fill="url(#pink)" {O}/>'
        f'<rect x="300" y="340" width="100" height="40" rx="12" fill="#F7B3C6" {O}/>'
        f'<rect x="288" y="318" width="28" height="74" rx="12" fill="url(#pink)" {O}/>'
        f'<rect x="384" y="318" width="28" height="74" rx="12" fill="url(#pink)" {O}/>'
        f'<rect x="300" y="388" width="10" height="18" rx="3" fill="url(#woodDark)" {outline(4)}/>'
        f'<rect x="390" y="388" width="10" height="18" rx="3" fill="url(#woodDark)" {outline(4)}/>'
    )
    return floor + bookshelf + fireplace + armchair


def winter_pack():
    flakes = "".join(
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFFFFF" opacity="0.9"/>'
        for x, y, r in [(150, 150, 6), (230, 196, 5), (300, 150, 7), (380, 210, 6), (110, 270, 5), (420, 280, 5), (260, 250, 4)]
    )
    ground = f'<ellipse cx="256" cy="476" rx="270" ry="108" fill="url(#snow)" {O}/>'
    tree = (
        f'<rect x="161" y="336" width="28" height="40" rx="4" fill="url(#woodDark)" {outline(6)}/>'
        f'<polygon points="92,348 258,348 175,246" fill="url(#green)" {O}/>'
        f'<polygon points="108,290 242,290 175,204" fill="url(#green)" {O}/>'
        f'<polygon points="126,234 224,234 175,164" fill="url(#green)" {O}/>'
        + gem(140, 330, 9, "#E8506A")
        + gem(206, 318, 9, "#7FC8F5")
        + gem(160, 272, 8, "#FFD45C")
        + gem(198, 220, 8, "#F58FB0")
        + star(175, 160, 24)
    )
    gumdrops = "".join(
        f'<circle cx="{x}" cy="{y}" r="7" fill="{c}" {outline(4)}/>'
        for x, y, c in [(228, 322, "#E8506A"), (256, 302, "#8EE08E"), (284, 322, "#7FC8F5")]
    )
    house = (
        f'<rect x="206" y="340" width="100" height="84" rx="6" fill="url(#ginger)" {O}/>'
        f'<path d="M240,424 L240,394 Q240,380 256,380 Q272,380 272,394 L272,424 Z" fill="#7A4524" {outline(6)}/>'
        f'<rect x="216" y="356" width="20" height="20" rx="3" fill="#FFE76E" {outline(5)}/>'
        f'<rect x="276" y="356" width="20" height="20" rx="3" fill="#FFE76E" {outline(5)}/>'
        f'<polygon points="190,350 322,350 256,282" fill="url(#ginger)" {O}/>'
        f'<path d="M192,350 Q204,362 216,350 Q228,362 240,350 Q252,362 264,350 Q276,362 288,350 Q300,362 312,350 Q318,356 322,350" '
        f'fill="none" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round"/>'
        f'<path d="M200,342 L256,288 L312,342" fill="none" stroke="#FFFFFF" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
        + gumdrops
    )
    snowman = (
        f'<circle cx="356" cy="376" r="50" fill="url(#snow)" {O}/>'
        f'<circle cx="356" cy="296" r="36" fill="url(#snow)" {O}/>'
        f'<path d="M322,324 Q356,340 390,324 L392,338 Q356,354 320,338 Z" fill="#E8506A" {outline(6)}/>'
        f'<rect x="370" y="330" width="16" height="34" rx="5" fill="#E8506A" {outline(6)}/>'
        f'<circle cx="344" cy="290" r="4.5" fill="{BROWN}"/>'
        f'<circle cx="368" cy="290" r="4.5" fill="{BROWN}"/>'
        f'<polygon points="356,298 384,306 356,308" fill="#FF9F45" {outline(4)}/>'
        f'<rect x="334" y="232" width="44" height="34" rx="5" fill="#6E4128" {outline(6)}/>'
        f'<rect x="322" y="260" width="68" height="12" rx="5" fill="#6E4128" {outline(6)}/>'
        f'<circle cx="356" cy="364" r="5" fill="{BROWN}"/>'
        f'<circle cx="356" cy="388" r="5" fill="{BROWN}"/>'
    )
    return flakes + ground + tree + snowman + house


# Developer products


def sack(x, y, scale, fill, emblem):
    """A closed drawstring sack around (x, y), with an emblem on its front."""
    return (
        f'<g transform="translate({x} {y}) scale({scale})">'
        f'<path d="M-44,-72 L-72,-124 Q0,-104 72,-124 L44,-72 Z" fill="{fill}" {O}/>'
        f'<path d="M-60,-70 C-128,-8 -122,110 0,110 C122,110 128,-8 60,-70 Z" fill="{fill}" {O}/>'
        f'<rect x="-58" y="-86" width="116" height="22" rx="11" fill="url(#woodDark)" {O}/>'
        + shine(0, 30, 92, 200, 238, width=8, opacity=0.5)
        + emblem
        + "</g>"
    )


def open_sack(x, y, scale, heap):
    """An open sack around (x, y), heaped with the given drawing."""
    return (
        f'<g transform="translate({x} {y}) scale({scale})">'
        f'<path d="M-74,-62 C-134,0 -126,112 0,112 C126,112 134,0 74,-62 Z" fill="url(#sack)" {O}/>'
        f'<ellipse cx="0" cy="-62" rx="80" ry="24" fill="url(#sack)" {O}/>'
        f'<ellipse cx="0" cy="-62" rx="62" ry="14" fill="#6E4128"/>'
        + heap
        + shine(0, 30, 96, 200, 236, width=8, opacity=0.5)
        + coin(0, 26, 40)
        + "</g>"
    )


def chest(heap):
    return (
        f'<polygon points="148,300 364,300 348,196 164,196" fill="url(#woodDark)" {O}/>'
        f'<rect x="174" y="200" width="18" height="100" fill="url(#gold)" {outline(5)}/>'
        f'<rect x="320" y="200" width="18" height="100" fill="url(#gold)" {outline(5)}/>'
        + heap
        + f'<rect x="138" y="298" width="236" height="124" rx="12" fill="url(#wood)" {O}/>'
        + f'<rect x="132" y="290" width="248" height="24" rx="8" fill="url(#woodDark)" {O}/>'
        + f'<rect x="168" y="290" width="22" height="132" fill="url(#gold)" {outline(6)}/>'
        + f'<rect x="322" y="290" width="22" height="132" fill="url(#gold)" {outline(6)}/>'
        + f'<rect x="234" y="314" width="44" height="48" rx="8" fill="url(#gold)" {O}/>'
        + f'<path d="M256,328 a7,7 0 1 1 0.1,0 L262,348 L250,348 Z" fill="{BROWN}"/>'
    )


def coin_heap():
    coins = [(196, 290, 30), (316, 290, 30), (256, 296, 32), (226, 268, 30), (288, 268, 30), (256, 244, 30)]
    return f'<ellipse cx="256" cy="298" rx="104" ry="36" fill="url(#gold)" {O}/>' + "".join(flat_coin(*c) for c in coins)


def star_heap():
    stars = [(190, 286, 26, -10), (322, 286, 26, 14), (256, 292, 28, 0), (222, 258, 28, 18), (292, 256, 28, -16), (256, 222, 32, 6)]
    return f'<ellipse cx="256" cy="298" rx="104" ry="36" fill="url(#purple)" {O}/>' + "".join(star(*s) for s in stars)


def coin_bag():
    return (
        sack(256, 302, 0.95, "url(#sack)", coin(0, 22, 40))
        + flat_coin(160, 414, 26)
        + flat_coin(352, 410, 24)
        + sparkle(352, 196, 15)
    )


def coin_sack():
    heap = flat_coin(-34, -80, 26) + flat_coin(28, -84, 26) + flat_coin(-4, -104, 26) + flat_coin(-50, -60, 22) + flat_coin(46, -62, 22)
    return (
        open_sack(256, 290, 1.1, heap)
        + flat_coin(142, 410, 26)
        + flat_coin(186, 428, 24)
        + flat_coin(362, 404, 26)
        + flat_coin(330, 430, 22)
        + sparkle(372, 168, 16)
        + sparkle(140, 186, 13)
    )


def coin_chest():
    return chest(coin_heap()) + flat_coin(126, 418, 22) + flat_coin(392, 414, 22) + sparkle(130, 214, 15) + sparkle(392, 196, 16)


def star_pouch():
    return (
        sack(256, 302, 0.95, "url(#pink)", star(0, 22, 44))
        + star(158, 404, 24, rot=-14)
        + star(352, 396, 20, rot=12)
        + sparkle(352, 196, 15)
    )


def star_jar():
    stars = ""
    rng = random.Random(3)
    for row, y in enumerate(range(408, 248, -34)):
        for x in range(194 + (row % 2) * 18, 330, 36):
            stars += star(x, y + rng.uniform(-4, 4), 21, rot=rng.uniform(-30, 30))
    return (
        '<defs><clipPath id="jar"><rect x="176" y="214" width="160" height="212" rx="44"/></clipPath></defs>'
        '<rect x="176" y="214" width="160" height="212" rx="44" fill="#E6F5FF" opacity="0.6"/>'
        f'<g clip-path="url(#jar)">{stars}</g>'
        f'<rect x="176" y="214" width="160" height="212" rx="44" fill="none" {O}/>'
        '<rect x="192" y="240" width="14" height="150" rx="7" fill="#FFFFFF" opacity="0.75"/>'
        f'<rect x="190" y="196" width="132" height="26" rx="8" fill="#E6F5FF" {O}/>'
        f'<rect x="182" y="160" width="148" height="42" rx="12" fill="url(#pink)" {O}/>'
        + "".join(f'<rect x="{x}" y="166" width="10" height="30" rx="4" fill="#FFFFFF" opacity="0.8"/>' for x in range(200, 320, 24))
        + sparkle(132, 236, 15)
        + sparkle(384, 288, 16)
    )


def star_chest():
    return chest(star_heap()) + star(124, 410, 20, rot=-12) + star(392, 404, 20, rot=10) + sparkle(130, 214, 15) + sparkle(392, 196, 16)


def boost():
    bolt = f'<polygon points="232,116 122,290 198,290 166,432 304,238 228,238 282,116" fill="url(#gold)" {O}/>'
    bolt += '<path d="M240,132 L156,272" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" opacity="0.8"/>'
    watch = (
        f'<rect x="342" y="148" width="26" height="20" rx="5" fill="url(#gold)" {outline(6)}/>'
        f'<circle cx="355" cy="222" r="50" fill="url(#pink)" {O}/>'
        f'<circle cx="355" cy="222" r="36" fill="{CREAM}" {outline(5)}/>'
        + "".join(
            f'<circle cx="{355 + 28 * math.cos(math.radians(a)):.1f}" cy="{222 + 28 * math.sin(math.radians(a)):.1f}" r="3" fill="{BROWN}"/>'
            for a in range(0, 360, 90)
        )
        + f'<path d="M355,222 L355,198 M355,222 L372,232" stroke="{BROWN}" stroke-width="6" stroke-linecap="round"/>'
        f'<circle cx="355" cy="222" r="5" fill="{BROWN}"/>'
    )
    return bolt + watch + sparkle(120, 200, 14) + text(330, 404, "2x", 104)


# File name, background colours (middle, edge) and drawing for each icon.
ICONS = [
    ("DoubleCoins", ("#FFF6D2", "#FFCF66"), double_coins),
    ("VIP", ("#D5DBFF", "#7C8CE8"), vip),
    ("StarterPack", ("#DDF2FF", "#7FC4EE"), starter_pack),
    ("CozyPack", ("#FFE6C4", "#F2A766"), cozy_pack),
    ("WinterPack", ("#EEF8FF", "#9ECDF0"), winter_pack),
    ("CoinBag", ("#E2F8E6", "#8ED6A2"), coin_bag),
    ("CoinSack", ("#E2F8E6", "#8ED6A2"), coin_sack),
    ("CoinChest", ("#E2F8E6", "#8ED6A2"), coin_chest),
    ("StarPouch", ("#F1EAFF", "#B9A2EE"), star_pouch),
    ("StarJar", ("#F1EAFF", "#B9A2EE"), star_jar),
    ("StarChest", ("#F1EAFF", "#B9A2EE"), star_chest),
    ("2xBoost", ("#D8F8F4", "#5FC9BF"), boost),
]


def main():
    for name, background, draw in ICONS:
        svg = HERE / f"{name}.svg"
        png = HERE / f"{name}.png"
        svg.write_text(badge(background, draw()))
        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                "--window-size=512,512",
                f"--screenshot={png}",
                svg.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
        print(png.name)


if __name__ == "__main__":
    main()
