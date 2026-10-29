"""يولّد عرض تقديمي احترافي (PPTX) لمشروع بصيرة بالعربية RTL."""
from __future__ import annotations

import os
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Emu, Inches, Pt

# ── الهوية البصرية ────────────────────────────────────────────
GREEN = RGBColor(0x0B, 0x6B, 0x3A)
GREEN_DARK = RGBColor(0x06, 0x4A, 0x28)
AMBER = RGBColor(0xF5, 0xA5, 0x24)
INK = RGBColor(0x10, 0x16, 0x13)
MUTED = RGBColor(0x5B, 0x6B, 0x63)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
LIGHT = RGBColor(0xF4, 0xF7, 0xF5)
LINE = RGBColor(0xD8, 0xE2, 0xDC)

FONT = "Segoe UI"
W, H = Inches(13.333), Inches(7.5)

BASE = Path(__file__).resolve().parent.parent
ICON = BASE / "assets" / "images" / "app_icon.png"
OUT = BASE / "docs" / "Basira-Presentation.pptx"


def rtl(paragraph) -> None:
    """يجعل الفقرة عربية RTL."""
    ppr = paragraph._p.get_or_add_pPr()
    ppr.set("rtl", "1")


def textbox(slide, x, y, w, h, text, size, color=INK, bold=False,
            align=PP_ALIGN.RIGHT, line_spacing=1.15, anchor=MSO_ANCHOR.TOP):
    box = slide.shapes.add_textbox(x, y, w, h)
    tf = box.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = Emu(0)
    tf.margin_top = tf.margin_bottom = Emu(0)
    lines = text.split("\n")
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.line_spacing = line_spacing
        rtl(p)
        run = p.add_run()
        run.text = line
        run.font.size = Pt(size)
        run.font.bold = bold
        run.font.name = FONT
        run.font.color.rgb = color
    return box


def rect(slide, x, y, w, h, color, radius=None, line=None, line_width=1):
    shape_type = MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE
    shp = slide.shapes.add_shape(shape_type, x, y, w, h)
    shp.fill.solid()
    shp.fill.fore_color.rgb = color
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line
        shp.line.width = Pt(line_width)
    shp.shadow.inherit = False
    if radius:
        shp.adjustments[0] = radius
    shp.text_frame.text = ""
    return shp


def header(slide, title: str, kicker: str | None = None) -> None:
    rect(slide, 0, 0, W, Inches(0.16), GREEN)
    if kicker:
        textbox(slide, Inches(0.7), Inches(0.45), Inches(12), Inches(0.4),
                kicker, 14, AMBER, bold=True)
        textbox(slide, Inches(0.7), Inches(0.8), Inches(12), Inches(0.9),
                title, 34, INK, bold=True)
    else:
        textbox(slide, Inches(0.7), Inches(0.55), Inches(12), Inches(0.9),
                title, 36, INK, bold=True)
    rect(slide, W - Inches(2.3), Inches(1.75), Inches(1.6), Inches(0.06), GREEN)


def blank(prs):
    return prs.slides.add_slide(prs.slide_layouts[6])


def title_slide(prs):
    s = blank(prs)
    rect(s, 0, 0, W, H, GREEN_DARK)
    rect(s, 0, 0, W, Inches(0.22), AMBER)
    if ICON.exists():
        s.shapes.add_picture(str(ICON), Inches(11.1), Inches(0.75), height=Inches(1.35))
    textbox(s, Inches(0.9), Inches(1.7), Inches(9.5), Inches(0.5),
            "تطبيق تنقّل صوتي لذوي الإعاقة البصرية", 20, RGBColor(0xCF, 0xE9, 0xD9))
    textbox(s, Inches(0.9), Inches(2.2), Inches(9.5), Inches(1.5),
            "بصيرة", 84, WHITE, bold=True)
    textbox(s, Inches(0.9), Inches(3.75), Inches(9.5), Inches(0.7),
            "طريقك الآمن.. بصوتك", 30, AMBER, bold=True)
    textbox(s, Inches(0.9), Inches(4.75), Inches(10.5), Inches(1.2),
            "إرشاد صوتي لحظي · مسارات آمنة · تنبيه إشارات المرور · خرائط جامعات · زر استغاثة\n"
            "يعمل بالكامل بدون إنترنت", 18, RGBColor(0xE8, 0xF5, 0xEE), line_spacing=1.4)
    textbox(s, Inches(0.9), Inches(6.45), Inches(11.5), Inches(0.5),
            "github.com/mo3bdo23/basira   ·   MIT License   ·   Flutter", 15,
            RGBColor(0xA5, 0xC9, 0xB4))


