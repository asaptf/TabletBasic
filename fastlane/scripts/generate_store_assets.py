#!/usr/bin/env python3
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCREENSHOT_SOURCE = ROOT / "simulator-launch.png"
APP_ICON_SOURCE = ROOT / "QuickBasic/Assets.xcassets/AppIcon.appiconset/AppIcon-1024@1x.png"
SVG_ICON_SOURCE = ROOT / "Artwork/TabletBasicIcon.svg"
SCREENSHOT_DIR = ROOT / "fastlane/screenshots/en-US"
ASSET_DIR = ROOT / "fastlane/assets"

BLUE = (0, 0, 168)
BLUE_DARK = (0, 0, 112)
BLUE_STATUS = (0, 0, 130)
CYAN = (119, 255, 225)
WHITE = (246, 250, 255)
MUTED = (187, 205, 255)
YELLOW = (255, 216, 103)
INK = (20, 22, 30)
PANEL = (239, 239, 239)
PANEL_DARK = (40, 47, 66)
GREEN = (87, 245, 200)


def font(size: int, bold: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont:
    candidates = []
    if mono:
        candidates.extend([
            "/System/Library/Fonts/SFNSMono.ttf",
            "/System/Library/Fonts/Supplemental/Courier New Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Courier New.ttf",
        ])
    else:
        candidates.extend([
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        ])
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


TITLE = font(96, bold=True)
SUBTITLE = font(44)
MENU = font(30, mono=True)
MONO = font(34, mono=True)
MONO_SMALL = font(28, mono=True)
MONO_BOLD = font(36, bold=True, mono=True)
CAPTION = font(56, bold=True)
BODY = font(38)
PHONE_TITLE = font(64, bold=True)
PHONE_CAPTION = font(38, bold=True)
PHONE_BODY = font(28)
PHONE_MENU = font(19, mono=True)
PHONE_MONO = font(25, mono=True)
PHONE_MONO_SMALL = font(20, mono=True)
PHONE_MONO_BOLD = font(27, bold=True, mono=True)


def ensure_dirs() -> None:
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for path in SCREENSHOT_DIR.glob("*.png"):
        path.unlink()


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=fnt)
    return int(box[2] - box[0]), int(box[3] - box[1])


def center_text(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], text: str, fnt, fill) -> None:
    width, height = text_size(draw, text, fnt)
    x = box[0] + (box[2] - box[0] - width) // 2
    y = box[1] + (box[3] - box[1] - height) // 2
    draw.text((x, y), text, font=fnt, fill=fill)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        width, _ = text_size(draw, candidate, fnt)
        if width <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_caption(draw: ImageDraw.ImageDraw, title: str, subtitle: str | None = None) -> None:
    draw.rounded_rectangle((96, 142, 1968, 388), radius=26, fill=(0, 0, 112), outline=(98, 175, 255), width=3)
    draw.text((140, 176), title, font=CAPTION, fill=WHITE)
    if subtitle:
        draw.text((142, 254), subtitle, font=BODY, fill=MUTED)


def draw_shell(title: str = "Untitled") -> Image.Image:
    image = Image.new("RGB", (2064, 2752), BLUE)
    draw = ImageDraw.Draw(image)

    draw.rectangle((0, 0, 2064, 58), fill=(0, 0, 170))
    draw.text((24, 18), "09:41  Fri Jul 3", font=MENU, fill=WHITE)
    draw.text((1856, 18), "Wi-Fi  100%", font=MENU, fill=WHITE)

    menus = "File   Edit   View   Search   Run   Debug   Options   Help"
    draw.text((24, 82), menus, font=MENU, fill=WHITE)
    center_text(draw, (0, 118, 2064, 168), title, MENU, WHITE)

    draw.rectangle((0, 2590, 2064, 2642), fill=BLUE_DARK, outline=(82, 91, 226), width=2)
    draw.text((12, 2602), ">", font=MONO, fill=WHITE)
    draw.rectangle((0, 2642, 2064, 2752), fill=BLUE_STATUS)
    draw.text((16, 2674), "F1=Help   Enter=Execute   Esc=Cancel   Tab=Next Field   Arrow=Next Item", font=MENU, fill=WHITE)
    draw.text((1902, 2674), "Immediate", font=MENU, fill=WHITE)
    return image


