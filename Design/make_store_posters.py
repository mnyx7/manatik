"""Builds the App Store screenshots as poster-style SVGs, then renders them.

Usage: python3 make_store_posters.py <screenshots dir> <output dir>
Each slide: flat colour field, a Didot headline, the app screen in a phone
outline with an offset ink line, hatching and hand-drawn marks.
"""
import base64
import subprocess
import sys
from pathlib import Path

SHOTS = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)

INK = "#1E2340"
PAPER = "#F2EBE1"

SLIDES = [
    ("1-home", "Your money,", "feels at home", "EVERY BOOK OPENS WHAT IT SHOWS", PAPER, "#F1D488", INK),
    ("2-add", "Add a spend", "in seconds", "AMOUNT · CATEGORY · DONE", "#EDBFB3", PAPER, INK),
    ("3-bill", "Keep every bill", "close at hand", "PHOTO OR PDF, OPEN IT IN A TAP", "#9DB89A", "#F1D488", INK),
    ("4-goal", "Watch your", "savings grow", "GOALS, DEADLINES, EVERY TOP-UP", "#F1D488", "#D2654A", INK),
    ("5-overview", "See where", "it all goes", "A CLEAR PICTURE OF EVERY MONTH", "#B9A6CF", PAPER, INK),
    ("6-currency", "Every currency,", "every trip", "EACH ENTRY KEEPS ITS OWN CURRENCY", "#A9C7D6", "#F1D488", INK),
    ("7-styles", "A home page", "that feels like you", "SEVEN ROOMS, CHRISTMAS INCLUDED", "#D2654A", "#F1D488", PAPER),
    ("8-widget", "Add from your", "Home Screen", "ONE TAP OPENS NEW ENTRY", "#DDE9D3", "#EDBFB3", INK),
]

DESIGN = Path(__file__).resolve().parent

W, H = 1320, 2868
PHONE_W = 900
PHONE_H = round(PHONE_W * 2622 / 1206)
PX = (W - PHONE_W) // 2
PY = 860


def data_uri(path):
    """Images are embedded: WebKit renders the SVG as an <img>, which may not
    load linked files."""
    return "data:image/png;base64," + base64.b64encode(Path(path).read_bytes()).decode()


def sparkle(cx, cy, r, fill):
    """A four-point sparkle, with the ink shadow offset like the logo's."""
    d = lambda x, y: (f"M{x} {y - r} Q{x + r * 0.18} {y - r * 0.18} {x + r} {y} "
                      f"Q{x + r * 0.18} {y + r * 0.18} {x} {y + r} "
                      f"Q{x - r * 0.18} {y + r * 0.18} {x - r} {y} "
                      f"Q{x - r * 0.18} {y - r * 0.18} {x} {y - r} Z")
    return f'<path d="{d(cx + 5, cy + 5)}" fill="{INK}"/><path d="{d(cx, cy)}" fill="{fill}"/>'


def home_screen():
    """A drawn iPhone Home Screen carrying the Quick add widget, for the one
    slide a simulator screenshot cannot show."""
    s = PHONE_W / 1206  # device pixels to poster pixels
    icon, gap = round(192 * s), round(66 * s)
    left = PX + round(78 * s)
    top = PY + round(230 * s)
    wsize = icon * 2 + gap
    parts = [f'<rect x="{PX}" y="{PY}" width="{PHONE_W}" height="{PHONE_H}" fill="url(#wall)"/>']

    # The widget: cream square, mint circle, terracotta badge with the + .
    wx, wy = left, top
    cx, cy = wx + wsize / 2, wy + wsize / 2
    parts += [
        f'<rect x="{wx}" y="{wy}" width="{wsize}" height="{wsize}" rx="{round(wsize * 0.22)}" fill="#FBF7F2"/>',
        f'<circle cx="{cx}" cy="{cy}" r="{wsize * 0.36}" fill="#DDE9D3"/>',
        f'<circle cx="{cx + 6}" cy="{cy + 6}" r="{wsize * 0.245}" fill="#3B2F2C"/>',
        f'<circle cx="{cx}" cy="{cy}" r="{wsize * 0.245}" fill="#C8552F"/>',
        f'<path d="M{cx} {cy - wsize * 0.11} V{cy + wsize * 0.11} M{cx - wsize * 0.11} {cy} H{cx + wsize * 0.11}" '
        f'stroke="#FFFFFF" stroke-width="{wsize * 0.055}" stroke-linecap="round"/>',
        sparkle(cx + wsize * 0.30, cy - wsize * 0.28, wsize * 0.07, "#F7C95A"),
        sparkle(cx - wsize * 0.31, cy + wsize * 0.23, wsize * 0.045, "#FFFFFF"),
    ]

    # App icons beside and below it; muna's real icon sits next to the widget.
    tones = ["#F6A9A0", "#A9C7D6", "#F1D488", "#B9A6CF", "#9DB89A", "#EDBFB3", "#A9C7D6", "#F1D488"]
    slots = [(left + wsize + gap + c * (icon + gap), top + r * (icon + gap)) for r in range(2) for c in range(2)]
    slots += [(left + c * (icon + gap), top + wsize + gap + round(40 * s) + r * (icon + gap))
              for r in range(2) for c in range(4)]
    logo = data_uri(DESIGN / "app-icon.png")
    for i, (x, y) in enumerate(slots[:10]):
        if i == 0:
            parts.append(f'<clipPath id="ic"><rect x="{x}" y="{y}" width="{icon}" height="{icon}" rx="{round(icon * 0.225)}"/></clipPath>'
                         f'<image href="{logo}" xlink:href="{logo}" x="{x}" y="{y}" width="{icon}" height="{icon}" clip-path="url(#ic)"/>')
        else:
            parts.append(f'<rect x="{x}" y="{y}" width="{icon}" height="{icon}" rx="{round(icon * 0.225)}" fill="{tones[i % len(tones)]}" opacity="0.75"/>')
    # Dock.
    dy = PY + PHONE_H - round(300 * s)
    parts.append(f'<rect x="{PX + round(40 * s)}" y="{dy}" width="{PHONE_W - round(80 * s)}" height="{round(250 * s)}" rx="{round(90 * s)}" fill="#FFFFFF" opacity="0.35"/>')
    for c in range(4):
        x = PX + round(90 * s) + c * (icon + round(84 * s))
        parts.append(f'<rect x="{x}" y="{dy + round(29 * s)}" width="{icon}" height="{icon}" rx="{round(icon * 0.225)}" fill="{tones[(c + 3) % len(tones)]}" opacity="0.75"/>')
    # Status bar.
    parts.append(f'<text x="{PX + round(150 * s)}" y="{PY + round(110 * s)}" font-family="Avenir Next" font-weight="600" font-size="{round(50 * s)}" fill="{INK}">9:41</text>')
    return "\n  ".join(parts)