def problem_slide(prs):
    s = blank(prs)
    header(s, "المشكلة", "لماذا نبني بصيرة؟")
    items = [
        ("غياب الإرشاد الصوتي", "المكفوف يعتمد على سؤال المارة أو على مرافق دائم للتنقل."),
        ("مسارات غير آمنة", "أرصفة مكسورة، حفر، وأعمال بناء بلا توثيق أو تحذير مسبق."),
        ("إشارات بلا صوت", "عبور الطرق يعتمد على التخمين أو على مساعدة الآخرين."),
    ]
    y = Inches(2.15)
    for i, (title, body) in enumerate(items, start=1):
        rect(s, Inches(0.7), y, Inches(7.6), Inches(1.15), LIGHT, radius=0.12, line=LINE)
        rect(s, Inches(7.6), y, Inches(0.09), Inches(1.15), AMBER)
        textbox(s, Inches(7.85), y + Inches(0.12), Inches(0.5), Inches(0.5),
                f"{i}", 26, GREEN, bold=True, align=PP_ALIGN.LEFT)
        textbox(s, Inches(2.0), y + Inches(0.12), Inches(5.4), Inches(0.4),
                title, 21, INK, bold=True)
        textbox(s, Inches(1.0), y + Inches(0.58), Inches(6.4), Inches(0.45),
                body, 15, MUTED)
        y += Inches(1.35)

    rect(s, Inches(8.6), Inches(2.15), Inches(4.0), Inches(4.05), GREEN, radius=0.08)
    textbox(s, Inches(8.9), Inches(2.45), Inches(3.4), Inches(0.5),
            "النتيجة", 22, AMBER, bold=True)
    textbox(s, Inches(8.9), Inches(3.05), Inches(3.4), Inches(2.6),
            "فقدان الاستقلالية\n\nتقليل الحضور\n\nقلق دائم للطالب وأسرته", 20, WHITE,
            line_spacing=1.5)
    textbox(s, Inches(0.7), Inches(6.45), Inches(12), Inches(0.4),
            "الحل يجب أن يكون صوتيًا بالكامل، ويعمل بلا إنترنت، ومصمّمًا لمصر.", 16, GREEN, bold=True)


def solution_slide(prs):
    s = blank(prs)
    header(s, "الحل", "عصا بيضاء رقمية")
    textbox(s, Inches(0.7), Inches(2.05), Inches(12), Inches(0.8),
            "تطبيق يسمعك، يرشدك خطوة بخطوة، يحذّرك من الإشارات والعوائق،\n"
            "ويطلب المساعدة عنك — بدون لمس الشاشة وبدون إنترنت.", 20, MUTED, line_spacing=1.4)

    steps = ["Splash", "إخلاء المسؤولية", "تدريب صوتي", "الرئيسية", "تنقّل · بلاغ · خريطة · SOS"]
    x = Inches(0.7)
    widths = [1.55, 2.2, 1.95, 1.6, 3.4]
    for i, (label, w) in enumerate(zip(steps, widths)):
        color = GREEN if i < 4 else GREEN_DARK
        rect(s, x, Inches(3.35), Inches(w), Inches(1.05), color, radius=0.15)
        textbox(s, x + Inches(0.08), Inches(3.62), Inches(w - 0.16), Inches(0.6),
                label, 14, WHITE, bold=True, align=PP_ALIGN.CENTER)
        if i < len(steps) - 1:
            textbox(s, x + Inches(w) + Inches(0.03), Inches(3.6), Inches(0.35), Inches(0.5),
                    "←", 20, MUTED, align=PP_ALIGN.CENTER)
        x += Inches(w) + (Inches(0.38) if i < len(steps) - 1 else 0)

    textbox(s, Inches(0.7), Inches(4.95), Inches(12), Inches(1.4),
            "سبع شاشات، كلها مصمّمة لتُستخدم بالسمع فقط:\n"
            "كل شاشة تُعلن نفسها، وكل إجراء له تأكيد منطوق، ولكل أمر صوتي زر بديل.", 17, INK,
            line_spacing=1.5)


