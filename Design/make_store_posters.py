"""Builds the App Store screenshots as poster-style SVGs, then renders them.

Usage: python3 make_store_posters.py <screenshots dir> <output dir>
Each slide: flat colour field, a Didot headline, the app screen in a phone
outline with an offset ink line, hatching and hand-drawn marks.
"""
import subprocess
import sys
from pathlib import Path

SHOTS = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

INK = "#1E2340"
PAPER = "#F2EBE1"

SLIDES = [
    ("1-home", "Your money,", "on a cozy shelf", "EVERY BOOK OPENS WHAT IT SHOWS", PAPER, "#F1D488", INK),
    ("2-add", "Add a spend", "in seconds", "AMOUNT · CATEGORY · DONE", "#EDBFB3", PAPER, INK),
    ("3-bill", "Keep every bill", "close at hand", "PHOTO OR PDF, OPEN IT IN A TAP", "#9DB89A", "#F1D488", INK),
    ("4-goal", "Watch your", "savings grow", "GOALS, DEADLINES, EVERY TOP-UP", "#F1D488", "#D2654A", INK),
    ("5-overview", "See where", "it all goes", "A CLEAR PICTURE OF EVERY MONTH", "#B9A6CF", PAPER, INK),
    ("6-styles", "A home page", "that feels like you", "SEVEN ROOMS, CHRISTMAS INCLUDED", "#D2654A", "#F1D488", PAPER),
]

W, H = 1320, 2868
PHONE_W = 900
PHONE_H = round(PHONE_W * 2622 / 1206)
PX = (W - PHONE_W) // 2
PY = 860


def slide(name, line1, line2, sub, bg, accent, text):
    shot = (SHOTS / f"{name}.png").as_uri()
    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
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
  <image href="{shot}" xlink:href="{shot}" x="{PX}" y="{PY}" width="{PHONE_W}" height="{PHONE_H}" clip-path="url(#screen)" preserveAspectRatio="xMidYMin slice"/>
  <rect x="{PX}" y="{PY}" width="{PHONE_W}" height="{PHONE_H}" rx="118" fill="none" stroke="{INK}" stroke-width="10"/>

  <rect width="{W}" height="{H}" filter="url(#grain)" opacity="0.06" style="mix-blend-mode:multiply"/>
</svg>
"""


for args in SLIDES:
    name = args[0]
    svg = OUT / f"{name}.svg"
    svg.write_text(slide(*args))
    png = OUT / f"{name}.png"
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
         "--allow-file-access-from-files", f"--window-size={W},{H}",
         f"--user-data-dir={OUT.parent / '.chrome'}", f"--screenshot={png}", svg.as_uri()],
        capture_output=True,
    )
    # App Store Connect rejects screenshots with an alpha channel.
    jpg = OUT / f"{name}.jpg"
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "92", str(png), "--out", str(jpg)], capture_output=True)
    png.unlink()
    svg.unlink()
    print("wrote", jpg.name)
