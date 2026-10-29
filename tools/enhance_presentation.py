"""يضيف شرائح العرض الحقيقية (لقطة التطبيق + سيناريو الديمو + معايير التحكيم) إلى العرض."""
from __future__ import annotations

from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Emu, Inches, Pt

BASE = Path(__file__).resolve().parent.parent
DECK = BASE / "docs" / "Basira-Presentation.pptx"
SHOT = BASE / "assets" / "images" / "app_screenshot.png"

GREEN = RGBColor(0x0B, 0x6B, 0x3A)
GREEN_DARK = RGBColor(0x06, 0x4A, 0x28)
AMBER = RGBColor(0xF5, 0xA5, 0x24)
INK = RGBColor(0x10, 0x16, 0x13)
MUTED = RGBColor(0x5B, 0x6B, 0x63)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
LIGHT = RGBColor(0xF4, 0xF7, 0xF5)
LINE = RGBColor(0xD8, 0xE2, 0xDC)
FONT = "Segoe UI"

W = Inches(13.333)
H = Inches(7.5)


def rtl(p):
    p._p.get_or_add_pPr().set("rtl", "1")


def text(slide, x, y, w, h, body, size, color=INK, bold=False,
         align=PP_ALIGN.RIGHT, spacing=1.2, anchor=MSO_ANCHOR.TOP):
    box = slide.shapes.add_textbox(x, y, w, h)
    tf = box.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = Emu(0)
    tf.margin_top = tf.margin_bottom = Emu(0)
    for i, line in enumerate(body.split("\n")):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.line_spacing = spacing
        rtl(p)
        r = p.add_run()
        r.text = line
        r.font.size = Pt(size)
        r.font.bold = bold
        r.font.name = FONT
        r.font.color.rgb = color
    return box


def rect(slide, x, y, w, h, color, radius=None, line=None, lw=1):
    shape = MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE
    s = slide.shapes.add_shape(shape, x, y, w, h)
    s.fill.solid()
    s.fill.fore_color.rgb = color
    if line is None:
        s.line.fill.background()
    else:
        s.line.color.rgb = line
        s.line.width = Pt(lw)
    s.shadow.inherit = False
    if radius:
        s.adjustments[0] = radius
    return s


def header(slide, title, kicker=None):
    rect(slide, 0, 0, W, Inches(0.16), GREEN)
    if kicker:
        text(slide, Inches(0.7), Inches(0.45), Inches(12), Inches(0.4), kicker, 14, AMBER, bold=True)
        text(slide, Inches(0.7), Inches(0.8), Inches(12), Inches(0.9), title, 34, INK, bold=True)
    else:
        text(slide, Inches(0.7), Inches(0.55), Inches(12), Inches(0.9), title, 36, INK, bold=True)
    rect(slide, W - Inches(2.3), Inches(1.75), Inches(1.6), Inches(0.06), GREEN)