def features_slide(prs):
    s = blank(prs)
    header(s, "الميزات الأساسية", "ما الذي يجعله مختلفًا؟")
    cards = [
        ("🧭", "إرشاد صوتي لحظي", "تعليمات قبل كل انعطاف + كشف الخروج عن المسار"),
        ("🗺️", "مسارات آمنة", "موثّقة بدرجة أمان، محفوظة وتعمل أوفلاين"),
        ("🚦", "تنبيه الإشارات", "حالة الضوء والثواني المتبقية قبل الوصول"),
        ("📢", "بلاغات مجتمعية", "وصف صوتي للعائق + مزامنة تلقائية لاحقًا"),
        ("🏛️", "خرائط جامعات", "خريطة متجهية + دليل صوتي لكل مبنى"),
        ("🆘", "زر استغاثة", "عدّ تنازلي قابل للإلغاء + إرسال الموقع برسالة"),
    ]
    x0, y0 = Inches(0.7), Inches(2.15)
    cw, ch, gap = Inches(3.95), Inches(1.85), Inches(0.25)
    for i, (emoji, title, body) in enumerate(cards):
        col, row = i % 3, i // 3
        x = x0 + col * (cw + gap)
        y = y0 + row * (ch + gap)
        rect(s, x, y, cw, ch, LIGHT, radius=0.1, line=LINE)
        textbox(s, x + Inches(0.2), y + Inches(0.2), cw - Inches(0.45), Inches(0.4),
                title, 19, INK, bold=True)
        textbox(s, x + Inches(0.2), y + Inches(0.72), cw - Inches(0.45), Inches(0.9),
                body, 14, MUTED, line_spacing=1.35)
    textbox(s, Inches(0.7), Inches(6.55), Inches(12), Inches(0.4),
            "وكل ذلك في تطبيق واحد، بحجم أقل من 25 ميجابايت، ويعمل على أندرويد 6+.", 15, GREEN, bold=True)


def guidance_slide(prs):
    s = blank(prs)
    header(s, "كيف يعمل الإرشاد؟", "من الموقع إلى تعليمة مفهومة")
    boxes = [
        ("GPS", "تحديث كل 2 متر", GREEN),
        ("محرك الإرشاد", "إسقاط على المسار + المسافة المتبقية", GREEN),
        ("الصوت", "«امشِ ٤٠ مترًا ثم انعطف يمينًا»", GREEN_DARK),
        ("الاهتزاز", "نمط مختلف لليمين واليسار والخطر", AMBER),
    ]
    for i, (title, body, color) in enumerate(boxes):
        x = W - Inches(0.7) - Inches(2.75) - i * Inches(3.15)
        rect(s, x, Inches(2.3), Inches(2.75), Inches(1.6), color, radius=0.12)
        textbox(s, x + Inches(0.15), Inches(2.45), Inches(2.45), Inches(0.45),
                title, 20, WHITE, bold=True, align=PP_ALIGN.CENTER)
        textbox(s, x + Inches(0.15), Inches(2.95), Inches(2.45), Inches(0.8),
                body, 13, WHITE, align=PP_ALIGN.CENTER, line_spacing=1.3)
        if i < 3:
            textbox(s, x - Inches(0.42), Inches(2.95), Inches(0.4), Inches(0.5),
                    "←", 18, MUTED, align=PP_ALIGN.CENTER)

    textbox(s, Inches(0.7), Inches(4.35), Inches(12), Inches(0.45),
            "تنبيهات متدرّجة على المسافة", 20, INK, bold=True)
    bands = ["150 م", "80 م", "40 م", "20 م", "10 م", "وصول"]
    for i, band in enumerate(bands):
        x = W - Inches(0.7) - Inches(1.85) - i * Inches(1.98)
        rect(s, x, Inches(4.95), Inches(1.85), Inches(0.75),
             GREEN if i < 5 else AMBER, radius=0.2)
        textbox(s, x, Inches(5.12), Inches(1.85), Inches(0.4), band, 16, WHITE,
                bold=True, align=PP_ALIGN.CENTER)
    textbox(s, Inches(0.7), Inches(6.05), Inches(12), Inches(0.9),
            "لا يُنطق الإرشاد مرتين لنفس الحالة، والتنبيه العاجل فقط يقطع الطابور.\n"
            "وعند انقطاع GPS: «توقف في مكان آمن» ثم إعلان الاستعادة.", 15, MUTED, line_spacing=1.4)


