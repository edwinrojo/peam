"""Draw concept.png and wireframe.png for the PEAM-Registry paper.

Run from the overleaf folder:  python3 tools/make_figures.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = Path("/System/Library/Fonts/Supplemental")

BRAND = (123, 97, 255)
BRAND_SOFT = (237, 233, 255)
MINT = (47, 158, 122)
MINT_SOFT = (222, 244, 236)
SKY = (59, 130, 246)
SKY_SOFT = (224, 236, 254)
PEACH = (249, 115, 22)
PEACH_SOFT = (255, 228, 214)
INK = (17, 17, 17)
MUTED = (90, 90, 100)
LINE = (190, 190, 200)
WHITE = (255, 255, 255)


def font(size, bold=False):
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    return ImageFont.truetype(str(FONT_DIR / name), size)


def wrap(draw, text, fnt, width):
    lines = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        line = ""
        for word in words:
            trial = f"{line} {word}".strip()
            if draw.textlength(trial, font=fnt) <= width:
                line = trial
            else:
                if line:
                    lines.append(line)
                line = word
        lines.append(line)
    return lines


def text_block(draw, xy, text, fnt, width, fill=INK, spacing=8):
    x, y = xy
    for line in wrap(draw, text, fnt, width):
        draw.text((x, y), line, font=fnt, fill=fill)
        y += fnt.size + spacing
    return y


def arrow(draw, start, end, fill=MUTED, width=6, head=22):
    draw.line([start, end], fill=fill, width=width)
    (x1, y1), (x2, y2) = start, end
    if x1 == x2:
        sign = 1 if y2 > y1 else -1
        draw.polygon(
            [(x2, y2), (x2 - head * 0.6, y2 - sign * head), (x2 + head * 0.6, y2 - sign * head)],
            fill=fill,
        )
    else:
        sign = 1 if x2 > x1 else -1
        draw.polygon(
            [(x2, y2), (x2 - sign * head, y2 - head * 0.6), (x2 - sign * head, y2 + head * 0.6)],
            fill=fill,
        )


# --------------------------------------------------------------------------
# Conceptual framework (Input - Process - Output)
# --------------------------------------------------------------------------


def concept():
    w, h = 1500, 2400
    img = Image.new("RGB", (w, h), WHITE)
    d = ImageDraw.Draw(img)

    band_x = 40
    label_w = 70
    body_x = band_x + label_w + 20
    body_w = w - body_x - 150

    bands = [
        (
            "INPUT",
            BRAND,
            BRAND_SOFT,
            [
                ("HR event setup", "Schedule, venue pin, event-area radius, requires check-out"),
                ("Employee record", "Employee ID and work email created by PHRMO"),
                ("Phone signals", "GPS location, device ID, on-device biometric result"),
                ("Connectivity", "Online or offline state of the phone"),
            ],
        ),
        (
            "PROCESS",
            SKY,
            SKY_SOFT,
            [
                ("1  Sign in", "Email one-time code, then bind one phone"),
                ("2  Event-area check", "Distance to venue within radius, inside event time"),
                ("3  Confirm it is you", "Fingerprint or face unlock on the phone"),
                ("4  Record and sync", "Save on phone (SQLite), upload to Supabase when online"),
                ("5  Notify", "FCM and local reminders, including open check-outs"),
            ],
        ),
        (
            "OUTPUT",
            MINT,
            MINT_SOFT,
            [
                ("Attendance record", "One row per employee per event: Present or Incomplete"),
                ("Status on the phone", "Pending (saved on phone) then Synced (sent to PHRMO)"),
                ("HR web dashboard", "Review, filters, reports, device-change decisions"),
            ],
        ),
    ]

    title_f = font(34, bold=True)
    body_f = font(29)
    label_f = font(38, bold=True)

    y = 40
    centers = []
    tops = []
    for name, strong, soft, items in bands:
        cols = 2
        col_gap = 24
        col_w = (body_w - 40 - col_gap) // cols
        rows = (len(items) + cols - 1) // cols
        card_h = 170
        row_gap = 22
        band_h = 40 + rows * card_h + (rows - 1) * row_gap
        d.rounded_rectangle(
            [band_x, y, band_x + label_w, y + band_h], radius=18, fill=strong
        )
        label_img = Image.new("RGBA", (band_h, label_w), (0, 0, 0, 0))
        ld = ImageDraw.Draw(label_img)
        tw = ld.textlength(name, font=label_f)
        ld.text(((band_h - tw) / 2, (label_w - 38) / 2 - 4), name, font=label_f, fill=WHITE)
        label_img = label_img.rotate(90, expand=True)
        img.paste(label_img, (band_x, y), label_img)

        d.rounded_rectangle(
            [body_x, y, body_x + body_w, y + band_h], radius=22, fill=soft
        )
        for i, (head, detail) in enumerate(items):
            r, c = divmod(i, cols)
            cx = body_x + 20 + c * (col_w + col_gap)
            cy = y + 20 + r * (card_h + row_gap)
            if len(items) % 2 == 1 and i == len(items) - 1:
                cx = body_x + 20
                cw = body_w - 40
            else:
                cw = col_w
            d.rounded_rectangle(
                [cx, cy, cx + cw, cy + card_h], radius=16, fill=WHITE, outline=strong, width=3
            )
            d.text((cx + 22, cy + 18), head, font=title_f, fill=strong)
            text_block(d, (cx + 22, cy + 66), detail, body_f, cw - 44, fill=INK, spacing=6)
        tops.append((y, y + band_h))
        centers.append(body_x + body_w // 2)
        y += band_h + 70

    for (top_a, bottom_a), (top_b, _) in zip(tops, tops[1:]):
        cx = body_x + body_w // 2
        arrow(d, (cx, bottom_a + 8), (cx, top_b - 8), fill=INK, width=7, head=26)

    fx = body_x + body_w + 60
    out_mid = (tops[2][0] + tops[2][1]) // 2
    in_mid = (tops[0][0] + tops[0][1]) // 2
    d.line([(body_x + body_w + 8, out_mid), (fx, out_mid)], fill=PEACH, width=7)
    d.line([(fx, out_mid), (fx, in_mid)], fill=PEACH, width=7)
    arrow(d, (fx, in_mid), (body_x + body_w + 10, in_mid), fill=PEACH, width=7, head=26)
    fb = Image.new("RGBA", (out_mid - in_mid, 60), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fb)
    msg = "Feedback: HR reviews and updates events"
    small = font(28, bold=True)
    fd.text(((fb.width - fd.textlength(msg, font=small)) / 2, 14), msg, font=small, fill=PEACH)
    fb = fb.rotate(90, expand=True)
    img.paste(fb, (fx + 8, in_mid), fb)

    ty = y - 20
    d.rounded_rectangle([band_x, ty, w - 40, ty + 170], radius=18, fill=(245, 245, 248), outline=LINE, width=2)
    d.text((band_x + 26, ty + 18), "Technologies", font=title_f, fill=INK)
    text_block(
        d,
        (band_x + 26, ty + 64),
        "Flutter  ·  Supabase Auth, PostgreSQL, RLS, Edge Functions  ·  Google Maps SDK  ·  Firebase Cloud Messaging  ·  Vue.js admin web",
        font(27),
        w - band_x - 120,
        fill=MUTED,
    )
    img = img.crop((0, 0, w, ty + 200))
    img.save(ROOT / "concept.png", dpi=(300, 300))


# --------------------------------------------------------------------------
# Low-fidelity wireframes of the eight employee screens
# --------------------------------------------------------------------------

PW, PH = 520, 1040
GRAY = (232, 232, 236)
DARK = (60, 60, 66)


class Phone:
    def __init__(self, draw, x, y):
        self.d = draw
        self.x = x
        self.y = y
        self.left = x + 30
        self.right = x + PW - 30
        self.cursor = y + 90
        draw.rounded_rectangle([x, y, x + PW, y + PH], radius=56, fill=WHITE, outline=DARK, width=6)
        draw.rounded_rectangle([x + PW / 2 - 70, y + 18, x + PW / 2 + 70, y + 40], radius=11, fill=DARK)
        draw.text((x + 40, y + 46), "9:41", font=font(20, bold=True), fill=DARK)

    def gap(self, amount):
        self.cursor += amount

    def title(self, text, back=False):
        x = self.left
        if back:
            self.d.text((x, self.cursor), "<", font=font(34, bold=True), fill=DARK)
            x += 34
        self.d.text((x, self.cursor), text, font=font(32, bold=True), fill=INK)
        self.cursor += 54

    def text(self, value, size=22, fill=MUTED, bold=False):
        self.cursor = text_block(
            self.d, (self.left, self.cursor), value, font(size, bold), self.right - self.left, fill=fill, spacing=6
        )
        self.cursor += 8

    def field(self, label):
        self.d.text((self.left, self.cursor), label, font=font(20, bold=True), fill=DARK)
        self.cursor += 28
        self.d.rounded_rectangle(
            [self.left, self.cursor, self.right, self.cursor + 58], radius=14, outline=LINE, width=3, fill=WHITE
        )
        self.cursor += 76

    def button(self, label, fill=INK, color=WHITE, outline=None):
        self.d.rounded_rectangle(
            [self.left, self.cursor, self.right, self.cursor + 66],
            radius=33,
            fill=fill,
            outline=outline,
            width=3 if outline else 0,
        )
        f = font(23, bold=True)
        tw = self.d.textlength(label, font=f)
        self.d.text(((self.left + self.right - tw) / 2, self.cursor + 19), label, font=f, fill=color)
        self.cursor += 84

    def card(self, height, fill=GRAY, outline=None):
        top = self.cursor
        self.d.rounded_rectangle(
            [self.left, top, self.right, top + height], radius=20, fill=fill, outline=outline, width=3 if outline else 0
        )
        self.cursor += height + 16
        return top

    def chip_row(self, labels, active=0):
        x = self.left
        f = font(19, bold=True)
        for i, label in enumerate(labels):
            tw = self.d.textlength(label, font=f)
            fill = INK if i == active else GRAY
            color = WHITE if i == active else DARK
            self.d.rounded_rectangle([x, self.cursor, x + tw + 30, self.cursor + 42], radius=21, fill=fill)
            self.d.text((x + 15, self.cursor + 10), label, font=f, fill=color)
            x += tw + 42
        self.cursor += 60

    def placeholder(self, height, label):
        top = self.cursor
        self.d.rectangle([self.left, top, self.right, top + height], outline=LINE, width=3, fill=(246, 246, 248))
        self.d.line([self.left, top, self.right, top + height], fill=LINE, width=2)
        self.d.line([self.left, top + height, self.right, top], fill=LINE, width=2)
        f = font(22, bold=True)
        tw = self.d.textlength(label, font=f)
        self.d.rounded_rectangle(
            [self.left + 12, top + 12, self.left + tw + 36, top + 52], radius=10, fill=WHITE
        )
        self.d.text((self.left + 24, top + 19), label, font=f, fill=DARK)
        self.cursor += height + 18
        return top

    def nav(self, active):
        y = self.y + PH - 96
        self.d.line([self.x + 20, y, self.x + PW - 20, y], fill=LINE, width=2)
        labels = ["Home", "History", "Profile"]
        f = font(19, bold=True)
        slot = (PW - 60) / 3
        for i, label in enumerate(labels):
            cx = self.x + 30 + slot * i + slot / 2
            color = BRAND if i == active else MUTED
            self.d.ellipse([cx - 14, y + 16, cx + 14, y + 44], outline=color, width=4)
            tw = self.d.textlength(label, font=f)
            self.d.text((cx - tw / 2, y + 50), label, font=f, fill=color)


def wireframe():
    cols, rows = 4, 2
    gap_x, gap_y = 120, 200
    margin = 60
    label_h = 90
    w = margin * 2 + cols * PW + (cols - 1) * gap_x
    h = margin * 2 + rows * (PH + label_h) + (rows - 1) * gap_y
    img = Image.new("RGB", (w, h), WHITE)
    d = ImageDraw.Draw(img)

    def slot(i):
        r, c = divmod(i, cols)
        return margin + c * (PW + gap_x), margin + label_h + r * (PH + label_h + gap_y)

    captions = [
        "1  Sign in",
        "2  Select event",
        "3  Check in",
        "4  Authenticate",
        "5  Confirmation",
        "6  History",
        "7  Notifications",
        "8  Profile",
    ]
    for i, cap in enumerate(captions):
        x, y = slot(i)
        color = BRAND if i < 5 else MUTED
        d.text((x + 8, y - 70), cap, font=font(40, bold=True), fill=color)

    # 1 Sign in
    p = Phone(d, *slot(0))
    p.gap(40)
    d.rounded_rectangle([p.left, p.cursor, p.left + 96, p.cursor + 96], radius=24, fill=BRAND_SOFT, outline=BRAND, width=3)
    d.text((p.left + 20, p.cursor + 30), "Logo", font=font(22, bold=True), fill=BRAND)
    p.gap(120)
    p.title("Sign in")
    p.text("Enter your Employee ID. PEAM sends a code to the work email PHRMO has for you.")
    p.gap(6)
    p.field("Employee ID")
    p.button("Send email code")
    p.text("Check your email  ·  e•••@davaodelsur.gov.ph", size=20)
    p.field("Email verification code")
    p.button("Verify and register this phone")
    p.text("Ask PHRMO to use this phone", size=20, fill=BRAND, bold=True)

    # 2 Select event
    p = Phone(d, *slot(1))
    d.rounded_rectangle([p.left, p.cursor, p.right, p.cursor + 58], radius=29, outline=LINE, width=3)
    d.text((p.left + 24, p.cursor + 17), "Search events or venues", font=font(21), fill=MUTED)
    p.gap(78)
    p.title("Attendance Made Simple")
    p.chip_row(["All", "Ongoing", "Upcoming", "Done"])
    for i, (name, status) in enumerate(
        [("Employees Assembly", "Ongoing"), ("Health Outreach", "Upcoming"), ("Disaster Drill", "Upcoming")]
    ):
        top = p.card(i == 0 and 210 or 160, fill=WHITE, outline=LINE)
        d.text((p.left + 22, top + 20), name, font=font(25, bold=True), fill=INK)
        d.text((p.left + 22, top + 58), "Date · time · venue", font=font(20), fill=MUTED)
        chip = MINT_SOFT if status == "Ongoing" else SKY_SOFT
        d.rounded_rectangle([p.left + 22, top + 96, p.left + 160, top + 132], radius=18, fill=chip)
        d.text((p.left + 36, top + 104), status, font=font(19, bold=True), fill=MINT if status == "Ongoing" else SKY)
        if i == 0:
            d.rounded_rectangle([p.left + 22, top + 146, p.right - 22, top + 192], radius=14, fill=PEACH_SOFT)
            d.text((p.left + 38, top + 157), "Check-out required", font=font(19, bold=True), fill=PEACH)
    p.nav(0)

    # 3 Check in
    p = Phone(d, *slot(2))
    p.title("Check in", back=True)
    top = p.placeholder(330, "Map")
    cx, cy = (p.left + p.right) / 2, top + 165
    d.ellipse([cx - 120, cy - 120, cx + 120, cy + 120], outline=BRAND, width=4)
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=BRAND)
    d.rounded_rectangle([p.left + 10, top + 280, p.right - 10, top + 320], radius=20, fill=MINT_SOFT)
    d.text((p.left + 26, top + 288), "Inside the event area · within 120 m", font=font(18, bold=True), fill=MINT)
    p.text("Employees Assembly", size=26, fill=INK, bold=True)
    p.text("Event area: within 120 m of the venue", size=21)
    p.text("You are 35 m from the venue", size=21)
    top = p.card(80, fill=PEACH_SOFT)
    d.text((p.left + 20, top + 24), "This event needs a check-out", font=font(20, bold=True), fill=PEACH)
    p.button("Check location again", fill=WHITE, color=INK, outline=INK)
    p.button("Check in")

    # 4 Authenticate
    p = Phone(d, *slot(3))
    p.title("Confirm it is you", back=True)
    p.chip_row(["Fingerprint", "Face"])
    p.gap(30)
    cx = (p.left + p.right) / 2
    d.ellipse([cx - 120, p.cursor, cx + 120, p.cursor + 240], outline=BRAND, width=6, fill=BRAND_SOFT)
    for r in (40, 70, 100):
        d.arc([cx - r, p.cursor + 120 - r, cx + r, p.cursor + 120 + r], 200, 340, fill=BRAND, width=5)
        d.arc([cx - r, p.cursor + 120 - r, cx + r, p.cursor + 120 + r], 20, 160, fill=BRAND, width=5)
    p.gap(270)
    p.text("Place your finger on the sensor.", size=22, fill=INK, bold=True)
    p.text("Your phone checks the fingerprint or face. PEAM never stores it.", size=21)
    p.gap(80)
    p.button("Confirm with fingerprint")

    # 5 Confirmation
    p = Phone(d, *slot(4))
    p.gap(40)
    cx = (p.left + p.right) / 2
    d.ellipse([cx - 80, p.cursor, cx + 80, p.cursor + 160], fill=MINT_SOFT, outline=MINT, width=5)
    d.line([cx - 40, p.cursor + 84, cx - 10, p.cursor + 112, cx + 44, p.cursor + 52], fill=MINT, width=10)
    p.gap(190)
    p.title("Attendance confirmed")
    p.text("Your attendance has been recorded.")
    top = p.card(420, fill=WHITE, outline=LINE)
    rows_ = ["Employee", "Event", "Venue", "Check-in", "Status"]
    for i, label in enumerate(rows_):
        yy = top + 22 + i * 78
        d.text((p.left + 22, yy), label, font=font(19, bold=True), fill=MUTED)
        d.rounded_rectangle([p.left + 22, yy + 30, p.right - 60 - i * 20, yy + 50], radius=8, fill=GRAY)
    p.button("Back to events")

    # 6 History
    p = Phone(d, *slot(5))
    p.title("Attendance history")
    top = p.card(150, fill=BRAND_SOFT)
    text_block(
        d,
        (p.left + 20, top + 16),
        "Pending: saved on this phone.  Synced: sent to PHRMO.",
        font(20, bold=True),
        p.right - p.left - 40,
        fill=BRAND,
    )
    d.rounded_rectangle([p.left + 20, top + 92, p.left + 170, top + 134], radius=21, fill=INK)
    d.text((p.left + 46, top + 101), "Send now", font=font(19, bold=True), fill=WHITE)
    for i, (name, chip, color, soft) in enumerate(
        [
            ("Employees Assembly", "Pending", PEACH, PEACH_SOFT),
            ("Health Outreach", "Synced", MINT, MINT_SOFT),
            ("Planning Briefing", "Synced", MINT, MINT_SOFT),
        ]
    ):
        top = p.card(140, fill=WHITE, outline=LINE)
        d.text((p.left + 22, top + 20), name, font=font(23, bold=True), fill=INK)
        d.text((p.left + 22, top + 56), "Check-in · check-out times", font=font(19), fill=MUTED)
        d.rounded_rectangle([p.left + 22, top + 90, p.left + 150, top + 124], radius=17, fill=soft)
        d.text((p.left + 38, top + 97), chip, font=font(18, bold=True), fill=color)
    p.nav(1)

    # 7 Notifications
    p = Phone(d, *slot(6))
    p.title("Notifications", back=True)
    p.text("Mark all read", size=20, fill=BRAND, bold=True)
    for title, body, color, soft in [
        ("Check-out still needed", "Check out before the event ends.", PEACH, PEACH_SOFT),
        ("New event published", "Assembly · Capitol Grounds", BRAND, BRAND_SOFT),
        ("Event reminder", "Starts in 30 minutes.", SKY, SKY_SOFT),
        ("Device-change update", "PHRMO reviewed your request.", MINT, MINT_SOFT),
    ]:
        top = p.card(150, fill=WHITE, outline=LINE)
        d.ellipse([p.left + 20, top + 30, p.left + 80, top + 90], fill=soft, outline=color, width=3)
        text_block(d, (p.left + 100, top + 22), title, font(22, bold=True), p.right - p.left - 120, fill=INK)
        text_block(d, (p.left + 100, top + 84), body, font(19), p.right - p.left - 120, fill=MUTED)

    # 8 Profile
    p = Phone(d, *slot(7))
    p.title("Profile")
    cx = (p.left + p.right) / 2
    d.ellipse([cx - 60, p.cursor, cx + 60, p.cursor + 120], fill=GRAY, outline=LINE, width=3)
    p.gap(140)
    for label in ["Employee ID", "Office", "Work email", "Mobile", "Registered phone", "Registration"]:
        d.text((p.left, p.cursor), label, font=font(19, bold=True), fill=MUTED)
        d.rounded_rectangle([p.left, p.cursor + 30, p.right - 80, p.cursor + 50], radius=8, fill=GRAY)
        p.gap(74)
    p.gap(10)
    p.button("Sign out", fill=WHITE, color=INK, outline=INK)
    p.nav(2)

    flow = [(0, 1), (1, 2), (2, 3)]
    for a, b in flow:
        ax, ay = slot(a)
        bx, _ = slot(b)
        arrow(d, (ax + PW + 14, ay + PH / 2), (bx - 14, ay + PH / 2), fill=BRAND, width=8, head=30)
    x3, y3 = slot(3)
    x4, y4 = slot(4)
    mid = y3 + PH + (y4 - label_h - (y3 + PH)) / 2
    d.line([(x3 + PW / 2, y3 + PH + 12), (x3 + PW / 2, mid)], fill=BRAND, width=8)
    d.line([(x3 + PW / 2, mid), (x4 + PW / 2, mid)], fill=BRAND, width=8)
    arrow(d, (x4 + PW / 2, mid), (x4 + PW / 2, y4 - label_h - 6), fill=BRAND, width=8, head=30)

    img.save(ROOT / "wireframe.png", dpi=(300, 300))


if __name__ == "__main__":
    concept()
    wireframe()
