from __future__ import annotations
import json, re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "app_icon_source.webp"
BRAND = (47, 125, 225, 255)

def make_square(im, size, pad=BRAND):
    canvas = Image.new("RGBA", (size, size), pad)
    im2 = im.copy()
    im2.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas.paste(im2, ((size - im2.width)//2, (size - im2.height)//2), im2)
    return canvas

def make_fg(im, size):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.72)
    im2 = im.copy()
    im2.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    canvas.paste(im2, ((size - im2.width)//2, (size - im2.height)//2), im2)
    return canvas

def main():
    img = Image.open(SRC).convert("RGBA")
    print("source", img.size)
    master = make_square(img, 1024)
    (ROOT/"assets").mkdir(exist_ok=True)
    master.save(ROOT/"assets"/"app_icon.png", "PNG")
    res = ROOT/"android"/"app"/"src"/"main"/"res"
    for folder, sz in {"mipmap-mdpi":48,"mipmap-hdpi":72,"mipmap-xhdpi":96,"mipmap-xxhdpi":144,"mipmap-xxxhdpi":192}.items():
        out = res/folder/"ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        make_square(img, sz).save(out, "PNG")
        print(out)
    old = res/"drawable"/"ic_launcher_foreground.xml"
    if old.exists(): old.unlink()
    fg = res/"drawable"/"ic_launcher_foreground.png"
    make_fg(img, 432).save(fg, "PNG")
    print(fg)
    xml = res/"mipmap-anydpi-v26"/"ic_launcher.xml"
    xml.write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''', encoding="utf-8")
    colors = res/"values"/"colors.xml"
    txt = colors.read_text(encoding="utf-8")
    if "ic_launcher_background" not in txt:
        txt = txt.replace("</resources>", '    <color name="ic_launcher_background">#2F7DE1</color>\n</resources>')
    else:
        txt = re.sub(r'<color name="ic_launcher_background">.*?</color>', '<color name="ic_launcher_background">#2F7DE1</color>', txt)
    colors.write_text(txt, encoding="utf-8")
    sizes=[16,32,48,64,128,256]
    imgs=[make_square(img,s) for s in sizes]
    ico = ROOT/"windows"/"runner"/"resources"/"app_icon.ico"
    imgs[0].save(ico, format="ICO", sizes=[(s,s) for s in sizes], append_images=imgs[1:])
    print(ico)
    scale={"1x":1,"2x":2,"3x":3}
    def fill(appiconset: Path):
        if not appiconset.exists(): return
        data=json.loads((appiconset/"Contents.json").read_text(encoding="utf-8"))
        for item in data.get("images",[]):
            fn=item.get("filename")
            if not fn: continue
            pt=str(item.get("size","60x60")).split("x")[0]
            sc=scale.get(item.get("scale","1x"),1)
            try: px=int(float(pt)*sc)
            except: px=1024
            if item.get("idiom")=="ios-marketing": px=1024
            make_square(img,px).save(appiconset/fn,"PNG")
            print(appiconset/fn, px)
    fill(ROOT/"ios"/"Runner"/"Assets.xcassets"/"AppIcon.appiconset")
    fill(ROOT/"macos"/"Runner"/"Assets.xcassets"/"AppIcon.appiconset")
    print("done")
if __name__=="__main__":
    main()