def offline_slide(prs):
    s = blank(prs)
    header(s, "الأوفلاين والخصوصية", "يعمل في الشارع كما في القاعة")
    rect(s, Inches(0.7), Inches(2.15), Inches(6.0), Inches(3.90), LIGHT, radius=0.08, line=LINE)
    textbox(s, Inches(1.0), Inches(2.35), Inches(5.4), Inches(0.45),
            "أوفلاين كامل", 22, GREEN, bold=True)
    textbox(s, Inches(1.0), Inches(2.9), Inches(5.4), Inches(2.9),
            "• كل البيانات في Hive على الجهاز\n"
            "• خرائط متجهية بلا تحميل بلاطات\n"
            "• البلاغات تُحفظ وتُرفع عند عودة الشبكة\n"
            "• طابور مزامنة لا يفقد شيئًا\n"
            "• لا ميزة أساسية تعتمد على الشبكة", 16, INK, line_spacing=1.6)

    rect(s, Inches(7.0), Inches(2.15), Inches(5.6), Inches(3.90), GREEN, radius=0.08)
    textbox(s, Inches(7.3), Inches(2.35), Inches(5.0), Inches(0.45),
            "خصوصية بالتصميم", 22, AMBER, bold=True)
    textbox(s, Inches(7.3), Inches(2.9), Inches(5.0), Inches(2.9),
            "• تشفير AES-256 ومفتاح في Keystore\n"
            "• لا تتبع للموقع في الخلفية\n"
            "• الموقع يُشارك فقط مع جهات SOS\n"
            "• حذف كل البيانات من داخل التطبيق\n"
            "• Firebase اختياري تمامًا", 16, WHITE, line_spacing=1.6)


def accessibility_slide(prs):
    s = blank(prs)
    header(s, "الإتاحة", "مصمّم لمن لا يرى الشاشة")
    rows = [
        ("TalkBack / VoiceOver", "تسمية وتلميح لكل عنصر، وإعلان اسم كل شاشة"),
        ("أهداف لمس كبيرة", "88dp للأزرار الرئيسية، 56dp للثانوية"),
        ("تباين عالٍ", "وضع أصفر على أسود + تباين ≥ 4.5:1"),
        ("بديل لمسي دائم", "كل أمر صوتي له زر مقابل — لا اعتماد على الصوت وحده"),
        ("قراءة عند التحديد", "خيار يقرأ العنصر عند وصول التركيز إليه"),
    ]
    y = Inches(2.15)
    for title, body in rows:
        rect(s, Inches(0.7), y, Inches(0.08), Inches(0.78), AMBER)
        textbox(s, Inches(3.0), y + Inches(0.02), Inches(9.6), Inches(0.35),
                title, 18, INK, bold=True)
        textbox(s, Inches(0.95), y + Inches(0.38), Inches(11.6), Inches(0.35),
                body, 14, MUTED)
        y += Inches(0.85)
    textbox(s, Inches(0.7), Inches(6.55), Inches(12), Inches(0.4),
            "تدقيق WCAG 2.1 AA موثّق في docs/ACCESSIBILITY_AUDIT.md", 14, GREEN, bold=True)


