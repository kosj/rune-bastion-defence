"""Subset Noto CJK KR fonts to the glyphs actually used in the game's scripts (keeps the web download small)."""
from fontTools.ttLib import TTCollection, TTFont
from fontTools import subset
import glob, os, shutil
chars = set()
for f in glob.glob('scripts/**/*.gd', recursive=True) + glob.glob('web/*.html'):
    chars |= set(open(f, encoding='utf-8').read())
chars |= set(''.join(chr(c) for c in range(32, 127)))
chars |= set('·…▶◀→←↑↓★☆%+-×÷—–!?.,:;()[]0123456789')
txt = ''.join(sorted(c for c in chars if c >= ' '))
def extract(ttc, want, out):
    col = TTCollection(ttc)
    for f in col.fonts:
        name = f['name'].getDebugName(1)
        if want in name and 'Mono' not in name:
            tmp = '/tmp/_f.otf'
            f.save(tmp)
            opts = subset.Options(); opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.notdef_outline = True
            ft = TTFont(tmp)
            s = subset.Subsetter(opts); s.populate(text=txt); s.subset(ft)
            ft.save(out)
            print(out, name, os.path.getsize(out))
            return
os.makedirs('assets/fonts', exist_ok=True)
extract('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 'Noto Sans CJK KR', 'assets/fonts/ui.ttf')
extract('/usr/share/fonts/opentype/noto/NotoSerifCJK-Black.ttc', 'Noto Serif CJK KR', 'assets/fonts/title_kr.ttf')
extract('/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc', 'Noto Sans CJK KR', 'assets/fonts/ui_black.ttf')
shutil.copy('/usr/share/fonts/truetype/google-fonts/ofl/cardo/Cardo-Bold.ttf', 'assets/fonts/title.ttf')
print('glyphs', len(txt))
