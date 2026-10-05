#!/usr/bin/env python3
"""Placeholder avatars for the UX capture harness (dev tooling, stdlib only).

Generates 512x512 PNG portraits (a diagonal two-colour gradient with the
person's initials) into ux_audit/out/avatars/ and serves that directory on
http://127.0.0.1:8765/ (iOS ATS exempts IP-address hosts, so plain http is OK
for the simulator). Run with no arguments to generate (idempotent) and serve;
`--generate-only` stops after generating.

Files: <key>.png where <key> is one of AVATARS below, e.g.
http://127.0.0.1:8765/amelie.png
"""
from __future__ import annotations

import colorsys
import functools
import http.server
import socketserver
import struct
import sys
import zlib
from pathlib import Path

SIZE = 512
HOST, PORT = "127.0.0.1", 8765
OUT = Path(__file__).resolve().parent.parent / "ux_audit" / "out" / "avatars"

# key -> (initials, hue 0..1). Keys are referenced by ux_audit/support/world.dart.
AVATARS = {
    "amelie": ("AL", 0.95),
    "bastien": ("BM", 0.58),
    "chloe": ("CD", 0.08),
    "dario": ("DR", 0.33),
    "emilia": ("EV", 0.75),
    "farid": ("FB", 0.50),
    "giulia": ("GP", 0.15),
    "hugo": ("HT", 0.62),
    "ines": ("IC", 0.88),
    "jules": ("JN", 0.40),
    "kenji": ("KS", 0.03),
    "lea": ("LO", 0.68),
}

# 5x7 bitmap glyphs, one string per row ('#' = ink).
FONT = {
    "A": [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "B": ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "],
    "C": [" ####", "#    ", "#    ", "#    ", "#    ", "#    ", " ####"],
    "D": ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
    "E": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
    "F": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "],
    "G": [" ####", "#    ", "#    ", "# ###", "#   #", "#   #", " ####"],
    "H": ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "I": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "#####"],
    "J": ["  ###", "   # ", "   # ", "   # ", "   # ", "#  # ", " ##  "],
    "K": ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"],
    "L": ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
    "M": ["#   #", "## ##", "# # #", "# # #", "#   #", "#   #", "#   #"],
    "N": ["#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #"],
    "O": [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    "P": ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "],
    "R": ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
    "S": [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
    "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
    "V": ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "],
}


def _hsv(h: float, s: float, v: float) -> tuple[int, int, int]:
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return int(r * 255), int(g * 255), int(b * 255)


def _render(initials: str, hue: float) -> bytes:
    """Raw RGB rows (each prefixed with filter byte 0) for the PNG."""
    c1, c2 = _hsv(hue, 0.55, 0.95), _hsv(hue + 0.08, 0.75, 0.62)
    scale, gap = 22, 18
    glyph_w, glyph_h = 5 * scale, 7 * scale
    total_w = len(initials) * glyph_w + (len(initials) - 1) * gap
    x0, y0 = (SIZE - total_w) // 2, (SIZE - glyph_h) // 2
    ink = set()
    for gi, ch in enumerate(initials):
        gx = x0 + gi * (glyph_w + gap)
        for ry, row in enumerate(FONT[ch]):
            for rx, cell in enumerate(row):
                if cell == "#":
                    for dy in range(scale):
                        for dx in range(scale):
                            ink.add((gx + rx * scale + dx, y0 + ry * scale + dy))
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        for x in range(SIZE):
            if (x, y) in ink:
                rows += b"\xff\xff\xff"
                continue
            t = (x + y) / (2 * (SIZE - 1))
            rows += bytes(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return bytes(rows)


def _png(raw: bytes) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )


def generate() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for key, (initials, hue) in AVATARS.items():
        path = OUT / f"{key}.png"
        if not path.exists():
            path.write_bytes(_png(_render(initials, hue)))
            print(f"generated {path}", flush=True)


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        pass


class _Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def serve() -> None:
    handler = functools.partial(_Quiet, directory=str(OUT))
    with _Server((HOST, PORT), handler) as httpd:
        print(f"serving {OUT} on http://{HOST}:{PORT}/", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    generate()
    if "--generate-only" not in sys.argv:
        serve()