def screenshot_welcome() -> None:
    source = Image.open(SCREENSHOT_SOURCE).convert("RGB")
    draw = ImageDraw.Draw(source)
    draw_caption(
        draw,
        "Retro BASIC for iPhone & iPad",
        "A fast, focused place to learn programming one line at a time.",
    )
    source.save(SCREENSHOT_DIR / "01_IPAD_PRO_3GEN_129_welcome.png", optimize=True)


def screenshot_editor() -> None:
    image = draw_shell("HELLO.BAS")
    draw = ImageDraw.Draw(image)
    draw_caption(draw, "Write BASIC, instantly", "Type small programs, run them, and see the result right away.")

    code = [
        "10 REM HELLO.BAS - YOUR FIRST PROGRAM",
        "20 PRINT \"HELLO, WORLD!\"",
        "30 PRINT \"WELCOME TO TABLETBASIC\"",
        "40 FOR I% = 1 TO 5",
        "50   PRINT \"LINE\"; I%",
        "60 NEXT I%",
        "70 END",
    ]
    x, y = 150, 520
    for line in code:
        draw.text((x, y), line, font=MONO_BOLD if line.startswith("10") else MONO, fill=WHITE)
        y += 62

    draw.rounded_rectangle((132, 1084, 1932, 1534), radius=12, fill=(0, 0, 132), outline=(126, 175, 255), width=3)
    draw.text((176, 1132), "Program Output", font=MONO_BOLD, fill=YELLOW)
    output = ["HELLO, WORLD!", "WELCOME TO TABLETBASIC", "LINE 1", "LINE 2", "LINE 3", "LINE 4", "LINE 5"]
    y = 1212
    for line in output:
        draw.text((176, y), line, font=MONO, fill=WHITE)
        y += 44

    image.save(SCREENSHOT_DIR / "02_IPAD_PRO_3GEN_129_editor.png", optimize=True)


def screenshot_samples() -> None:
    image = draw_shell("Sample Programs")
    draw = ImageDraw.Draw(image)
    draw_caption(draw, "20 sample programs", "Learn from ready-made examples for text, loops, data, math, and graphics.")

    left = (170, 540, 760, 2050)
    right = (780, 540, 1894, 2050)
    draw.rounded_rectangle(left, radius=8, fill=PANEL, outline=INK, width=4)
    draw.rounded_rectangle(right, radius=8, fill=PANEL, outline=INK, width=4)
    draw.text((210, 588), "Sample Programs", font=SUBTITLE, fill=INK)

    items = [
        ("HELLO.BAS", "Hello World"),
        ("FORLOOP.BAS", "FOR...NEXT Loop"),
        ("DATAREAD.BAS", "DATA & READ"),
        ("DICE.BAS", "Random Numbers"),
        ("SHAPES.BAS", "Basic Shapes"),
        ("MOIRE.BAS", "Moire Pattern"),
    ]
    y = 690
    for i, (name, label) in enumerate(items):
        fill = (0, 0, 168) if i == 4 else PANEL
        text_fill = WHITE if i == 4 else INK
        draw.rectangle((190, y - 18, 740, y + 78), fill=fill)
        draw.text((216, y), name, font=MONO_BOLD, fill=text_fill)
        draw.text((216, y + 38), label, font=MONO_SMALL, fill=text_fill)
        y += 116

    draw.text((830, 588), "SHAPES.BAS", font=SUBTITLE, fill=INK)
    draw.text((832, 656), "SCREEN 13 with CIRCLE and LINE.", font=BODY, fill=(74, 78, 88))
    code = [
        "SCREEN 13",
        "CLS",
        "CIRCLE (160, 100), 60, 4",
        "LINE (100, 160)-(220, 160), 2",
        "LINE (100, 40)-(100, 160), 3",
        "LINE (220, 40)-(220, 160), 3",
        "PRINT \"Shapes drawn!\"",
    ]
    y = 770
    for line in code:
        draw.text((850, y), line, font=MONO, fill=INK)
        y += 58
    draw.rounded_rectangle((850, 1770, 1260, 1870), radius=10, fill=(0, 102, 210))
    center_text(draw, (850, 1770, 1260, 1870), "Load & Run", BODY, WHITE)

    image.save(SCREENSHOT_DIR / "03_IPAD_PRO_3GEN_129_samples.png", optimize=True)