def architecture_slide(prs):
    s = blank(prs)
    header(s, "المعمارية", "طبقات واضحة ومنطق قابل للاختبار")
    layers = [
        ("الشاشات", "10 شاشات + مكوّنات إتاحة", GREEN),
        ("الحالة", "AppState — منسّق مركزي", GREEN),
        ("الخدمات", "صوت · موقع · إرشاد · بلاغات · SOS · مزامنة", GREEN),
        ("التخزين", "Hive مشفّر + Firestore اختياري", GREEN_DARK),
    ]
    y = Inches(2.2)
    for title, body, color in layers:
        rect(s, Inches(0.7), y, Inches(11.9), Inches(0.95), color, radius=0.1)
        textbox(s, Inches(9.6), y + Inches(0.22), Inches(2.7), Inches(0.45),
                title, 20, WHITE, bold=True)
        textbox(s, Inches(0.95), y + Inches(0.28), Inches(8.4), Inches(0.45),
                body, 15, WHITE)
        y += Inches(1.12)
    textbox(s, Inches(0.7), Inches(6.75), Inches(11.9), Inches(0.4),
            "محرك الإرشاد والأوامر الصوتية والجغرافيا دوال نقية — مغطاة بـ 61 اختبارًا.", 14, MUTED)


def stack_slide(prs):
    s = blank(prs)
    header(s, "التقنيات", "مفتوحة المصدر بالكامل")
    data = [
        ("الواجهة", "Flutter 3.27+ · Material 3 · RTL"),
        ("الصوت", "flutter_tts (ar-EG) · speech_to_text"),
        ("الموقع", "geolocator + محرك إرشاد مخصص"),
        ("الخرائط", "CustomPainter (أوفلاين) + flutter_map/OSM اختياري"),
        ("التخزين", "hive مشفّر + flutter_secure_storage"),
        ("السحابة", "Firebase Auth / Firestore / FCM — اختياري"),
    ]
    y = Inches(2.2)
    for name, tech in data:
        rect(s, Inches(0.7), y, Inches(2.9), Inches(0.62), GREEN, radius=0.15)
        textbox(s, Inches(0.7), y + Inches(0.13), Inches(2.9), Inches(0.4), name, 16,
                WHITE, bold=True, align=PP_ALIGN.CENTER)
        textbox(s, Inches(3.9), y + Inches(0.12), Inches(8.7), Inches(0.4), tech, 16, INK)
        rect(s, Inches(0.7), y + Inches(0.66), Inches(11.9), Inches(0.01), LINE)
        y += Inches(0.72)


def roadmap_slide(prs):
    s = blank(prs)
    header(s, "خريطة الطريق", "من v1.0 إلى المنظومة")
    phases = [
        ("v1.0 — الآن", "الميزات الأساسية، أوفلاين كامل، 61 اختبارًا", GREEN),
        ("v1.1", "التحقق المجتمعي · اهتزاز دلالي · مراقبة GPS", RGBColor(0x14, 0x7D, 0x4A)),
        ("v1.2", "Bluetooth Beacons لدقة داخل المباني", RGBColor(0x1E, 0x8E, 0x57)),
        ("v1.3", "توصيف الصور وكشف الإشارات بالكاميرا", RGBColor(0x2A, 0xA0, 0x64)),
        ("v2.0", "ساعة ذكية · تكامل حكومي · لغات إضافية", GREEN_DARK),
    ]
    y = Inches(2.2)
    for title, body, color in phases:
        rect(s, Inches(0.7), y, Inches(2.3), Inches(0.75), color, radius=0.2)
        textbox(s, Inches(0.7), y + Inches(0.19), Inches(2.3), Inches(0.4), title, 16,
                WHITE, bold=True, align=PP_ALIGN.CENTER)
        textbox(s, Inches(3.3), y + Inches(0.18), Inches(9.3), Inches(0.45), body, 16, INK)
        y += Inches(0.9)


