"""Builds the short muna walkthrough deck (16:9) in the poster style.

Usage: python make_deck.py <screenshots dir> <app icon png> <output .pptx>
Needs python-pptx (which brings Pillow).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN
from pptx.util import Emu, Pt

SHOTS = Path(sys.argv[1])
ICON = Path(sys.argv[2])
OUT = Path(sys.argv[3])
WORK = OUT.parent / ".deck-work"
WORK.mkdir(exist_ok=True)

INK = RGBColor(0x1E, 0x23, 0x40)
PAPER = RGBColor(0xF2, 0xEB, 0xE1)
BLUSH = RGBColor(0xED, 0xBF, 0xB3)
SAGE = RGBColor(0x9D, 0xB8, 0x9A)
BUTTER = RGBColor(0xF1, 0xD4, 0x88)
LILAC = RGBColor(0xB9, 0xA6, 0xCF)
TERRA = RGBColor(0xD2, 0x65, 0x4A)

SERIF = "Didot"
SANS = "Avenir Next"

prs = Presentation()
prs.slide_width = Emu(12192000)   # 13.333 in
prs.slide_height = Emu(6858000)   # 7.5 in
SW, SH = prs.slide_width, prs.slide_height
BLANK = prs.slide_layouts[6]


def inches(value):
    return Emu(int(value * 914400))


def phone_image(name):
    """Screenshot with rounded corners and an offset ink outline, as a PNG."""
    src = Image.open(SHOTS / f"{name}.png").convert("RGBA")
    w, h = src.size
    radius = int(w * 0.13)
    pad = 40
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (pad + 22, pad - 22, pad + w + 22, pad + h - 22), radius, outline=(30, 35, 64, 255), width=10
    )
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius, fill=255)
    canvas.paste(src, (pad, pad), mask)
    ImageDraw.Draw(canvas).rounded_rectangle((pad, pad, pad + w, pad + h), radius, outline=(30, 35, 64, 255), width=12)
    path = WORK / f"{name}-phone.png"
    canvas.save(path)
    return path


def background(slide, color):
    fill = slide.background.fill
    fill.solid()
    fill.fore_color.rgb = color


def circle(slide, x, y, d, color, outline=False):
    shape = slide.shapes.add_shape(MSO_SHAPE.OVAL, inches(x), inches(y), inches(d), inches(d))
    if outline:
        shape.fill.background()
        shape.line.color.rgb = INK
        shape.line.width = Pt(1.75)
    else:
        shape.fill.solid()
        shape.fill.fore_color.rgb = color
        shape.line.fill.background()
    return shape


def rule(slide, x, y, w):
    line = slide.shapes.add_connector(1, inches(x), inches(y), inches(x + w), inches(y))
    line.line.color.rgb = INK
    line.line.width = Pt(2.25)


def text(slide, x, y, w, h, runs, align=PP_ALIGN.LEFT):
    """runs: list of paragraphs; each paragraph a list of (text, font, size, italic, color)."""
    box = slide.shapes.add_textbox(inches(x), inches(y), inches(w), inches(h))
    frame = box.text_frame
    frame.word_wrap = True
    for index, paragraph in enumerate(runs):
        p = frame.paragraphs[0] if index == 0 else frame.add_paragraph()
        p.alignment = align
        p.space_after = Pt(6)
        for value, font, size, italic, color in paragraph:
            run = p.add_run()
            run.text = value
            run.font.name = font
            run.font.size = Pt(size)
            run.font.italic = italic
            run.font.color.rgb = color
    return box


def caps(value, color=INK, size=12):
    return [(value.upper(), SANS, size, False, color)]


def feature_slide(title_a, title_b, kicker, shot, bullets, bg, accent, ink=INK):
    slide = prs.slides.add_slide(BLANK)
    background(slide, bg)
    circle(slide, 8.2, 0.6, 4.6, accent)
    circle(slide, 8.32, 0.48, 4.6, accent, outline=True)
    rule(slide, 0.7, 6.95, 11.9)

    text(slide, 0.7, 0.55, 6.6, 0.4, [caps(kicker, ink)])
    text(slide, 0.7, 0.9, 6.8, 1.8, [
        [(title_a, SERIF, 46, False, ink)],
        [(title_b, SERIF, 46, True, ink)],
    ])
    rows = []
    for head, body in bullets:
        rows.append([(head + "  ", SANS, 15, False, ink), (body, SANS, 15, False, ink)])
    box = text(slide, 0.7, 3.0, 6.6, 3.8, rows)
    for p in box.text_frame.paragraphs:
        p.runs[0].font.bold = True
        p.space_after = Pt(12)

    image = phone_image(shot)
    height = 6.4
    slide.shapes.add_picture(str(image), inches(8.55), inches(0.45), height=inches(height))
    return slide


# 1. Title
slide = prs.slides.add_slide(BLANK)
background(slide, PAPER)
circle(slide, 7.6, 0.9, 5.2, BUTTER)
circle(slide, 7.72, 0.78, 5.2, BUTTER, outline=True)
slide.shapes.add_picture(str(ICON), inches(8.6), inches(1.9), height=inches(3.2))
text(slide, 0.8, 1.6, 7, 0.4, [caps("A cozy budget for manat")])
text(slide, 0.8, 2.0, 7, 1.6, [[("muna", SERIF, 88, False, INK)]])
text(slide, 0.8, 3.7, 6.4, 1.6, [[("Track what you spend and earn, keep every bill, and watch savings grow. Everything stays on your iPhone.", SANS, 18, False, INK)]])
rule(slide, 0.8, 6.6, 11.7)
text(slide, 0.8, 6.7, 8, 0.4, [caps("How it works · Version 1.0", INK, 11)])

# 2. Home map
feature_slide(
    "Your home", "is a shelf", "1 · Home page", "1-home",
    [
        ("Balance sign", "what is left this month. Tap for Overview."),
        ("Books", "Expenses, Income and Bills open Activity filtered; Loans opens your loans."),
        ("Jar & clock", "the jar fills as you save; the clock opens payment reminders."),
        ("Calendar", "switch month. ‹ › at the top do the same."),
        ("Below the room", "quick add chips and your latest entries."),
    ],
    PAPER, BUTTER,
)

# 3. Adding
feature_slide(
    "Add a spend", "in seconds", "2 · Adding an entry", "2-add",
    [
        ("1", "Tap the big + in the bar, or a quick-add chip on Home."),
        ("2", "Type the amount; pick Income or Expense."),
        ("3", "Pick a category; your recent ones come first."),
        ("4", "Optional: note, paperclip for a bill, Repeat for monthly costs."),
        ("5", "Save, or Save and add another for a stack of receipts."),
    ],
    BLUSH, PAPER,
)

# 4. Bills
feature_slide(
    "Keep every bill", "close at hand", "3 · Bills & attachments", "3-bill",
    [
        ("Paperclip", "attach a photo or a PDF; the number shows how many."),
        ("Tap a tile", "opens the bill full screen: zoom, swipe, share."),
        ("Bookmark", "beside Save marks the entry as a bill for the Bills tab."),
        ("From the list", "swipe an entry right and choose Open bill."),
        ("Safe to undo", "remove a file and press Cancel: it comes back."),
    ],
    SAGE, BUTTER,
)

# 5. Savings and loans
feature_slide(
    "Watch savings", "grow, loans shrink", "4 · Savings & loans", "4-goal",
    [
        ("Goals", "set a target and a date; Add money records each top-up."),
        ("Progress", "saved, still to go and days left at a glance."),
        ("Loans", "record payments; see paid, remaining and instalments left."),
        ("Reminders", "get a notification before a payment is due."),
    ],
    BUTTER, TERRA,
)

# 6. Overview
feature_slide(
    "See where", "it all goes", "5 · Overview", "5-overview",
    [
        ("Donut", "spending by category, with share and amount."),
        ("Income vs expense", "for the month you are viewing."),
        ("Daily spending", "a bar per day to spot the heavy ones."),
        ("Year overview", "every month side by side."),
    ],
    LILAC, PAPER,
)

# 7. Settings
feature_slide(
    "Make it", "your own", "6 · Settings", "6-styles",
    [
        ("Home page", "Classic or one of six illustrated rooms; tap to switch."),
        ("Currency & month start", "AZN, USD or EUR; begin your month on any day 1–28."),
        ("My Categories", "add, hide, reorder or rename your own."),
        ("Backup", "export or restore everything as a file."),
    ],
    PAPER, BLUSH,
)

# 8. Closing
slide = prs.slides.add_slide(BLANK)
background(slide, TERRA)
circle(slide, 9.0, 3.6, 4.4, BUTTER)
circle(slide, 9.12, 3.48, 4.4, BUTTER, outline=True)
text(slide, 0.8, 0.9, 8, 0.4, [caps("Private by design", PAPER)])
text(slide, 0.8, 1.3, 9, 2.0, [
    [("Your money stays", SERIF, 52, False, PAPER)],
    [("on your phone", SERIF, 52, True, PAPER)],
])
text(slide, 0.8, 3.5, 7.6, 2.4, [
    [("No account and no tracking. Entries, bills and reminders live only on this device.", SANS, 18, False, PAPER)],
    [("Bill files are locked while the phone is locked. Export a backup any time from Settings.", SANS, 18, False, PAPER)],
])
slide.shapes.add_picture(str(ICON), inches(10.1), inches(4.5), height=inches(2.2))

prs.save(OUT)
print("saved", OUT, len(prs.slides), "slides")