def screenshot_graphics() -> None:
    image = draw_shell("MOIRE.BAS")
    draw = ImageDraw.Draw(image)
    draw_caption(draw, "Classic graphics mode", "Experiment with SCREEN 13 style drawing commands.")

    canvas = (252, 556, 1812, 1530)
    draw.rounded_rectangle(canvas, radius=10, fill=(3, 16, 22), outline=GREEN, width=6)
    cx, cy = 1032, 1038
    colors = [(87, 245, 200), (255, 216, 103), (109, 176, 255), (255, 104, 178)]
    for i, radius in enumerate(range(90, 520, 48)):
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=colors[i % len(colors)], width=8)
    draw.line((320, 1440, 1744, 620), fill=(109, 176, 255), width=8)
    draw.rectangle((380, 690, 650, 960), outline=YELLOW, width=8)

    draw.rounded_rectangle((252, 1596, 1812, 2100), radius=8, fill=(0, 0, 128), outline=(126, 175, 255), width=3)
    draw.text((304, 1644), "BASIC source", font=MONO_BOLD, fill=YELLOW)
    code = [
        "SCREEN 13",
        "CLS",
        "FOR R% = 5 TO 150 STEP 5",
        "  C% = (R% MOD 15) + 1",
        "  CIRCLE (160, 100), R%, C%",
        "NEXT R%",
    ]
    y = 1728
    for line in code:
        draw.text((304, y), line, font=MONO, fill=WHITE)
        y += 52

    image.save(SCREENSHOT_DIR / "04_IPAD_PRO_3GEN_129_graphics.png", optimize=True)


def screenshot_lessons() -> None:
    image = draw_shell("Learning Guide")
    draw = ImageDraw.Draw(image)
    draw_caption(draw, "Built for beginners", "Lessons and hints turn old-school BASIC into a gentle first language.")

    panel = (150, 536, 1914, 2170)
    draw.rounded_rectangle(panel, radius=8, fill=PANEL, outline=INK, width=4)
    draw.rectangle((150, 536, 640, 2170), fill=(245, 245, 247), outline=INK, width=3)
    draw.text((210, 594), "TabletBasic", font=SUBTITLE, fill=INK)
    draw.text((210, 650), "Learning Guide", font=BODY, fill=(74, 78, 88))

    lessons = [
        ("Chapter 1", "Hello, World!"),
        ("Chapter 2", "Variables"),
        ("Chapter 3", "FOR...NEXT Loops"),
        ("Chapter 4", "Simple Graphics"),
        ("Chapter 5", "GOSUB and RETURN"),
    ]
    y = 764
    for i, (chapter, title) in enumerate(lessons):
        fill = (0, 0, 168) if i == 3 else (245, 245, 247)
        text_fill = WHITE if i == 3 else INK
        draw.rectangle((178, y - 18, 612, y + 92), fill=fill)
        draw.text((208, y), chapter, font=MONO_SMALL, fill=text_fill)
        draw.text((208, y + 42), title, font=BODY, fill=text_fill)
        y += 132

    draw.text((710, 620), "Simple Graphics", font=TITLE, fill=INK)
    draw.text((716, 738), "Draw with SCREEN, CIRCLE, LINE", font=SUBTITLE, fill=(74, 78, 88))
    body = "SCREEN 13 sets 320x200 graphics mode. Use CIRCLE and LINE to draw shapes, then run the lesson and change the numbers."
    y = 836
    for line in wrap_text(draw, body, BODY, 1080):
        draw.text((716, y), line, font=BODY, fill=INK)
        y += 50

    code_box = (716, 1052, 1770, 1450)
    draw.rounded_rectangle(code_box, radius=6, fill=(232, 235, 240), outline=(166, 171, 184), width=2)
    code = [
        "SCREEN 13",
        "CLS",
        "CIRCLE (160, 100), 50, 4",
        "LINE (50, 150)-(270, 150), 2",
        "PRINT \"Graphics ready!\"",
    ]
    y = 1100
    for line in code:
        draw.text((756, y), line, font=MONO, fill=INK)
        y += 58

    draw.rounded_rectangle((716, 1530, 1054, 1626), radius=10, fill=(0, 102, 210))
    center_text(draw, (716, 1530, 1054, 1626), "Open in Editor", BODY, WHITE)
    draw.rounded_rectangle((1092, 1530, 1372, 1626), radius=10, fill=(231, 236, 246), outline=(121, 128, 140), width=2)
    center_text(draw, (1092, 1530, 1372, 1626), "Run Lesson", BODY, INK)

    image.save(SCREENSHOT_DIR / "05_IPAD_PRO_3GEN_129_lessons.png", optimize=True)