def slide(name, line1, line2, sub, bg, accent, text):
    if name == "8-widget":
        screen = home_screen()
    else:
        shot = data_uri(SHOTS / f"{name}.png")
        screen = (f'<image href="{shot}" xlink:href="{shot}" x="{PX}" y="{PY}" width="{PHONE_W}" height="{PHONE_H}" '
                  f'clip-path="url(#screen)" preserveAspectRatio="xMidYMin slice"/>')
    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
    <linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F2EBE1"/><stop offset="1" stop-color="#E7D7C6"/></linearGradient>
    <filter id="rough" x="-5%" y="-5%" width="110%" height="110%">
      <feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="2" seed="9" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="7" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
    <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="4"/><feColorMatrix type="saturate" values="0"/></filter>
    <pattern id="hatch" width="18" height="18" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
      <line x1="0" y1="0" x2="0" y2="18" stroke="{INK}" stroke-width="3.5"/>
    </pattern>
    <clipPath id="screen"><rect x="{PX}" y="{PY}" width="{PHONE_W}" height="{PHONE_H}" rx="118"/></clipPath>
  </defs>
  <rect width="{W}" height="{H}" fill="{bg}"/>

  <g filter="url(#rough)">
    <circle cx="{W - 170}" cy="{PY + 260}" r="330" fill="{accent}"/>
    <circle cx="{W - 156}" cy="{PY + 246}" r="330" fill="none" stroke="{INK}" stroke-width="4"/>
    <rect x="0" y="{H - 520}" width="{W}" height="520" fill="url(#hatch)" opacity="0.18"/>
    <path d="M60 {H - 520} H{W - 60}" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
    <g stroke="{text}" stroke-width="6" stroke-linecap="round">
      <path d="M140 640 v56 M112 668 h56 M120 648 l40 40 M160 648 l-40 40"/>
      <path d="M{W - 150} 150 h40 M{W - 130} 130 v40"/>
    </g>
    <g fill="{text}"><circle cx="210" cy="760" r="8"/><circle cx="250" cy="732" r="6"/><circle cx="180" cy="800" r="5"/></g>
    <rect x="{PX + 14}" y="{PY - 14}" width="{PHONE_W}" height="{PHONE_H}" rx="118" fill="none" stroke="{INK}" stroke-width="7"/>
  </g>

  <text x="{W // 2}" y="150" text-anchor="middle" font-family="Avenir Next" font-weight="600" font-size="34" letter-spacing="10" fill="{text}">MUNA</text>
  <text x="{W // 2}" y="340" text-anchor="middle" font-family="Didot" font-size="130" fill="{text}">{line1}</text>
  <text x="{W // 2}" y="480" text-anchor="middle" font-family="Didot" font-style="italic" font-size="130" fill="{text}">{line2}</text>
  <text x="{W // 2}" y="600" text-anchor="middle" font-family="Avenir Next" font-weight="600" font-size="34" letter-spacing="7" fill="{text}" opacity="0.85">{sub}</text>

  <rect x="{PX}" y="{PY}" width="{PHONE_W}" height="{PHONE_H}" rx="118" fill="{PAPER}"/>
  <g clip-path="url(#screen)">
  {screen}
  </g>
  <rect x="{PX}" y="{PY}" width="{PHONE_W}" height="{PHONE_H}" rx="118" fill="none" stroke="{INK}" stroke-width="10"/>

  <rect width="{W}" height="{H}" filter="url(#grain)" opacity="0.06" style="mix-blend-mode:multiply"/>
</svg>
"""


for args in SLIDES:
    name = args[0]
    svg = OUT / f"{name}.svg"
    svg.write_text(slide(*args))
    png = OUT / f"{name}.png"
    # As an <img> WebKit applies the hand-drawn filters, which it skips when
    # the SVG is opened as the page itself.
    page = OUT / f"{name}.html"
    page.write_text(f'<html><body style="margin:0"><img src="{svg.name}" width="{W}" height="{H}" style="display:block"></body></html>')
    subprocess.run(
        ["swift", str(DESIGN / "render.swift"), str(page), str(png), str(W), str(H)],
        capture_output=True, check=True,
    )
    # App Store Connect rejects screenshots with an alpha channel.
    jpg = OUT / f"{name}.jpg"
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "92", str(png), "--out", str(jpg)], capture_output=True)
    png.unlink()
    svg.unlink()
    page.unlink()
    print("wrote", jpg.name)