def impact_slide(prs):
    s = blank(prs)
    header(s, "الأثر", "لماذا يهم؟")
    stats = [
        ("استقلالية", "طالب يذهب لمحاضرته دون مرافق دائم"),
        ("سلامة", "تنبيه قبل الإشارة والعائق، لا بعدهما"),
        ("شمول", "مجاني، يعمل على أجهزة قديمة، وبدون إنترنت"),
    ]
    x = Inches(0.7)
    for title, body in stats:
        rect(s, x, Inches(2.2), Inches(3.85), Inches(1.6), LIGHT, radius=0.1, line=LINE)
        textbox(s, x + Inches(0.25), Inches(2.4), Inches(3.35), Inches(0.45), title, 22,
                GREEN, bold=True)
        textbox(s, x + Inches(0.25), Inches(2.95), Inches(3.35), Inches(0.7), body, 14, MUTED,
                line_spacing=1.3)
        x += Inches(4.05)

    sdgs = ["SDG 3 الصحة", "SDG 4 التعليم", "SDG 9 الابتكار", "SDG 10 المساواة",
            "SDG 11 مدن مستدامة", "SDG 17 الشراكات"]
    x = Inches(0.7)
    for i, sdg in enumerate(sdgs):
        rect(s, x, Inches(4.35), Inches(1.85), Inches(0.7), GREEN_DARK, radius=0.2)
        textbox(s, x, Inches(4.5), Inches(1.85), Inches(0.4), sdg, 12, WHITE, bold=True,
                align=PP_ALIGN.CENTER)
        x += Inches(1.98)

    textbox(s, Inches(0.7), Inches(5.55), Inches(12), Inches(1.2),
            "المؤشرات المستهدفة: ≥ 90% إكمال الرحلة دون مساعدة · رضا ≥ 4.2/5 · صفر حوادث.\n"
            "ما لا ندّعيه: التطبيق أداة مساعدة، وليس بديلًا عن العصا البيضاء أو المرافق.", 15,
            MUTED, line_spacing=1.5)


def closing_slide(prs):
    s = blank(prs)
    rect(s, 0, 0, W, H, GREEN_DARK)
    rect(s, 0, Inches(7.28), W, Inches(0.22), AMBER)
    textbox(s, Inches(0.9), Inches(1.6), Inches(11.5), Inches(0.9),
            "جرّبها بنفسك", 44, WHITE, bold=True)
    textbox(s, Inches(0.9), Inches(2.7), Inches(11.5), Inches(1.6),
            "أغمض عينيك، واضغط زر الاستغاثة مرتين، ثم اسمع.\n"
            "هذه هي التجربة التي نقدّمها — لا شرائح، بل استقلالية.", 22,
            RGBColor(0xD8, 0xEF, 0xE3), line_spacing=1.5)
    textbox(s, Inches(0.9), Inches(4.5), Inches(11.5), Inches(0.5),
            "github.com/mo3bdo23/basira", 24, AMBER, bold=True)
    textbox(s, Inches(0.9), Inches(5.2), Inches(11.5), Inches(1.2),
            "الكود مفتوح · يعمل بدون إنترنت · يدعم TalkBack و VoiceOver\n"
            "MIT License © 2026 Basira", 16, RGBColor(0xA5, 0xC9, 0xB4), line_spacing=1.4)


def build() -> None:
    prs = Presentation()
    prs.slide_width = W
    prs.slide_height = H

    title_slide(prs)
    problem_slide(prs)
    solution_slide(prs)
    features_slide(prs)
    guidance_slide(prs)
    offline_slide(prs)
    accessibility_slide(prs)
    architecture_slide(prs)
    stack_slide(prs)
    roadmap_slide(prs)
    impact_slide(prs)
    closing_slide(prs)

    core = prs.core_properties
    core.title = "بصيرة — تطبيق تنقّل صوتي لذوي الإعاقة البصرية"
    core.subject = "Voice-first navigation for blind and low-vision users"
    core.author = "Basira"
    core.keywords = "accessibility, flutter, navigation, offline, sos"
    core.language = "ar"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    prs.save(str(OUT))
    print(f"saved {OUT} ({len(prs.slides.__iter__.__self__._sldIdLst)} slides)")


if __name__ == "__main__":
    build()