def draw_phone_caption(draw: ImageDraw.ImageDraw, title: str, subtitle: str | None = None) -> None:
    draw.rounded_rectangle((56, 172, 1264, 398), radius=24, fill=(0, 0, 112), outline=(98, 175, 255), width=3)
    draw.text((92, 202), title, font=PHONE_CAPTION, fill=WHITE)
    if subtitle:
        y = 268
        for line in wrap_text(draw, subtitle, PHONE_BODY, 1120)[:3]:
            draw.text((94, y), line, font=PHONE_BODY, fill=MUTED)
            y += 36


def draw_phone_shell(title: str = "Untitled") -> Image.Image:
    image = Image.new("RGB", (1320, 2868), BLUE)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 1320, 96), fill=(0, 0, 170))
    draw.text((40, 42), "09:41", font=PHONE_MENU, fill=WHITE)
    draw.text((1102, 42), "Wi-Fi  100%", font=PHONE_MENU, fill=WHITE)
    draw.text((36, 116), "File   Run   Help", font=PHONE_MENU, fill=WHITE)
    center_text(draw, (0, 144, 1320, 188), title, PHONE_MENU, WHITE)
    draw.rectangle((0, 2680, 1320, 2738), fill=BLUE_DARK, outline=(82, 91, 226), width=2)
    draw.text((20, 2692), ">", font=PHONE_MONO, fill=WHITE)
    draw.rectangle((0, 2738, 1320, 2868), fill=BLUE_STATUS)
    draw.text((28, 2782), "F1=Help   Enter=Run   Esc=Back", font=PHONE_MENU, fill=WHITE)
    draw.text((1100, 2782), "Immediate", font=PHONE_MENU, fill=WHITE)
    return image


def phone_welcome() -> None:
    image = draw_phone_shell("Untitled")
    draw = ImageDraw.Draw(image)
    draw_phone_caption(
        draw,
        "Retro BASIC on iOS",
        "A friendly coding workspace for iPhone and iPad.",
    )
    dialog = (170, 1150, 1150, 1564)
    draw.rectangle(dialog, fill=PANEL, outline=INK, width=4)
    center_text(draw, (dialog[0], dialog[1] + 44, dialog[2], dialog[1] + 96), "Welcome to", PHONE_MONO, INK)
    center_text(draw, (dialog[0], dialog[1] + 112, dialog[2], dialog[1] + 172), "TabletBasic Version 1.0", PHONE_MONO_BOLD, INK)
    center_text(draw, (dialog[0], dialog[1] + 194, dialog[2], dialog[1] + 254), "Type. Run. Learn.", PHONE_MONO, INK)
    center_text(draw, (dialog[0], dialog[1] + 304, dialog[2], dialog[1] + 362), "< Press Enter to open lessons >", PHONE_MONO_SMALL, INK)
    image.save(SCREENSHOT_DIR / "01_IPHONE_69_welcome.png", optimize=True)


