"""Strips the live objects out of the home illustrations, leaving the scenery.

The books, jar, pie, clock, calendar, balance and tab bar are drawn natively in
SwiftUI with real numbers, so the background keeps only what never changes.
The status bar strip is cropped off; the canvas starts at y=160 of the
1080x2340 design.
"""
import re
import sys
from pathlib import Path

DESIGN = Path(sys.argv[1])
OUT = Path(sys.argv[2])

COZY_CUTS = [
    ("<!-- BALANCE sign -->", "<!-- SHELF 1 -->"),
    ("<!-- Expenses -->", "<!-- SHELF 2 -->"),
    ("<!-- Savings jar -->", "<!-- PERIOD calendar -->"),
    ("<!-- PERIOD calendar -->", "<!-- window, decorative -->"),
    ("<!-- holly on the sign -->", "<!-- snowflakes in the gaps -->"),
    ("<!-- tab bar, as in the app -->", "\n  </g>\n\n  <rect width"),
]
POSTER_CUTS = [
    ("<!-- masthead -->", "<!-- SHELF 1 -->"),
    ("<!-- Expenses -->", "<!-- SHELF 2 -->"),
    ("<!-- Savings: an arch that fills -->", "<!-- PERIOD -->"),
    ("<!-- PERIOD -->", "<!-- sun behind her -->"),
    ("<!-- tab bar -->", "\n  </g>\n\n  <rect width"),
]

FILES = {
    "home-cozy-shelf": COZY_CUTS,
    "home-cozy-shelf-boy": COZY_CUTS,
    "home-cozy-shelf-xmas": COZY_CUTS,
    "home-poster": POSTER_CUTS,
    "home-poster-boy": POSTER_CUTS,
    "home-poster-xmas": POSTER_CUTS,
}


def cut(text: str, start: str, end: str) -> str:
    i = text.find(start)
    if i < 0:
        return text
    j = text.find(end, i + len(start))
    if j < 0:
        raise SystemExit(f"end marker {end!r} missing after {start!r}")
    return text[:i] + text[j:]


for name, cuts in FILES.items():
    text = (DESIGN / f"{name}.svg").read_text()
    for start, end in cuts:
        text = cut(text, start, end)
    # Status bar clock, poster frame, and the hidden tap map.
    text = re.sub(r'\s*<text x="70" y="100"[^>]*>9:41</text>', "", text)
    text = re.sub(r'\s*<rect class="ink" x="30" y="30"[^>]*/>', "", text)
    text = re.sub(r'\s*<g id="hotspots".*?</g>', "", text, flags=re.S)
    text = text.replace(
        'viewBox="0 0 1080 2340" width="1080" height="2340"',
        'viewBox="0 160 1080 1920" width="1179" height="2096"',
    )
    (OUT / f"{name}-bg.svg").write_text(text)
    print("wrote", name)
