"""يولّد أيقونة تطبيق بصيرة (PNG) بكل المقاسات المطلوبة لأندرويد/iOS/الويب."""
from PIL import Image, ImageDraw
import os

SIZE = 1024
GREEN = (11, 107, 58, 255)
GREEN_DARK = (6, 74, 40, 255)
WHITE = (255, 255, 255, 255)
AMBER = (245, 165, 36, 255)


def make_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # خلفية متدرجة يدويًا (دوائر متداخلة)
    r = size * 0.22
    d.rounded_rectangle([0, 0, size, size], radius=r, fill=GREEN_DARK)
    for i in range(60, 0, -1):
        t = i / 60
        inset = size * 0.06 * t
        col = tuple(int(GREEN[k] * (1 - t) + GREEN_DARK[k] * t) for k in range(3)) + (255,)
        d.ellipse(
            [size * 0.05 + inset, -size * 0.25 + inset,
             size * 0.95 - inset, size * 0.85 - inset],
            fill=col,
        )

    cx, cy = size / 2, size / 2
    # شكل العين
    eye_w, eye_h = size * 0.62, size * 0.40
    d.ellipse([cx - eye_w / 2, cy - eye_h / 2, cx + eye_w / 2, cy + eye_h / 2], fill=WHITE)
    # القزحية
    d.ellipse([cx - eye_h * 0.36, cy - eye_h * 0.36, cx + eye_h * 0.36, cy + eye_h * 0.36], fill=GREEN)
    # البؤبؤ
    d.ellipse([cx - eye_h * 0.18, cy - eye_h * 0.18, cx + eye_h * 0.18, cy + eye_h * 0.18], fill=(8, 20, 14, 255))
    # لمعة
    d.ellipse([cx - eye_h * 0.30, cy - eye_h * 0.30, cx - eye_h * 0.10, cy - eye_h * 0.10], fill=WHITE)
    # حلقة ذهبية حول العين (رمز العصا/الوعي)
    ring = size * 0.026
    d.arc(
        [cx - eye_w / 2 - ring * 2, cy - eye_h / 2 - ring * 2,
         cx + eye_w / 2 + ring * 2, cy + eye_h / 2 + ring * 2],
        start=200, end=340, fill=AMBER, width=int(ring),
    )
    return img


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.abspath(os.path.join(here, "..", "assets", "images"))
    os.makedirs(out, exist_ok=True)
    icon = make_icon(SIZE)
    icon.save(os.path.join(out, "app_icon.png"))

    # أيقونات أندرويد (mipmap) و iOS إن وُجد المجلد.
    densities = {
        "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
    }
    android_res = os.path.abspath(os.path.join(here, "..", "android", "app", "src", "main", "res"))
    for folder, px in densities.items():
        target = os.path.join(android_res, folder)
        if os.path.isdir(os.path.dirname(target)):
            os.makedirs(target, exist_ok=True)
            icon.resize((px, px), Image.LANCZOS).save(os.path.join(target, "ic_launcher.png"))

    ios_dir = os.path.abspath(os.path.join(
        here, "..", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"))
    if os.path.isdir(os.path.dirname(ios_dir)):
        os.makedirs(ios_dir, exist_ok=True)
        for px in (20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024):
            icon.resize((px, px), Image.LANCZOS).save(os.path.join(ios_dir, f"Icon-App-{px}.png"))

    # أيقونة الويب
    web_dir = os.path.abspath(os.path.join(here, "..", "web"))
    if os.path.isdir(web_dir):
        for px, name in ((192, "icons/Icon-192.png"), (512, "icons/Icon-512.png")):
            p = os.path.join(web_dir, name)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            icon.resize((px, px), Image.LANCZOS).save(p)

    print("icon written:", os.path.join(out, "app_icon.png"))


if __name__ == "__main__":
    main()