def phone_editor() -> None:
    image = draw_phone_shell("HELLO.BAS")
    draw = ImageDraw.Draw(image)
    draw_phone_caption(draw, "Write BASIC anywhere", "Small programs fit naturally on iPhone.")
    code = [
        "10 REM HELLO.BAS",
        "20 PRINT \"HELLO, WORLD!\"",
        "30 FOR I% = 1 TO 5",
        "40   PRINT \"LINE\"; I%",
        "50 NEXT I%",
        "60 END",
    ]
    x, y = 72, 560
    for line in code:
        draw.text((x, y), line, font=PHONE_MONO_BOLD if line.startswith("10") else PHONE_MONO, fill=WHITE)
        y += 58

    box = (64, 1110, 1256, 1554)
    draw.rounded_rectangle(box, radius=10, fill=(0, 0, 132), outline=(126, 175, 255), width=3)
    draw.text((104, 1164), "Program Output", font=PHONE_MONO_BOLD, fill=YELLOW)
    y = 1232
    for line in ["HELLO, WORLD!", "LINE 1", "LINE 2", "LINE 3", "LINE 4", "LINE 5"]:
        draw.text((104, y), line, font=PHONE_MONO, fill=WHITE)
        y += 45
    image.save(SCREENSHOT_DIR / "02_IPHONE_69_editor.png", optimize=True)


def phone_samples() -> None:
    image = draw_phone_shell("Sample Programs")
    draw = ImageDraw.Draw(image)
    draw_phone_caption(draw, "20 sample programs", "Open examples for loops, math, data, and graphics.")
    panel = (70, 560, 1250, 2100)
    draw.rounded_rectangle(panel, radius=8, fill=PANEL, outline=INK, width=4)
    draw.text((112, 618), "Sample Programs", font=PHONE_TITLE, fill=INK)

    items = [
        ("HELLO.BAS", "Hello World"),
        ("FORLOOP.BAS", "FOR...NEXT Loop"),
        ("DATAREAD.BAS", "DATA & READ"),
        ("DICE.BAS", "Random Numbers"),
        ("SHAPES.BAS", "Basic Shapes"),
    ]
    y = 736
    for i, (name, label) in enumerate(items):
        fill = BLUE if i == 4 else PANEL
        text_fill = WHITE if i == 4 else INK
        draw.rectangle((104, y - 14, 1216, y + 92), fill=fill)
        draw.text((136, y), name, font=PHONE_MONO_BOLD, fill=text_fill)
        draw.text((136, y + 42), label, font=PHONE_MONO_SMALL, fill=text_fill)
        y += 124

    draw.line((104, 1394, 1216, 1394), fill=(190, 194, 205), width=3)
    draw.text((136, 1440), "SHAPES.BAS", font=PHONE_MONO_BOLD, fill=INK)
    code = ["SCREEN 13", "CLS", "CIRCLE (160,100),60,4", "LINE (100,160)-(220,160),2", "PRINT \"Shapes drawn!\""]
    y = 1510
    for line in code:
        draw.text((136, y), line, font=PHONE_MONO, fill=INK)
        y += 50
    draw.rounded_rectangle((136, 1878, 530, 1970), radius=10, fill=(0, 102, 210))
    center_text(draw, (136, 1878, 530, 1970), "Load & Run", PHONE_BODY, WHITE)
    image.save(SCREENSHOT_DIR / "03_IPHONE_69_samples.png", optimize=True)