def main():
    prs = Presentation(str(DECK))

    # ── شريحة اللقطة الحقيقية (تُدرَج بعد شريحة الميزات = index 4) ──
    blank = prs.slide_layouts[6]
    s = prs.slides.add_slide(blank)

    header(s, "التطبيق كما هو الآن", "لقطة حقيقية من النسخة المنشورة")

    # إطار الهاتف
    rect(s, Inches(8.55), Inches(2.05), Inches(4.1), Inches(5.05), GREEN_DARK, radius=0.06)
    if SHOT.exists():
        s.shapes.add_picture(str(SHOT), Inches(8.7), Inches(2.2), width=Inches(3.8))

    bullets = [
        ("زر واحد كبير", "«ابدأ المشي» — لا قوائم ولا خطوات وسيطة"),
        ("حالة مسموعة", "اضغط سطر الحالة ليُقرأ لك: الموقع، الاتصال، البلاغات"),
        ("استغاثة واضحة", "أحمر، ثابت أسفل الشاشة، لا يختفي بالتمرير"),
        ("أوفلاين", "٤ بلاغات معلّقة تنتظر الشبكة — والتنقل يستمر"),
    ]
    y = Inches(2.15)
    for title, body in bullets:
        rect(s, Inches(0.7), y, Inches(0.08), Inches(0.95), AMBER)
        text(s, Inches(3.4), y, Inches(4.9), Inches(0.4), title, 19, INK, bold=True)
        text(s, Inches(1.0), y + Inches(0.42), Inches(7.3), Inches(0.5), body, 14, MUTED)
        y += Inches(1.15)

    text(s, Inches(0.7), Inches(6.95), Inches(7.4), Inches(0.4),
         "التصميم داكن عالي التباين افتراضيًا — أريح للعين وللحالات المختلطة.", 13, GREEN, bold=True)

    # ── شريحة سيناريو الديمو ──
    s2 = prs.slides.add_slide(blank)
    header(s2, "سيناريو العرض الحيّ", "٣ دقائق أمام اللجنة")

    steps = [
        ("٠:٠٠", "أغمضوا أعينكم ٣٠ ثانية", "الإحساس بالمشكلة قبل أي شريحة"),
        ("٠:٣٠", "افتح بصيرة", "«طريقك الآمن بصوتك» — ثم إخلاء المسؤولية بثلاث نقاط"),
        ("٠:٥٠", "«أين أنا؟»", "وصف الموقع وأقرب مبنى وإشارة"),
        ("١:١٠", "«ابدأ المشي»", "إرشاد حقيقي + اهتزاز يمين/يسار — امشِ أمامهم"),
        ("١:٤٠", "أطفئ الواي فاي", "التطبيق يستمر — «أوفلاين»"),
        ("٢:٠٠", "بلّغ عن عائق بصوتك", "يُحفظ محليًا ويُرفع لاحقًا"),
        ("٢:٢٠", "زر الاستغاثة", "عدّ تنازلي ثم إلغاء بنقرة"),
        ("٢:٤٠", "الخاتمة", "استقلالية، لا شرائح"),
    ]
    y = Inches(2.1)
    for i, (t, title, body) in enumerate(steps):
        col = i % 2
        row = i // 2
        x = Inches(6.9) if col == 0 else Inches(0.75)
        yy = y + row * Inches(1.18)
        rect(s2, x, yy, Inches(5.6), Inches(1.0), LIGHT, radius=0.12, line=LINE)
        text(s2, x + Inches(4.75), yy + Inches(0.12), Inches(0.7), Inches(0.35), t, 13, GREEN, bold=True,
             align=PP_ALIGN.LEFT)
        text(s2, x + Inches(0.18), yy + Inches(0.12), Inches(4.45), Inches(0.35), title, 17, INK, bold=True)
        text(s2, x + Inches(0.18), yy + Inches(0.5), Inches(5.2), Inches(0.4), body, 12, MUTED)

    # ── شريحة معايير التحكيم ──
    s3 = prs.slides.add_slide(blank)
    header(s3, "لماذا يفوز هذا المشروع؟", "الابتكار · الأثر · التنفيذ · الاستدامة")

    cards = [
        ("الابتكار", "أول تطبيق عربي صوتي أولًا يجمع: إرشاد + إشارات + بلاغات + SOS + أوفلاين في منتج واحد"),
        ("الأثر", "يستهدف فئة مهمّشة بمشكلة موثّقة، وحل مبني على مقابلات لا على تخمين"),
        ("التنفيذ", "53 ملف Dart · 61 اختبارًا ناجحًا · تحليل بلا أخطاء · يعمل الآن على الويب"),
        ("الاستدامة", "مفتوح المصدر · بلا تكاليف تشغيل · قابل للتوسّع لـ Beacons والذكاء الاصطناعي"),
    ]
    y = Inches(2.15)
    for title, body in cards:
        rect(s3, Inches(0.7), y, Inches(2.4), Inches(0.95), GREEN, radius=0.18)
        text(s3, Inches(0.7), y + Inches(0.24), Inches(2.4), Inches(0.45), title, 19, WHITE, bold=True,
             align=PP_ALIGN.CENTER)
        text(s3, Inches(3.35), y + Inches(0.12), Inches(9.2), Inches(0.75), body, 15, INK, spacing=1.35)
        y += Inches(1.25)

    text(s3, Inches(0.7), Inches(6.9), Inches(12), Inches(0.4),
         "كل رقم مذكور قابل للتحقق من المستودع مباشرة أمام اللجنة.", 13, GREEN, bold=True)

    # ترتيب: الشرائح الجديدة قبل شريحة الختام
    sld = prs.slides._sldIdLst
    ids = list(sld)
    new = ids[-3:]
    closing = ids[-4]
    for el in new:
        sld.remove(el)
    closing_idx = list(sld).index(closing)
    for offset, el in enumerate(new):
        sld.insert(closing_idx + offset, el)

    prs.save(str(DECK))
    print("slides:", len(prs.slides))


if __name__ == "__main__":
    main()
