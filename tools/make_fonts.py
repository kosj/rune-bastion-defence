"""Subset the fonts to the glyphs actually used in the game's scripts (keeps the web download small:
fonts sit in the core pack, which gates the title screen). Re-run after adding new text."""
from fontTools.ttLib import TTCollection, TTFont
from fontTools import subset
import glob, os, shutil
chars = set()
for f in glob.glob('scripts/**/*.gd', recursive=True) + glob.glob('web/*.html'):
    chars |= set(open(f, encoding='utf-8').read())
chars |= set(''.join(chr(c) for c in range(32, 127)))
chars |= set('·…▶◀→←↑↓★☆%+-×÷—–!?.,:;()[]0123456789')
txt = ''.join(sorted(c for c in chars if c >= ' '))
import sys
if '--check' in sys.argv:
    # CI: every character the scripts use must be in the shipped Korean UI fonts (else it renders
    # as a box): re-run this tool without --check after adding text
    bad = {}
    for f in ('ui', 'ui_black', 'title_kr'):
        cmap = TTFont('assets/fonts/%s.ttf' % f).getBestCmap()
        # emoji only appear on the HTML loading page (system fonts)
        miss = sorted(c for c in txt if 32 < ord(c) < 0x1F000 and ord(c) not in cmap and not (0xFE00 <= ord(c) <= 0xFE0F))
        if miss:
            bad[f] = ''.join(miss)
    if bad:
        sys.exit('fonts miss glyphs (run python3 tools/make_fonts.py): %s' % bad)
    print('fonts cover all %d characters' % len(txt))
    sys.exit(0)
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
def subset_ttf(src, out):
    opts = subset.Options(); opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.notdef_outline = True
    ft = TTFont(src)
    s = subset.Subsetter(opts); s.populate(text=txt); s.subset(ft)
    ft.save(out)
    print(out, os.path.basename(src), os.path.getsize(out))
os.makedirs('assets/fonts', exist_ok=True)
extract('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 'Noto Sans CJK KR', 'assets/fonts/ui.ttf')
extract('/usr/share/fonts/opentype/noto/NotoSerifCJK-Black.ttc', 'Noto Serif CJK KR', 'assets/fonts/title_kr.ttf')
extract('/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc', 'Noto Sans CJK KR', 'assets/fonts/ui_black.ttf')
# the Latin title face: full Cardo has ~3000 glyphs (348 KB); the game uses a few hundred
subset_ttf('/usr/share/fonts/truetype/google-fonts/ofl/cardo/Cardo-Bold.ttf', 'assets/fonts/title.ttf')
print('glyphs', len(txt))