def phone_graphics() -> None:
    image = draw_phone_shell("MOIRE.BAS")
    draw = ImageDraw.Draw(image)
    draw_phone_caption(draw, "Pocket graphics lab", "Draw with SCREEN, LINE, CIRCLE, PSET, and COLOR.")
    canvas = (92, 560, 1228, 1540)
    draw.rounded_rectangle(canvas, radius=10, fill=(3, 16, 22), outline=GREEN, width=5)
    cx, cy = 660, 1050
    colors = [(87, 245, 200), (255, 216, 103), (109, 176, 255), (255, 104, 178)]
    for i, radius in enumerate(range(74, 430, 44)):
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=colors[i % len(colors)], width=7)
    draw.line((150, 1430, 1170, 660), fill=(109, 176, 255), width=7)
    draw.rectangle((210, 718, 432, 940), outline=YELLOW, width=7)

    box = (92, 1610, 1228, 2140)
    draw.rounded_rectangle(box, radius=8, fill=(0, 0, 128), outline=(126, 175, 255), width=3)
    draw.text((136, 1664), "BASIC source", font=PHONE_MONO_BOLD, fill=YELLOW)
    code = ["SCREEN 13", "CLS", "FOR R% = 5 TO 150 STEP 5", "  CIRCLE (160,100), R%, C%", "NEXT R%"]
    y = 1736
    for line in code:
        draw.text((136, y), line, font=PHONE_MONO, fill=WHITE)
        y += 54
    image.save(SCREENSHOT_DIR / "04_IPHONE_69_graphics.png", optimize=True)


def phone_lessons() -> None:
    image = draw_phone_shell("Learning Guide")
    draw = ImageDraw.Draw(image)
    draw_phone_caption(draw, "Learn step by step", "Lessons keep the classic BASIC workflow approachable.")
    panel = (70, 560, 1250, 2130)
    draw.rounded_rectangle(panel, radius=8, fill=PANEL, outline=INK, width=4)
    draw.text((112, 626), "Simple Graphics", font=PHONE_TITLE, fill=INK)
    draw.text((116, 708), "Draw with SCREEN, CIRCLE, LINE", font=PHONE_BODY, fill=(74, 78, 88))
    body = "SCREEN 13 sets 320x200 graphics mode. Change the numbers, run again, and see what moves."
    y = 800
    for line in wrap_text(draw, body, PHONE_BODY, 1060):
        draw.text((116, y), line, font=PHONE_BODY, fill=INK)
        y += 40

    code_box = (116, 1030, 1204, 1390)
    draw.rounded_rectangle(code_box, radius=6, fill=(232, 235, 240), outline=(166, 171, 184), width=2)
    code = ["SCREEN 13", "CLS", "CIRCLE (160, 100), 50, 4", "LINE (50, 150)-(270, 150), 2", "PRINT \"Graphics ready!\""]
    y = 1078
    for line in code:
        draw.text((152, y), line, font=PHONE_MONO, fill=INK)
        y += 54

    draw.rounded_rectangle((116, 1490, 536, 1586), radius=10, fill=(0, 102, 210))
    center_text(draw, (116, 1490, 536, 1586), "Open in Editor", PHONE_BODY, WHITE)
    draw.rounded_rectangle((572, 1490, 906, 1586), radius=10, fill=(231, 236, 246), outline=(121, 128, 140), width=2)
    center_text(draw, (572, 1490, 906, 1586), "Run Lesson", PHONE_BODY, INK)
    image.save(SCREENSHOT_DIR / "05_IPHONE_69_lessons.png", optimize=True)


def copy_assets() -> None:
    icon = Image.open(APP_ICON_SOURCE).convert("RGB")
    icon.save(ASSET_DIR / "app-icon-1024.png", optimize=True)
    if SVG_ICON_SOURCE.exists():
        shutil.copyfile(SVG_ICON_SOURCE, ASSET_DIR / "tabletbasic-icon.svg")


def main() -> None:
    ensure_dirs()
    screenshot_welcome()
    screenshot_editor()
    screenshot_samples()
    screenshot_graphics()
    screenshot_lessons()
    phone_welcome()
    phone_editor()
    phone_samples()
    phone_graphics()
    phone_lessons()
    copy_assets()
    print(f"Wrote screenshots to {SCREENSHOT_DIR}")
    print(f"Wrote marketing assets to {ASSET_DIR}")


if __name__ == "__main__":
    main()
